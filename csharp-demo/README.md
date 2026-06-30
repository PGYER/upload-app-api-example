# PGYER C# Demo

这是 PGYER App 上传 API 的 C#/.NET 示例，可用于上传 iOS、Android 和 HarmonyOS 安装包。

## 功能

- 支持 `.ipa`、`.apk`、`.hap` 文件
- 自动选择可用的 PGYER API 服务域名
- 自动获取上传凭证、上传安装包并轮询构建结果
- 使用流式上传，避免一次性将安装包读入内存
- 调试日志会对 API Key、上传签名、临时 token、安装密码等敏感字段脱敏

## 环境要求

- .NET 8.0 或更高版本

## 快速开始

```bash
cd csharp-demo
export PGYER_API_KEY="<your api key>"
export PGYER_APP_PATH="/path/to/app.apk"
dotnet run
```

如需开启调试日志：

```bash
PGYER_DEBUG=1 dotnet run
```

## 可选环境变量

| 变量名 | 含义 |
| --- | --- |
| `PGYER_OVERSEA` | 是否使用海外加速上传：`1` 海外，`2` 国内；留空时根据 IP 自动判断 |
| `PGYER_INSTALL_TYPE` | 安装方式：`1` 公开，`2` 密码，`3` 邀请，默认为 `1` |
| `PGYER_INSTALL_PASSWORD` | 安装密码，当安装方式为密码安装时使用 |
| `PGYER_BUILD_DESCRIPTION` | 应用介绍 |
| `PGYER_UPDATE_DESCRIPTION` | 版本更新描述 |
| `PGYER_DEBUG` | 设置为 `1` 时输出调试日志 |

## 代码集成

```csharp
PGYERAppUploader uploader = new PGYERAppUploader("<your api key>");

UploadOption option = new UploadOption
{
    FilePath = "/path/to/app.apk",
    BuildInstallType = "1",
    BuildUpdateDescription = "Uploaded by C# demo"
};

Response<BuildInfoResponse> response = uploader.Upload(option);
Console.WriteLine(response.Data.BuildShortcutUrl);
```

## 注意事项

1. 文件扩展名必须是 `.ipa`、`.apk` 或 `.hap`。
2. 上传完成后会轮询构建结果，最多等待约 60 秒。
3. 网络、上传或构建处理超时时会抛出明确异常，建议使用 `try/catch` 包裹上传流程。

## 详细文档

更多信息请参考 [PGYER API 文档](https://www.pgyer.com/doc/view/api#fastUploadApp)。
