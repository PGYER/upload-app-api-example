# -*- coding: utf-8 -*-
# -*- author: LinXunFeng -*-

from utils import upload_pgyer as PgyerUtil

if __name__ == "__main__":

  # 上传完成回调
  def upload_complete_callback(isSuccess, result):
    if isSuccess:
      print('上传完成')
      _data = result['data']
      _url = _data['buildShortcutUrl'].strip() # 去除首尾空格
      _appVer = _data['buildVersion']
      _buildVer = _data['buildBuildVersion']
      print('链接: https://www.pgyer.com/%s'%_url)
      print('版本: %s (build %s)'%(_appVer, _buildVer))
    else:
      print('上传失败')

  # 示例文件路径 (支持 .ipa/.apk/.hap 文件)
  app_path = '<your app path>'  # 例如: '/path/to/app.ipa' 或 '/path/to/app.apk' 或 '/path/to/app.hap'
  pgyer_api_key = '<your api key>' # API KEY

  PgyerUtil.upload_to_pgyer(
    path = app_path, 
    api_key = pgyer_api_key,
    install_type = 1,  # 1:公开 2:密码安装 3:邀请安装
    callback=upload_complete_callback
  )
