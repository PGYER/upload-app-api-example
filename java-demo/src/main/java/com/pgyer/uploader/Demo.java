package com.pgyer.uploader;

import java.util.HashMap;
import java.util.Map;

/**
 * PGYER App 上传 Demo
 * 
 * 使用方法示例:
 * 
 * PGYERAppUploader uploader = new PGYERAppUploader("your_api_key");
 * 
 * Map<String, Object> config = new HashMap<>();
 * config.put("filePath", "./app.ipa");  // iOS应用
 * uploader.upload(config);
 * 
 * 支持的文件类型：.ipa (iOS)、.apk (Android)、.hap (HarmonyOS)
 * 
 * uploadOptions 参数说明: (https://www.pgyer.com/doc/view/api#fastUploadApp)
 * 
 * 参数名                  是否必选    含义
 * filePath              Y          App 文件的路径，可以是相对路径
 * buildInstallType      N          应用安装方式，值为(1,2,3，默认为1 公开安装)
 *                                   1：公开安装，2：密码安装，3：邀请安装
 * buildPassword         N          设置App安装密码，密码为空时默认公开安装
 * buildUpdateDescription N         版本更新描述，请传空字符串，或不传
 * buildInstallDate      N          是否设置安装有效期，值为：1 设置有效时间， 2 长期有效
 * buildInstallStartDate N          安装有效期开始时间，字符串型，如：2018-01-01
 * buildInstallEndDate   N          安装有效期结束时间，字符串型，如：2018-12-31
 * buildChannelShortcut  N          所需更新的指定渠道的下载短链接，只可指定一个渠道
 * 
 * 返回结果示例:
 * {
 *   buildKey: 'xxx',
 *   buildType: '1',
 *   buildIsFirst: '0',
 *   buildIsLastest: '1',
 *   buildFileKey: 'xxx.ipa',
 *   buildFileName: '',
 *   buildFileSize: '40095060',
 *   buildName: 'xxx',
 *   buildVersion: '2.2.0',
 *   buildVersionNo: '1.0.1',
 *   buildBuildVersion: '9',
 *   buildIdentifier: 'xxx.xxx.xxx',
 *   buildIcon: 'xxx',
 *   buildDescription: '',
 *   buildUpdateDescription: '',
 *   buildScreenshots: '',
 *   buildShortcutUrl: 'xxxx',
 *   buildCreated: 'xxxx-xx-xx xx:xx:xx',
 *   buildUpdated: 'xxxx-xx-xx xx:xx:xx',
 *   buildQRCodeURL: 'https://www.pgyer.com/app/qrcodeHistory/xxxx'
 * }
 */
public class Demo {

    public static void main(String[] args) {
        try {
            // 创建上传器实例
            PGYERAppUploader uploader = new PGYERAppUploader("<your api key>");
            uploader.setLogEnabled(true);

            // 示例4：带有密码和更新描述的上传
            Map<String, Object> fullConfig = new HashMap<>();
            fullConfig.put("filePath", "<your app file path>");  // 应用文件路径
            fullConfig.put("buildInstallType", 2);  // 密码安装
            fullConfig.put("buildPassword", "123456");
            fullConfig.put("buildUpdateDescription", "update by api");
            Map<String, Object> fullResult = uploader.upload(fullConfig);
            System.out.println("App uploaded with full config: " + fullResult);
        } catch (Exception e) {
            e.printStackTrace();
            System.err.println("Error: " + e.getMessage());
        }
    }
}
