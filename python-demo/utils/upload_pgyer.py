# -*- coding: utf-8 -*-
# -*- author: LinXunFeng -*-

import os
import time
import requests
import json
from requests.adapters import HTTPAdapter
import urllib3
from urllib3.util.ssl_ import create_urllib3_context
from tqdm import tqdm
from requests_toolbelt.multipart.encoder import MultipartEncoder, MultipartEncoderMonitor

# 官方文档
# https://www.pgyer.com/doc/view/api#fastUploadApp

# 支持的文件类型
SUPPORTED_TYPES = ['ipa', 'apk', 'hap']

# 全局变量
host = None
hostname = None
dnsService = 'https://dns.alidns.com/resolve'
serviceHosts = [
    'api.pgyer.com',
    'api.xcxwo.com',
    'api.pgyerapp.com'
]

urllib3.disable_warnings()

class SSLAdapter(HTTPAdapter):
    """自定义 HTTPAdapter，支持 SNI 和 IP + Host Header 的 HTTPS 请求"""
    def init_poolmanager(self, *args, **kwargs):
        ctx = create_urllib3_context()
        kwargs['ssl_context'] = ctx
        return super().init_poolmanager(*args, **kwargs)

def _checkConnectivity():
    """
    检查连通性，支持 DoH（DNS over HTTPS）
    尝试连接到蒲公英 API 服务，获取可用的 host 和 hostname
    """
    global host, hostname
    
    for service_host in serviceHosts:
        try:
            # 先尝试直接连接
            response = requests.get(
                f'https://{service_host}/apiv2',
                timeout=5
            )
            data = response.json()
            if data and data.get('code') == 1001:
                host = service_host
                hostname = service_host
                return
        except Exception:
            pass
        
        try:
            # 使用 DoH 查询 DNS
            response = requests.get(
                f'{dnsService}?name={service_host}&type=A',
                timeout=5
            )
            data = response.json()
            
            # 过滤 A 记录（type=1）
            answers = data.get('Answer', [])
            a_records = [item for item in answers if item.get('type') == 1]
            
            if a_records:
                host = a_records[0]['data']
                hostname = service_host
                return
        except Exception:
            pass
    
    raise Exception('❌ 无法连接到蒲公英 API 服务，请检查网络连接')

def _get_build_type(file_path):
    """
    根据文件扩展名获取构建类型
    :param file_path: 文件路径
    :return: 构建类型 (ios/android/harmony)
    """
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"❌ 文件不存在: {file_path}")
    
    file_ext = os.path.splitext(file_path)[1][1:].lower()  # 获取扩展名并转小写
    
    if file_ext not in SUPPORTED_TYPES:
        raise ValueError(f"❌ 不支持的文件类型: {file_ext}，支持的类型: {', '.join(SUPPORTED_TYPES)}")
    
    if file_ext == 'ipa':
        return 'ios'
    elif file_ext == 'apk':
        return 'android'
    elif file_ext == 'hap':
        return 'harmony'

def _getCOSToken(
    api_key, 
    build_type,
    install_type, 
    password='', 
    update_description='', 
    callback=None
):
  """
  获取上传的 token
  """
  headers = {'enctype': 'multipart/form-data'}
  payload = {
    '_api_key': api_key, # API Key
    'buildType': build_type, # 需要上传的应用类型，ios、android 或 harmony
    'buildInstallType': install_type, # (选填)应用安装方式，值为(1,2,3，默认为1 公开安装)。1：公开安装，2：密码安装，3：邀请安装
    'buildPassword': password, # (选填) 设置App安装密码，密码为空时默认公开安装
    'buildUpdateDescription': update_description, # (选填) 版本更新描述，请传空字符串，或不传。
  }
  try:
    url = f'https://{host}/apiv2/app/getCOSToken'

    session = requests
    if host != hostname:
      headers['Host'] = hostname
      session = requests.Session()
      session.mount('https://', SSLAdapter())

    r = session.post(url, data=payload, headers=headers, verify=False)
    if r.status_code == requests.codes.ok:
      result = r.json()
      # print(result)
      if callback is not None:
        callback(True, result)
    else:
      if callback is not None:
          callback(False, None)
  except Exception as e:
    print(f'❌ 获取上传Token失败: {e}')


