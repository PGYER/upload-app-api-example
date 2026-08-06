# 蒲公英 API 上传 App 代码示例

## 语言

- [English](README_EN.md)
- [简体中文](README.md)

## 项目说明

[蒲公英 App 内测分发平台](https://www.pgyer.com) 是面向 App 安装包的内测托管、下载分发平台，支持上传：

- iOS 安装包：`.ipa`
- Android 安装包：`.apk`
- HarmonyOS 安装包：`.hap`

本项目演示如何通过蒲公英新版上传 API 上传 iOS、Android、HarmonyOS 安装包，并获取上传后的构建结果和下载地址。

新版上传 API 采用“获取上传凭证 -> 上传安装包 -> 查询构建结果”的流程，相比旧版 v1、v2 上传接口速度更快。旧版接口仍可使用，但新项目建议优先接入新版上传 API。

## 快速开始

如果只是希望在命令行或 CI 中快速上传，可以在仓库根目录直接使用 Shell 示例：

```bash
chmod +x ./shell-demo/pgyer_upload.sh
./shell-demo/pgyer_upload.sh -k <your-pgyer-api-key> <your-ipa-or-apk-or-hap-file-path>
```

Shell 示例兼容 [`pgyer-cli`](https://github.com/PGYER/pgyer-cli) 的登录配置。如果已经执行过 `pgyer auth login`，可以直接复用 `~/.config/pgyer/config.json` 中的 API Key：

```bash
./shell-demo/pgyer_upload.sh <your-ipa-or-apk-or-hap-file-path>
```

如果没有使用 `pgyer-cli`，也可以手动创建兼容配置：

```bash
mkdir -p ~/.config/pgyer
printf '%s\n' '{"apiKey":"<your-pgyer-api-key>"}' > ~/.config/pgyer/config.json
chmod 600 ~/.config/pgyer/config.json
```

读取优先级为：`-k` > `PGYER_API_KEY` 环境变量 > `pgyer-cli` 配置文件 > 旧版 Shell 配置文件。详情请查看 [Shell 示例说明](shell-demo/README.md)。

如果安装包路径中包含空格，请用引号包住完整路径，例如：

```bash
./shell-demo/pgyer_upload.sh "/path/with spaces/app.apk"
```

上传成功后会输出应用名称、版本号和下载页面 URL。如需完整 JSON 响应，可增加 `-j` 参数：

```bash
./shell-demo/pgyer_upload.sh -k <your-pgyer-api-key> -j <your-app-file-path>
```

## 示例代码

各语言目录中包含可运行 Demo、参数说明和返回结果示例：

| 语言 | 目录 | 说明 |
| --- | --- | --- |
| Shell | [shell-demo](shell-demo) | 适合命令行、CI/CD 和一行命令上传 |
| Java | [java-demo](java-demo) | Maven 项目示例 |
| Node.js | [nodejs-demo](nodejs-demo) | 支持 Promise 和 Callback 调用方式 |
| PHP | [php-demo](php-demo) | PHP 7.4+ 示例 |
| Python | [python-demo](python-demo) | Python 3 脚本示例 |
| C# | [csharp-demo](csharp-demo) | .NET 示例 |

## API 流程

新版上传 API 的核心流程如下：

1. 调用蒲公英接口获取上传凭证。
2. 使用上传凭证将 `.ipa`、`.apk` 或 `.hap` 文件上传到存储服务。
3. 轮询查询构建结果，获取应用名称、版本号、短链接、二维码等信息。

各语言示例都已经封装了上述流程，通常只需要传入 API Key、安装包路径和可选发布参数。

## 常用参数

| 参数 | 必填 | 说明 |
| --- | --- | --- |
| API Key | 是 | 可在蒲公英账号后台获取 |
| 文件路径 | 是 | `.ipa`、`.apk` 或 `.hap` 安装包路径 |
| 安装方式 | 否 | `1` 公开安装，`2` 密码安装，`3` 邀请安装 |
| 安装密码 | 否 | 安装方式为密码安装时使用 |
| 更新说明 | 否 | 本次上传版本的更新描述 |
| 渠道短链接 | 否 | 指定要更新的渠道短链接 |

更完整的参数列表请查看各语言目录中的 README，或参考 [蒲公英 API 上传文档](https://www.pgyer.com/doc/view/api#fastUploadApp)。

## 相关资源

- [Shell 一行命令上传脚本](shell-demo)
- [Postman API 调用模板](https://www.postman.com/pgyerdevs/workspace/pgyer-api)
- [GitHub Actions 工作流](https://github.com/PGYER/pgyer-upload-app-action)
- [Fastlane 插件](https://github.com/shishirui/fastlane-plugin-pgyer)
- [MCP 服务器](https://github.com/PGYER/pgyer-mcp-server)
- [Agent Skill](https://github.com/PGYER/pgyer-skill)

## 相关链接

- [蒲公英官方网站](https://www.pgyer.com)
- [查看蒲公英 API Key](https://www.pgyer.com/account/api)
- [蒲公英 API 上传文档](https://www.pgyer.com/doc/view/api#fastUploadApp)

## 贡献

欢迎提交新的语言示例、问题修复或文档优化。新增语言示例时，建议同时提供：

- 可直接运行的 Demo
- 依赖安装说明
- API 参数说明
- 成功返回示例
- 常见错误处理说明
