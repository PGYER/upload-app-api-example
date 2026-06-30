# PGYER Java Demo

这是 PGYER App 上传 API 的 Java 实现版本，可用于上传 iOS、Android 和 HarmonyOS 安装包。

## 功能

- 支持 `.ipa`、`.apk`、`.hap` 文件
- 自动选择可用的 PGYER API 服务域名
- 自动获取上传凭证、上传安装包并轮询构建结果
- 使用文件流上传安装包，适合较大的 App 文件
- 调试日志会对 API Key、上传签名、临时 token、安装密码等敏感字段脱敏

## 项目结构

```text
java-demo/
├── pom.xml
└── src/
    └── main/
        └── java/
            └── com/pgyer/uploader/
                ├── Demo.java
                └── PGYERAppUploader.java
```

## 环境要求

- JDK 8 或更高版本
- Maven

## 安装依赖与编译

```bash
cd java-demo
mvn clean compile
```

## 运行 Demo

```bash
export PGYER_API_KEY="<your api key>"
export PGYER_APP_PATH="/path/to/app.apk"
mvn exec:java -Dexec.mainClass="com.pgyer.uploader.Demo"
```

如需开启调试日志：

```bash
PGYER_DEBUG=1 mvn exec:java -Dexec.mainClass="com.pgyer.uploader.Demo"
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

```java
PGYERAppUploader uploader = new PGYERAppUploader("<your api key>");
uploader.setLogEnabled(true);

Map<String, Object> config = new HashMap<String, Object>();
config.put("filePath", "/path/to/app.apk");
config.put("buildInstallType", "1");
config.put("buildUpdateDescription", "Uploaded by Java demo");

Map<String, Object> result = uploader.upload(config);
System.out.println(result.get("buildShortcutUrl"));
```

## API 参数说明

| 参数名 | 必选 | 含义 |
| --- | --- | --- |
| `filePath` | Y | App 文件路径，可以是相对路径或绝对路径 |
| `oversea` | N | 是否使用海外加速上传：`1` 海外，`2` 国内；留空时根据 IP 自动判断 |
| `buildInstallType` | N | 安装方式：`1` 公开，`2` 密码，`3` 邀请 |
| `buildPassword` | N | 安装密码，当 `buildInstallType=2` 时使用 |
| `buildDescription` | N | 应用介绍 |
| `buildUpdateDescription` | N | 版本更新描述 |
| `buildInstallDate` | N | 安装有效期类型：`1` 设置时间，`2` 长期有效 |
| `buildInstallStartDate` | N | 安装有效期开始时间，格式：`2018-01-01` |
| `buildInstallEndDate` | N | 安装有效期结束时间，格式：`2018-12-31` |
| `buildChannelShortcut` | N | 指定渠道短链接 |

## 返回结果

上传成功后返回一个 `Map<String, Object>`，常用字段包括：

```java
System.out.println(result.get("buildName"));
System.out.println(result.get("buildVersion"));
System.out.println("https://www.pgyer.com/" + result.get("buildShortcutUrl"));
```

## 注意事项

1. 请确保 API Key 正确。
2. 文件扩展名必须是 `.ipa`、`.apk` 或 `.hap`。
3. 上传完成后会轮询构建结果，最多等待约 60 秒。
4. 网络、上传或构建处理超时时会抛出明确异常，建议使用 `try/catch` 包裹上传流程。

## 详细文档

更多信息请参考 [PGYER API 文档](https://www.pgyer.com/doc/view/api#fastUploadApp)。
