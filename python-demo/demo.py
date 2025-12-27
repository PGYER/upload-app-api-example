# -*- coding: utf-8 -*-
# -*- author: LinXunFeng -*-

import os
from utils import upload_pgyer as PgyerUtil

if __name__ == "__main__":

  # 上传完成回调
  def upload_complete_callback(isSuccess, result):
    print('\n' + '='*60)
    if isSuccess:
      print('✅ 上传成功！')
      print('='*60)
      _data = result['data']
      _url = _data['buildShortcutUrl'].strip() # 去除首尾空格
      _appVer = _data['buildVersion']
      _buildVer = _data['buildBuildVersion']
      _buildName = _data.get('buildName', 'N/A')
      _buildIdentifier = _data.get('buildIdentifier', 'N/A')
      
      print(f'📦 应用名称: {_buildName}')
      print(f'🆔 Bundle ID: {_buildIdentifier}')
      print(f'📌 版本号: {_appVer} (Build {_buildVer})')
      print(f'🔗 下载链接: https://www.pgyer.com/{_url}')
      print('='*60)
    else:
      print('❌ 上传失败！')
      print('='*60)

  # 从环境变量读取配置
  app_path = os.environ.get('PGYER_APP_PATH')  # 从环境变量 PGYER_APP_PATH 读取应用路径
  pgyer_api_key = os.environ.get('PGYER_API_KEY')  # 从环境变量 PGYER_API_KEY 读取 API KEY
  
  # 检查必需的环境变量
  if not app_path:
    print('❌ 错误: 请设置环境变量 PGYER_APP_PATH')
    exit(1)
  if not pgyer_api_key:
    print('❌ 错误: 请设置环境变量 PGYER_API_KEY')
    exit(1)

  PgyerUtil.upload_to_pgyer(
    path = app_path, 
    api_key = pgyer_api_key,
    install_type = 1,  # 1:公开 2:密码安装 3:邀请安装
    callback=upload_complete_callback
  )
