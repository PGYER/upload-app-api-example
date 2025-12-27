# -*- coding: utf-8 -*-
# -*- author: LinXunFeng -*-

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

  # 示例文件路径 (支持 .ipa/.apk/.hap 文件)
  app_path = '/Users/rexshi/Downloads/apks/5d7d326764b75788d021f7e579264a01.apk'  # 例如: '/path/to/app.ipa' 或 '/path/to/app.apk' 或 '/path/to/app.hap'
  pgyer_api_key = 'c3bb8fde1919514f8fb4d8694d38b4e2' # API KEY

  PgyerUtil.upload_to_pgyer(
    path = app_path, 
    api_key = pgyer_api_key,
    install_type = 1,  # 1:公开 2:密码安装 3:邀请安装
    callback=upload_complete_callback
  )
