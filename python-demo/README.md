## `Python` 脚本使用说明

支持上传 iOS (.ipa)、Android (.apk) 和 HarmonyOS (.hap) 应用到蒲公英平台。

## 环境

此为 `Python3` 脚本

使用前，请使用下方命令安装依赖

```shell
pip install -r requirements.txt
```

## 使用

导入工具包

```python
from utils import upload_pgyer as PgyerUtil
```

调用 `upload_to_pgyer` 方法即可

```python
# 上传完成回调
def upload_complete_callback(isSuccess, result):
  if isSuccess:
    print('上传完成')
  else:
    print('上传失败')

# 支持的文件类型：.ipa (iOS)、.apk (Android)、.hap (HarmonyOS)
app_path = '<your app path>'  # 例如: '/path/to/app.ipa' 或 '/path/to/app.apk' 或 '/path/to/app.hap'
pgyer_api_key = '<your api key>' # API KEY
pgyer_password = '<your app install password>' # 安装密码

PgyerUtil.upload_to_pgyer(
  path = app_path, 
  api_key = pgyer_api_key, 
  install_type = 2,  # 1:公开 2:密码安装 3:邀请安装
  password=pgyer_password, 
  callback=upload_complete_callback
)
```