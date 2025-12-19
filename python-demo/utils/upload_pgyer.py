# -*- coding: utf-8 -*-
# -*- author: LinXunFeng -*-

import os
import time
import requests
import json
from requests.adapters import HTTPAdapter
import urllib3
from urllib3.util.ssl_ import create_urllib3_context

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
    
    raise Exception('Cannot connect to PGYER API service.')

def _get_build_type(file_path):
    """
    根据文件扩展名获取构建类型
    :param file_path: 文件路径
    :return: 构建类型 (ios/android/harmony)
    """
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"文件不存在: {file_path}")
    
    file_ext = os.path.splitext(file_path)[1][1:].lower()  # 获取扩展名并转小写
    
    if file_ext not in SUPPORTED_TYPES:
        raise ValueError(f"不支持的文件类型: {file_ext}，支持的类型: {', '.join(SUPPORTED_TYPES)}")
    
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
    print('服务器暂时无法为您服务')


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
    
    # 初始化时检查连通性
    try:
        _checkConnectivity()
    except Exception as e:
        print(f"连接错误: {e}")
        if callback is not None:
            callback(False, None)
        return
    
    # 检测文件类型
    try:
        build_type = _get_build_type(path)
    except (FileNotFoundError, ValueError) as e:
        print(f"错误: {e}")
        if callback is not None:
            callback(False, None)
        return

    def getCOSToken_callback(isSuccess, json):
      if isSuccess:
        _upload_url = json['data']['endpoint']
        
        files = {'file': open(path, 'rb')}
        headers = {'enctype': 'multipart/form-data'}
        payload = json['data']['params']
        print("上传中...")
        
        try:
          r = requests.post(_upload_url, data=payload, files=files, headers=headers)
          if r.status_code == 204:
            # result = r.json()
            # print(result)
            print("上传成功，正在获取包处理信息，请稍等...")
            _getBuildInfo(api_key=api_key, json=json, callback=callback)
          else:
            print('HTTPError,Code:'+ str(r.status_code))
            if callback is not None:
              callback(False, None)
        except Exception as e:
          print('服务器暂时无法为您服务')
      else:
          pass

    print(f'Start upload, using service: {hostname} ({host}) ...');

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
        _getBuildInfo(api_key=api_key, json=json, callback=callback)
      else:
        if callback is not None:
          callback(True, result)
    else:
      if callback is not None:
        callback(False, None)

