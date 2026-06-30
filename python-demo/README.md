# PGYER Python Demo

这是 PGYER App 上传 API 的 Python 3 示例，可用于上传 iOS、Android 和 HarmonyOS 安装包。

## 功能

- 支持 `.ipa`、`.apk`、`.hap` 文件
- 自动选择可用的 PGYER API 服务域名
- 自动获取上传凭证、上传安装包并轮询构建结果
- 上传时显示进度条
- 构建结果轮询有明确超时，不会无限等待

## 环境要求

- Python 3.8 或更高版本

## 安装依赖

```bash
cd python-demo
python3 -m pip install -r requirements.txt
```

## 快速开始

脚本通过环境变量读取必要配置：

```bash
export PGYER_APP_PATH="/path/to/your/app.apk"
export PGYER_API_KEY="<your api key>"
python3 demo.py
```

也可以在一行中指定：

```bash
PGYER_APP_PATH="/path/to/app.apk" PGYER_API_KEY="<your api key>" python3 demo.py
```

## 可选环境变量

| 变量名 | 含义 |
| --- | --- |
| `PGYER_OVERSEA` | 是否使用海外加速上传：`1` 海外，`2` 国内；留空时根据 IP 自动判断 |
| `PGYER_INSTALL_TYPE` | 安装方式：`1` 公开，`2` 密码，`3` 邀请，默认为 `1` |
| `PGYER_INSTALL_PASSWORD` | 安装密码，当安装方式为密码安装时使用 |
| `PGYER_BUILD_DESCRIPTION` | 应用介绍 |
| `PGYER_UPDATE_DESCRIPTION` | 版本更新描述 |

## 代码集成

```python
from utils import upload_pgyer as PgyerUtil


def upload_complete_callback(is_success, result):
    if is_success:
        print("上传完成")
        print(result["data"]["buildShortcutUrl"])
    else:
        print("上传失败")


result = PgyerUtil.upload_to_pgyer(
    path="/path/to/app.apk",
    api_key="<your api key>",
    install_type=1,
    update_description="Uploaded by Python demo",
    callback=upload_complete_callback,
)
```

`upload_to_pgyer()` 会在上传成功时返回 PGYER API 响应；失败时返回 `None`，并通过回调返回失败状态。

## 参数说明

| 参数名 | 必选 | 含义 |
| --- | --- | --- |
| `path` | Y | App 文件路径，支持 `.ipa`、`.apk`、`.hap` |
| `api_key` | Y | PGYER API Key |
| `install_type` | N | 安装方式：`1` 公开，`2` 密码，`3` 邀请，默认为 `1` |
| `oversea` | N | 是否使用海外加速上传：`1` 海外，`2` 国内；留空时根据 IP 自动判断 |
| `password` | N | 安装密码，当 `install_type=2` 时使用 |
| `build_description` | N | 应用介绍 |
| `update_description` | N | 版本更新描述 |
| `install_date` | N | 安装有效期类型：`1` 设置时间，`2` 长期有效 |
| `install_start_date` | N | 安装有效期开始时间，格式：`2018-01-01` |
| `install_end_date` | N | 安装有效期结束时间，格式：`2018-12-31` |
| `channel_shortcut` | N | 指定渠道短链接 |
| `callback` | N | 上传完成回调：`callback(is_success, result)` |

## 注意事项

1. 请确保 API Key 正确。
2. 文件扩展名必须是 `.ipa`、`.apk` 或 `.hap`。
3. 上传完成后会轮询构建结果，最多等待约 60 秒。
4. 普通域名请求会保持 HTTPS 证书校验；只有直连失败并使用 DoH IP 兜底时，才会关闭该兜底请求的证书校验。

## 详细文档

更多信息请参考 [PGYER API 文档](https://www.pgyer.com/doc/view/api#fastUploadApp)。
