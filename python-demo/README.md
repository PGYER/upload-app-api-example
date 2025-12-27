## `Python` 脚本使用说明

支持上传 iOS (.ipa)、Android (.apk) 和 HarmonyOS (.hap) 应用到蒲公英平台。

## 环境

此为 `Python3` 脚本

使用前，请使用下方命令安装依赖

```shell
pip install -r requirements.txt
```

## 使用

### 配置环境变量

脚本需要通过环境变量配置以下参数：

- `PGYER_APP_PATH`: 应用文件路径（支持 .ipa、.apk、.hap 文件）
- `PGYER_API_KEY`: 蒲公英 API Key

设置环境变量示例：

```bash
export PGYER_APP_PATH="/path/to/your/app.apk"
export PGYER_API_KEY="your_api_key_here"
```

### 运行脚本

```bash
python demo.py
```

或者在一行中指定环境变量：

```bash
PGYER_APP_PATH="/path/to/app.apk" PGYER_API_KEY="your_api_key" python demo.py
```

### 代码集成

导入工具包

```python
import os
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

# 从环境变量读取配置
app_path = os.environ.get('PGYER_APP_PATH')
pgyer_api_key = os.environ.get('PGYER_API_KEY')

PgyerUtil.upload_to_pgyer(
  path = app_path, 
  api_key = pgyer_api_key, 
  install_type = 1,  # 1:公开 2:密码安装 3:邀请安装
  callback=upload_complete_callback
)
```