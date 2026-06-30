# PGYER Node.js Demo

这是 PGYER App 上传 API 的 Node.js 实现版本，可用于上传 iOS、Android 和 HarmonyOS 安装包。

## 功能

该项目提供了一个 Node.js 版本的 PGYER App 上传器，支持上传以下应用类型：

- iOS (.ipa)
- Android (.apk)
- HarmonyOS (.hap)

上传器会自动完成以下流程：

1. 选择可用的 PGYER API 服务域名
2. 获取上传 token
3. 上传安装包文件
4. 轮询获取构建结果

## 项目结构

```text
nodejs-demo/
├── PGYERAppUploader.js    # 核心上传器
├── demo.js                # 使用示例
├── package.json           # npm 依赖与包配置
└── package-lock.json      # npm 锁定文件
```

## 环境要求

- Node.js >= 14.0.0
- npm

## 安装依赖

```bash
cd nodejs-demo
npm install
```

如果后续发布为 npm 包，可改为：

```bash
npm install pgyer-app-uploader
```

## 快速开始

### Promise 用法

```js
const PGYERAppUploader = require('./PGYERAppUploader');

const uploader = new PGYERAppUploader('<your api key>');

uploader.upload({
  filePath: './app.apk',
  log: true,
  buildInstallType: 1,
  buildUpdateDescription: 'Uploaded by Node.js demo'
}).then((result) => {
  console.log('Upload success:', result);
}).catch((error) => {
  console.error('Upload failed:', error);
});
```

### Callback 用法

```js
const PGYERAppUploader = require('./PGYERAppUploader');

const uploader = new PGYERAppUploader('<your api key>');

uploader.upload({
  filePath: './app.ipa',
  log: true
}, (error, result) => {
  if (error) {
    console.error('Upload failed:', error);
    return;
  }

  console.log('Upload success:', result);
});
```

## 运行 Demo

编辑 `demo.js` 中的配置：

```js
const API_KEY = '<your api key>';
const APP_PATH = '/path/to/app.apk';
```

然后运行：

```bash
node demo.js
```

## API 参数说明

### 构造函数

```js
const uploader = new PGYERAppUploader(apiKey);
```

| 参数名 | 必选 | 含义 |
|--------|------|------|
| apiKey | Y | PGYER API Key |

### upload(options[, callback])

| 参数名 | 必选 | 含义 |
|--------|------|------|
| filePath | Y | App 文件路径，可以是相对路径或绝对路径 |
| log | N | 是否输出上传日志，默认为 false |
| buildInstallType | N | 应用安装方式，1=公开，2=密码，3=邀请 |
| buildPassword | N | 安装密码，当 buildInstallType=2 时使用 |
| buildUpdateDescription | N | 版本更新描述 |
| buildInstallDate | N | 安装有效期类型，1=设置时间，2=长期有效 |
| buildInstallStartDate | N | 安装有效期开始时间，格式：2018-01-01 |
| buildInstallEndDate | N | 安装有效期结束时间，格式：2018-12-31 |
| buildChannelShortcut | N | 指定渠道短链接 |

`upload()` 支持两种调用方式：

- 不传 `callback` 时返回 Promise
- 传入 `callback` 时使用 Node.js 风格回调：`callback(error, result)`

## 返回结果

上传成功后返回 PGYER API 的完整响应对象：

```json
{
  "code": 0,
  "message": "",
  "data": {
    "buildKey": "xxx",
    "buildType": "1",
    "buildIsFirst": "0",
    "buildIsLastest": "1",
    "buildFileKey": "xxx.apk",
    "buildFileName": "",
    "buildFileSize": "40095060",
    "buildName": "Example",
    "buildVersion": "1.0.0",
    "buildVersionNo": "1",
    "buildBuildVersion": "1",
    "buildIdentifier": "com.example.app",
    "buildIcon": "xxx",
    "buildDescription": "",
    "buildUpdateDescription": "",
    "buildScreenshots": "",
    "buildShortcutUrl": "example",
    "buildCreated": "xxxx-xx-xx xx:xx:xx",
    "buildUpdated": "xxxx-xx-xx xx:xx:xx",
    "buildQRCodeURL": "https://www.pgyer.com/app/qrcodeHistory/xxxx"
  }
}
```

常用字段：

```js
const data = result.data;
console.log(data.buildName);
console.log(data.buildVersion);
console.log(`https://www.pgyer.com/${data.buildShortcutUrl}`);
```

## 错误处理

上传过程中可能出现以下错误：

- API Key 无效
- 文件不存在或路径不是文件
- 文件类型不支持
- 网络连接失败或超时
- 上传服务返回非 204 状态码
- 构建结果轮询超时

Promise 用法：

```js
try {
  const result = await uploader.upload({ filePath: './app.apk' });
  console.log(result);
} catch (error) {
  console.error(error.message);
}
```

Callback 用法：

```js
uploader.upload({ filePath: './app.apk' }, (error, result) => {
  if (error) {
    console.error(error.message);
    return;
  }

  console.log(result);
});
```

## 注意事项

1. 请确保 API Key 正确。
2. 文件扩展名必须是 `.ipa`、`.apk` 或 `.hap`。
3. 上传器会自动检测可用 API 域名，并在需要时通过 DoH 获取可用 IP。
4. 上传完成后会轮询构建结果，最多等待约 60 秒。
5. 建议在 CI 环境中开启 `log: true`，便于排查网络或上传问题。

## 详细文档

更多信息请参考 [PGYER API 文档](https://www.pgyer.com/doc/view/api#fastUploadApp)。
