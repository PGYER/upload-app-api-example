# shell 脚本使用说明

本示例演示如何在 Shell 中通过新版上传 API 将 App 安装包上传到蒲公英平台（PGYER），默认支持 Linux、macOS。

如果只是希望日常通过命令行快速上传和管理应用，推荐使用官方 [`pgyer-cli`](https://github.com/PGYER/pgyer-cli)。本 Shell Demo 更适合学习上传流程、集成到现有 Shell/CI 脚本，或无法安装 Node.js 的场景。

## 使用说明

先进入 `shell-demo` 目录，再为脚本赋予执行权限：

    cd shell-demo
    chmod +x ./pgyer_upload.sh

执行命令：

    ./pgyer_upload.sh -k <your-pgyer-api-key> <your-ipa-or-apk-or-hap-file-path>

直接执行脚本（不带参数）或使用 `-h`，均会显示完整帮助信息。

### 复用 pgyer-cli 配置

Shell Demo 兼容 [`pgyer-cli`](https://github.com/PGYER/pgyer-cli) 的配置文件 `~/.config/pgyer/config.json`。如果已经执行过：

```bash
pgyer auth login
```

Shell Demo 会直接复用其中的 `apiKey`，无需再次配置：

```bash
./pgyer_upload.sh ~/Downloads/app.apk
```

如果没有使用 `pgyer-cli`，也可以手动创建相同格式的配置文件：

```bash
mkdir -p ~/.config/pgyer
printf '%s\n' '{"apiKey":"<your-pgyer-api-key>"}' > ~/.config/pgyer/config.json
chmod 600 ~/.config/pgyer/config.json
```

如果当前位于仓库根目录，请使用完整的脚本相对路径：

```bash
./shell-demo/pgyer_upload.sh ~/Downloads/app.apk
```

安装包路径包含空格时，需要用引号包住完整路径：

```bash
./pgyer_upload.sh "/path/with spaces/app.apk"
```

API Key 的读取优先级为：

1. 命令行 `-k`
2. `PGYER_API_KEY` 环境变量
3. `~/.config/pgyer/config.json` 中的 `apiKey`（与 `pgyer-cli` 共用）
4. `~/.config/pgyer/config` 中的 `PGYER_API_KEY`（旧版 Shell 配置回退）

也可以通过 `PGYER_CONFIG_FILE` 指定其他 JSON 或 `PGYER_API_KEY=value` 配置文件。

配置文件仅由脚本解析，不会作为 Shell 脚本执行。请勿将包含真实 API Key 的配置文件提交到 Git。

## 输出

上传过程中默认显示简洁的旋转指示器和已用时间；增加 `-P` 参数后，会显示包含百分比、速度和预计时间的详细进度条。上传成功后，默认输出应用名称、版本号和下载页面 URL。如需输出完整 JSON 结果，请增加 `-j` 参数。

示例输出：
```
$ ./pgyer_upload.sh -k *************** /path/to/your/app-package-file.apk

▶ Selecting available API domain

✓ Using domain: api.pgyer.com
ℹ Resolving api.pgyer.com...

▶ Step 1/3: Getting upload token

✓ Token obtained successfully

▶ Step 2/3: Uploading file

ℹ File: example.apk (10M)
✓ File uploaded successfully

▶ Step 3/3: Processing build

ℹ Waiting for build processing...
  ⠼ Processing... (4s)
✓ Build completed!

  App:     Example
  Version: 1.17.0 (1017050)
  URL:     https://pgyer.com/******
```

## 参数说明

### 必需参数

- `<file>` - `.ipa`、`.apk` 或 `.hap` 安装包路径

### 可选参数

- `-k <api_key>` - 蒲公英 API Key；未指定时依次读取环境变量和本地配置
- `-t <buildInstallType>` - 安装方式：1=公开，2=密码，3=邀请
- `-p <buildPassword>` - 安装密码（当 buildInstallType=2 时必填）
- `-d <buildUpdateDescription>` - 版本更新描述
- `-e <buildInstallDate>` - 安装有效期：1=自定义时间段，2=永久
- `-s <buildInstallStartDate>` - 安装开始日期，格式：yyyy-MM-dd
- `-E <buildInstallEndDate>` - 安装结束日期，格式：yyyy-MM-dd
- `-c <buildChannelShortcut>` - 渠道标识
- `-P` - 显示包含百分比、速度和预计时间的详细上传进度条
- `-j` - 输出完整 JSON 响应结果
- `-v` - 详细模式，显示脱敏后的 curl 命令和连接测试信息
- `-h` - 显示帮助信息

### 示例

基本用法：
```bash
./pgyer_upload.sh -k <your-api-key> ~/Downloads/app.apk
```

显示详细上传进度：
```bash
./pgyer_upload.sh -k <your-api-key> -P ~/Downloads/app.apk
```

详细模式：
```bash
./pgyer_upload.sh -k <your-api-key> -v ~/Downloads/app.apk
```

设置密码安装：
```bash
./pgyer_upload.sh -k <your-api-key> -t 2 -p 123456 ~/Downloads/app.apk
```

## 日志与调试

上传阶段会对临时网络错误进行有限重试（最多 3 次），并在失败时输出 `curl exit` 与 HTTP 状态码，便于区分网络断开、超时和服务端响应错误。

### 日志控制

默认为开启状态（`LOG_ENABLE=1`）。您可以修改脚本中的 `LOG_ENABLE=0` 来关闭日志。

### 详细模式

使用 `-v` 参数启用详细模式，可以看到：
- 域名连接测试详情
- DoH 域名解析结果
- 脱敏后的 curl 命令

这在遇到网络问题时非常有用。

### 进度条

上传文件时，默认不显示进度条。如需显示上传进度，请添加 `-P` 参数。

## Windows 用户

1. 安装 [git bash](https://gitforwindows.org)，以便让 windows 具备 bash 环境
2. 以`bash.exe`来执行 `pgyer_upload.sh` 脚本

命令如下（注意您的安装目录可能有所不同，请相应替换）：

    D:\> & 'C:\Program Files\Git\bin\bash.exe' .\pgyer_upload.sh -k <your-pgyer-api-key> <your-ipa-or-apk-or-hap-file>

完成后，就会直接返回 App 的上传结果

## 问题排查

如果遇到上传问题，建议：

1. 使用 `-v` 参数启用详细模式查看详细信息
2. 检查网络连接是否正常
3. 确认 API Key 是否正确
4. 确认文件路径是否正确，文件是否有读取权限