def upload_to_pgyer(path, api_key, install_type=2, password='', update_description='', callback=None):
    """
    上传到蒲公英
    :param path: 文件路径 (支持 .ipa/.apk/.hap 文件)
    :param api_key: API Key
    :param install_type: 应用安装方式，值为(1,2,3)。1：公开，2：密码安装，3：邀请安装。默认为1公开安装
    :param password: App安装密码
    :param update_description: 版本更新描述
    :param callback: 上传完成回调函数
    :return: None
    """
    
    print('\n' + '='*60)
    print('🚀 开始上传应用到蒲公英')
    print('='*60)
    
    # 初始化时检查连通性
    print('🔍 检查网络连通性...')
    try:
        _checkConnectivity()
        print(f'✅ 连接成功: {hostname} ({host})')
    except Exception as e:
        print(f"{e}")
        if callback is not None:
            callback(False, None)
        return
    
    # 检测文件类型
    print(f'📂 检查文件: {os.path.basename(path)}')
    try:
        build_type = _get_build_type(path)
        file_size = os.path.getsize(path)
        print(f'✅ 文件类型: {build_type.upper()}, 大小: {file_size / (1024*1024):.2f} MB')
    except (FileNotFoundError, ValueError) as e:
        print(f"{e}")
        if callback is not None:
            callback(False, None)
        return
    
    print('\n📤 正在获取上传凭证...')

    def getCOSToken_callback(isSuccess, json):
      if isSuccess:
        _upload_url = json['data']['endpoint']
        
        # 获取文件大小
        file_size = os.path.getsize(path)
        
        # 准备 multipart 数据
        payload = json['data']['params']
        payload['file'] = ('file', open(path, 'rb'), 'application/octet-stream')
        
        # 创建 MultipartEncoder
        encoder = MultipartEncoder(fields=payload)
        
        # 创建进度条
        print('\n📤 开始上传文件...')
        with tqdm(total=encoder.len, unit='B', unit_scale=True, unit_divisor=1024, desc="上传进度", ncols=80) as pbar:
            # 创建监控器，在每次数据发送时更新进度条
            def callback_progress(monitor):
                pbar.update(monitor.bytes_read - pbar.n)
            
            monitor = MultipartEncoderMonitor(encoder, callback_progress)
            
            headers = {'Content-Type': monitor.content_type}
            
            try:
                r = requests.post(_upload_url, data=monitor, headers=headers)
                pbar.close()  # 手动关闭进度条，避免重复显示
                if r.status_code == 204:
                    # result = r.json()
                    # print(result)
                    print("\n✅ 文件上传成功")
                    print("⏳ 正在处理应用包，请稍等...")
                    _getBuildInfo(api_key=api_key, json=json, callback=callback)
                else:
                    print(f'\n❌ 上传失败，HTTP错误码: {r.status_code}')
                    if callback is not None:
                        callback(False, None)
            except Exception as e:
                print(f'\n❌ 上传异常: {e}')
                if callback is not None:
                    callback(False, None)
      else:
          print('❌ 获取上传凭证失败')
          if callback is not None:
              callback(False, None)

    _getCOSToken(
      api_key=api_key, 
      build_type=build_type,
      install_type=install_type, 
      password=password, 
      update_description=update_description, 
      callback=getCOSToken_callback,
    )

def _getBuildInfo(api_key, json, callback=None):
    """
    检测应用是否发布完成，并获取发布应用的信息
    """
    time.sleep(3) # 先等个几秒，上传完直接获取肯定app是还在处理中~
    print('🔄 检查应用处理状态...')
    
    url = f'https://{host}/apiv2/app/buildInfo'
    params = {
        '_api_key': api_key,
        'buildKey': json['data']['params']['key'],
    }

    headers = {}
    session = requests

    if host != hostname:
      headers['Host'] = hostname
      session = requests.Session()
      session.mount('https://', SSLAdapter())

    response = session.get(url, params=params, headers=headers, verify=False)
    if response.status_code == requests.codes.ok:
      result = response.json()
      code = result['code']
      if code == 1247 or code == 1246: # 1246	应用正在解析、1247 应用正在发布中
        status_msg = '正在解析应用包...' if code == 1246 else '正在发布应用...'
        print(f'⏳ {status_msg}')
        _getBuildInfo(api_key=api_key, json=json, callback=callback)
      else:
        if callback is not None:
          callback(True, result)
    else:
      print(f'❌ 获取构建信息失败，HTTP错误码: {response.status_code}')
      if callback is not None:
        callback(False, None)

