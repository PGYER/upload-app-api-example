# PGYER PHP Demo

这是 PGYER App 上传 API 的 PHP 实现版本，可用于上传 iOS、Android 和 HarmonyOS 安装包。

## 功能

该项目提供了一个 PHP 版本的 PGYER App 上传器，支持上传以下应用类型：

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
php-demo/
├── PGYERAppUploader.php    # 核心上传器
├── demo.php                # 使用示例
└── README.md               # 使用说明
```

## 环境要求

- PHP 7.4 或更高版本
- PHP curl 扩展
- PHP json 扩展
- PHP openssl 扩展

可以通过以下命令检查扩展是否可用：

```bash
php -m | grep -E 'curl|json|openssl'
```

## 快速开始

在 PHP 项目中引入上传器：

```php
<?php

require_once __DIR__ . '/PGYERAppUploader.php';

$uploader = new PGYERAppUploader('<your api key>');
$uploader->log = true;

try {
    $info = $uploader->upload([
        'filePath' => './app.apk',
        'buildInstallType' => 1,
        'buildUpdateDescription' => 'Uploaded by PHP demo',
    ]);

    echo 'Upload success: ' . PHP_EOL;
    print_r($info);
} catch (Exception $e) {
    echo 'Upload failed: ' . $e->getMessage() . PHP_EOL;
}
```

## 运行 Demo

编辑 `demo.php` 中的配置：

```php
$uploader = new PGYERAppUploader('<your api key>');

$info = $uploader->upload([
    'filePath' => '<your app file path>',
    'buildInstallType' => 2,
    'buildPassword' => '123456',
    'buildUpdateDescription' => 'update by api',
]);
```

然后运行：

```bash
php demo.php
```

也可以从仓库根目录运行：

```bash
php php-demo/demo.php
```

## API 参数说明

### 构造函数

```php
$uploader = new PGYERAppUploader($apiKey);
```

| 参数名 | 必选 | 含义 |
|--------|------|------|
| apiKey | Y | PGYER API Key |

### upload($config)

| 参数名 | 必选 | 含义 |
|--------|------|------|
| filePath | Y | App 文件路径，可以是相对路径或绝对路径 |
| buildInstallType | N | 应用安装方式，1=公开，2=密码，3=邀请 |
| buildPassword | N | 安装密码，当 buildInstallType=2 时使用 |
| buildUpdateDescription | N | 版本更新描述 |
| buildInstallDate | N | 安装有效期类型，1=设置时间，2=长期有效 |
| buildInstallStartDate | N | 安装有效期开始时间，格式：2018-01-01 |
| buildInstallEndDate | N | 安装有效期结束时间，格式：2018-12-31 |
| buildChannelShortcut | N | 指定渠道短链接 |

日志通过实例属性控制：

```php
$uploader->log = true;
```

开启日志后，上传器会输出请求过程、上传重试和构建轮询信息。日志中的 API Key、上传签名、临时 token、安装密码等敏感字段会被脱敏。

## 返回结果

上传成功后，`upload()` 返回 PGYER API 的 `data` 数组：

```php
[
    'buildKey' => 'xxx',
    'buildType' => '1',
    'buildIsFirst' => '0',
    'buildIsLastest' => '1',
    'buildFileKey' => 'xxx.apk',
    'buildFileName' => '',
    'buildFileSize' => '40095060',
    'buildName' => 'Example',
    'buildVersion' => '1.0.0',
    'buildVersionNo' => '1',
    'buildBuildVersion' => '1',
    'buildIdentifier' => 'com.example.app',
    'buildIcon' => 'xxx',
    'buildDescription' => '',
    'buildUpdateDescription' => '',
    'buildScreenshots' => '',
    'buildShortcutUrl' => 'example',
    'buildCreated' => 'xxxx-xx-xx xx:xx:xx',
    'buildUpdated' => 'xxxx-xx-xx xx:xx:xx',
    'buildQRCodeURL' => 'https://www.pgyer.com/app/qrcodeHistory/xxxx',
]
```

常用字段：

```php
echo $info['buildName'] . PHP_EOL;
echo $info['buildVersion'] . PHP_EOL;
echo 'https://www.pgyer.com/' . $info['buildShortcutUrl'] . PHP_EOL;
```

## 错误处理

上传过程中可能出现以下错误：

- API Key 无效
- 文件不存在或不可读
- 文件类型不支持
- 网络连接失败或超时
- 上传服务返回非 204 状态码
- 构建结果轮询超时

建议始终使用 `try/catch` 包裹上传流程：

```php
try {
    $info = $uploader->upload([
        'filePath' => './app.apk',
    ]);
} catch (Exception $e) {
    echo $e->getMessage() . PHP_EOL;
}
```

上传阶段会对临时网络错误进行有限重试，失败时异常信息会包含 curl errno、HTTP status 或服务端响应，便于定位网络断开、超时和服务端错误。

## 注意事项

1. 请确保 API Key 正确。
2. 文件扩展名必须是 `.ipa`、`.apk` 或 `.hap`，大小写均可。
3. 上传器会自动检测可用 API 域名，并在需要时通过 DoH 获取可用 IP。
4. 上传完成后会轮询构建结果，最多等待约 60 秒。
5. 建议在 CI 或排查问题时开启 `$uploader->log = true`。

## 详细文档

更多信息请参考 [PGYER API 文档](https://www.pgyer.com/doc/view/api#fastUploadApp)。
