# PGYER Java Demo

这是 PGYER App 上传 API 的 Java 实现版本。

## 功能

该项目提供了一个 Java 版本的 PGYER App 上传器，支持上传以下应用类型：

- iOS (.ipa)
- Android (.apk)
- HarmonyOS (.hap)

## 项目结构

```text
java-demo/
├── pom.xml                          # Maven 配置文件
└── src/
    └── main/
        └── java/
            └── com/pgyer/uploader/
                ├── Demo.java                # 演示用法
                └── PGYERAppUploader.java    # 核心上传器类
```

## 依赖

该项目使用 Maven 进行依赖管理，主要依赖包括：

- Apache HttpClient 4.5.14
- Google Gson 2.10.1
- SLF4J 2.0.7

## 快速开始

### 1. 编译项目

```bash
mvn clean compile
```

### 2. 使用示例

```java
// 创建上传器实例
PGYERAppUploader uploader = new PGYERAppUploader("<your api key>");
uploader.setLogEnabled(true);

// 配置上传参数
Map<String, Object> config = new HashMap<>();
config.put("filePath", "./app.ipa");  // iOS 应用
config.put("buildInstallType", 2);    // 密码安装
config.put("buildPassword", "123456");
config.put("buildUpdateDescription", "update by api");

// 执行上传
Map<String, Object> result = uploader.upload(config);
System.out.println(result);
```

## API 参数说明

### upload() 方法参数

| 参数名 | 必选 | 含义 |
|--------|------|------|
| filePath | Y | App 文件的路径，可以是相对路径 |
| buildInstallType | N | 应用安装方式 (1:公开, 2:密码, 3:邀请，默认为1) |
| buildPassword | N | 设置App安装密码，密码为空时默认公开安装 |
| buildUpdateDescription | N | 版本更新描述 |
| buildInstallDate | N | 是否设置安装有效期 (1:设置时间, 2:长期有效) |
| buildInstallStartDate | N | 安装有效期开始时间，格式：2018-01-01 |
| buildInstallEndDate | N | 安装有效期结束时间，格式：2018-12-31 |
| buildChannelShortcut | N | 所需更新的指定渠道的下载短链接 |

## 返回结果

上传成功后返回一个 Map，包含以下信息：

```json
{
  "buildKey": "xxx",
  "buildType": "1",
  "buildIsFirst": "0",
  "buildIsLastest": "1",
  "buildFileKey": "xxx.ipa",
  "buildFileName": "",
  "buildFileSize": "40095060",
  "buildName": "xxx",
  "buildVersion": "2.2.0",
  "buildVersionNo": "1.0.1",
  "buildBuildVersion": "9",
  "buildIdentifier": "xxx.xxx.xxx",
  "buildIcon": "xxx",
  "buildDescription": "",
  "buildUpdateDescription": "",
  "buildScreenshots": "",
  "buildShortcutUrl": "xxxx",
  "buildCreated": "xxxx-xx-xx xx:xx:xx",
  "buildUpdated": "xxxx-xx-xx xx:xx:xx",
  "buildQRCodeURL": "https://www.pgyer.com/app/qrcodeHistory/xxxx"
}
```

## 运行 Demo

```bash
mvn exec:java -Dexec.mainClass="com.pgyer.uploader.Demo"
```

## 详细文档

更多信息请参考 [PGYER API 文档](https://www.pgyer.com/doc/view/api#fastUploadApp)

## 与 PHP 版本对比

此 Java 版本与 PHP 版本功能完全相同，主要区别：

| 功能 | PHP | Java |
|------|-----|------|
| HTTP 客户端 | cURL | Apache HttpClient |
| JSON 处理 | json_encode/decode | Gson |
| 日志记录 | echo + 时间戳 | System.out.println + LocalDateTime |
| 连接检测 | file_get_contents + DNS | HttpURLConnection |
| 文件上传 | CURLFile | MultipartEntityBuilder |

## 注意事项

1. 确保填入正确的 API Key
2. 文件路径可以是相对路径或绝对路径
3. 上传过程中会轮询获取应用信息，最多轮询 60 次
4. 建议在生产环境中开启日志以便调试
