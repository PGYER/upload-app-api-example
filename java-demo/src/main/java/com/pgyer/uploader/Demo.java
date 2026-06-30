package com.pgyer.uploader;

import java.util.HashMap;
import java.util.Map;

/**
 * PGYER App 上传 Demo。
 *
 * 详细文档参照 https://www.pgyer.com/doc/view/api#fastUploadApp
 * 支持上传 iOS (.ipa)、Android (.apk) 和 HarmonyOS (.hap) 应用。
 */
public class Demo {

    public static void main(String[] args) {
        String apiKey = System.getenv("PGYER_API_KEY");
        String appPath = System.getenv("PGYER_APP_PATH");

        if (apiKey == null || apiKey.trim().isEmpty()) {
            System.err.println("Please set PGYER_API_KEY.");
            System.exit(1);
        }

        if (appPath == null || appPath.trim().isEmpty()) {
            System.err.println("Please set PGYER_APP_PATH.");
            System.exit(1);
        }

        try {
            PGYERAppUploader uploader = new PGYERAppUploader(apiKey);
            uploader.setLogEnabled("1".equals(System.getenv("PGYER_DEBUG")));

            Map<String, Object> config = new HashMap<String, Object>();
            config.put("filePath", appPath);
            config.put("oversea", getEnvOrDefault("PGYER_OVERSEA", ""));
            config.put("buildInstallType", getEnvOrDefault("PGYER_INSTALL_TYPE", "1"));
            config.put("buildPassword", getEnvOrDefault("PGYER_INSTALL_PASSWORD", ""));
            config.put("buildDescription", getEnvOrDefault("PGYER_BUILD_DESCRIPTION", ""));
            config.put("buildUpdateDescription", getEnvOrDefault("PGYER_UPDATE_DESCRIPTION", ""));

            Map<String, Object> result = uploader.upload(config);
            System.out.println("Upload success: " + result);

            Object shortcut = result.get("buildShortcutUrl");
            if (shortcut != null) {
                System.out.println("Download URL: https://www.pgyer.com/" + shortcut);
            }
        } catch (Exception e) {
            System.err.println("Upload failed: " + e.getMessage());
            System.exit(1);
        }
    }

    private static String getEnvOrDefault(String name, String defaultValue) {
        String value = System.getenv(name);
        return value == null ? defaultValue : value;
    }
}
