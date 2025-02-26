# -*- coding: utf-8 -*-
# -*- author: LinXunFeng -*-

import time
import requests

# 官方文档
# https://www.pgyer.com/doc/view/api#fastUploadApp

def _getCOSToken(
    api_key, 
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
    'buildType': 'ios', # 需要上传的应用类型，ios 或 android
    'buildInstallType': install_type, # (选填)应用安装方式，值为(1,2,3，默认为1 公开安装)。1：公开安装，2：密码安装，3：邀请安装
    'buildPassword': password, # (选填) 设置App安装密码，密码为空时默认公开安装
    'buildUpdateDescription': update_description, # (选填) 版本更新描述，请传空字符串，或不传。
  }
  try:
    r = requests.post('https://api.pgyer.com/apiv2/app/getCOSToken', data=payload, headers=headers)
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
    :param path: 文件路径
    :param api_key: API Key
    :param install_type: 应用安装方式，值为(1,2,3)。1：公开，2：密码安装，3：邀请安装。默认为1公开
    :param password: App安装密码
    :param update_description:
    :return: 版本更新描述
    """

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

    _getCOSToken(
      api_key=api_key, 
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
    response = requests.get('https://api.pgyer.com/apiv2/app/buildInfo', params={
      '_api_key': api_key,
      'buildKey': json['data']['params']['key'],
    })
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

