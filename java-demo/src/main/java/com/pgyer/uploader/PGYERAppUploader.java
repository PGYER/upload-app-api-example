package com.pgyer.uploader;

import com.google.gson.Gson;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import org.apache.http.HttpEntity;
import org.apache.http.HttpStatus;
import org.apache.http.client.config.RequestConfig;
import org.apache.http.client.methods.CloseableHttpResponse;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.conn.DnsResolver;
import org.apache.http.entity.ContentType;
import org.apache.http.entity.mime.MultipartEntityBuilder;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClients;
import org.apache.http.util.EntityUtils;

import java.io.File;
import java.io.IOException;
import java.net.InetAddress;
import java.net.URLEncoder;
import java.net.UnknownHostException;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.TimeoutException;
import java.util.regex.Pattern;

/**
 * PGYER App 上传器。
 * 此类用于演示如何使用 PGYER API 上传 App。
 * 详细文档参照 https://www.pgyer.com/doc/view/api#fastUploadApp
 * 支持上传 iOS (.ipa)、Android (.apk) 和 HarmonyOS (.hap) 应用。
 */
public class PGYERAppUploader {

    private static final int BUILD_INFO_MAX_ATTEMPTS = 60;
    private static final int BUILD_INFO_POLL_INTERVAL_MS = 1000;
    private static final Pattern FORM_SECRET_PATTERN = Pattern.compile(
            "((?:_api_key|key|signature|x-cos-security-token|buildPassword|buildKey)=)([^&\\s]+)",
            Pattern.CASE_INSENSITIVE);
    private static final Pattern JSON_SECRET_PATTERN = Pattern.compile(
            "(\"(?:_api_key|key|signature|x-cos-security-token|buildPassword|buildKey)\"\\s*:\\s*\")([^\"]+)(\")",
            Pattern.CASE_INSENSITIVE);

    private final String apiKey;
    private boolean logEnabled = false;
    private final String dnsService = "https://dns.alidns.com/resolve";
    private final String[] serviceHosts = {"api.pgyer.com", "api.xcxwo.com", "api.pgyerapp.com"};
    private String host;
    private String hostname;
    private final Gson gson = new Gson();

    /**
     * 构造函数。
     *
     * @param apiKey PGYER API 密钥
     */
    public PGYERAppUploader(String apiKey) {
        this(apiKey, true);
    }

    /**
     * 构造函数。
     *
     * @param apiKey PGYER API 密钥
     * @param logEnabled 是否启用日志
     */
    public PGYERAppUploader(String apiKey, boolean logEnabled) {
        if (apiKey == null || apiKey.trim().isEmpty()) {
            throw new IllegalArgumentException("API key is required.");
        }

        this.apiKey = apiKey;
        this.logEnabled = logEnabled;
        checkConnectivity();
    }

    /**
     * 设置是否启用日志。
     */
    public void setLogEnabled(boolean enabled) {
        this.logEnabled = enabled;
    }

    /**
     * 自定义 DNS 解析器，将指定的 hostname 解析到 host（IP 地址）。
     */
    private class CustomDnsResolver implements DnsResolver {
        @Override
        public InetAddress[] resolve(String hostname) throws UnknownHostException {
            if (PGYERAppUploader.this.hostname != null &&
                    PGYERAppUploader.this.hostname.equals(hostname)) {
                return new InetAddress[]{InetAddress.getByName(PGYERAppUploader.this.host)};
            }
            return new InetAddress[]{InetAddress.getByName(hostname)};
        }
    }

    private CloseableHttpClient createHttpClientWithResolver() {
        return HttpClients.custom()
                .setDnsResolver(new CustomDnsResolver())
                .build();
    }

    /**
     * 上传应用。
     *
     * @param config 上传配置，包含以下参数:
     *               - filePath (必选): App 文件的路径
     *               - buildInstallType (可选): 安装方式 (1:公开, 2:密码, 3:邀请)
     *               - buildPassword (可选): 安装密码
     *               - buildDescription (可选): 应用介绍
     *               - buildUpdateDescription (可选): 版本更新描述
     *               - buildInstallDate (可选): 是否设置安装有效期 (1:设置时间, 2:长期有效)
     *               - buildInstallStartDate (可选): 有效期开始时间 (格式: 2018-01-01)
     *               - buildInstallEndDate (可选): 有效期结束时间 (格式: 2018-12-31)
     *               - buildChannelShortcut (可选): 下载短链接
     * @return 上传结果，包含应用信息
     */
    @SuppressWarnings("unchecked")
    public Map<String, Object> upload(Map<String, Object> config) throws Exception {
        if (config == null) {
            throw new IllegalArgumentException("Upload config is required.");
        }

        String filePath = (String) config.get("filePath");
        if (filePath == null || filePath.trim().isEmpty()) {
            throw new IllegalArgumentException("filePath is required.");
        }

        File file = new File(filePath);
        if (!file.isFile()) {
            throw new IOException("No such file: " + filePath);
        }

        String ext = getFileExtension(filePath);
        if (!isValidExtension(ext)) {
            throw new Exception("Invalid file type. Supported types: ipa, apk, hap");
        }

        String buildType = getBuildType(ext);

        log("Start upload, using service: " + hostname + " (" + host + ") ...");

        Map<String, Object> params = new HashMap<String, Object>();
        params.put("_api_key", apiKey);
        params.put("buildType", buildType);

        String[] otherParams = {
                "oversea",
                "buildInstallType",
                "buildPassword",
                "buildDescription",
                "buildUpdateDescription",
                "buildInstallDate",
                "buildInstallStartDate",
                "buildInstallEndDate",
                "buildChannelShortcut"
        };
        for (String key : otherParams) {
            if (config.containsKey(key) && config.get(key) != null) {
                params.put(key, config.get(key));
            }
        }

        log("get upload token with params: " + formatParams(params));

        String res = sendPost("/apiv2/app/getCOSToken", params);
        log("get upload token with response: " + res);

        JsonObject responseJson = gson.fromJson(res, JsonObject.class);
        if (responseJson == null || !responseJson.has("code") ||
                responseJson.get("code").getAsInt() != 0 ||
                !responseJson.has("data") ||
                responseJson.get("data").isJsonNull()) {
            String message = responseJson != null && responseJson.has("message")
                    ? responseJson.get("message").getAsString()
                    : res;
            throw new Exception("Failed to get upload token: " + message);
        }

        JsonObject dataObj = responseJson.getAsJsonObject("data");
        JsonObject cosParams = dataObj.getAsJsonObject("params");
        String endpoint = dataObj.get("endpoint").getAsString();
        String buildKey = cosParams.has("key") ? cosParams.get("key").getAsString() : dataObj.get("key").getAsString();

        log("upload app to bucket with params: " + formatJsonObject(cosParams));

        UploadResult uploadResult = uploadFile(file, endpoint, cosParams);
        if (uploadResult.statusCode != HttpStatus.SC_NO_CONTENT) {
            throw new Exception("Failed to upload app, http code: " + uploadResult.statusCode +
                    ", response: " + uploadResult.body);
        }
        log("upload success");

        Map<String, Object> buildInfoParams = new HashMap<String, Object>();
        buildInfoParams.put("_api_key", apiKey);
        buildInfoParams.put("buildKey", buildKey);
        String url = "/apiv2/app/buildInfo?" + buildQueryString(buildInfoParams);
        log("get build info from: " + url);

        for (int i = 1; i <= BUILD_INFO_MAX_ATTEMPTS; i++) {
            log("[" + i + "] get app build info...");
            String resp = sendGet(url);
            JsonObject buildInfo = gson.fromJson(resp, JsonObject.class);
            if (buildInfo == null || !buildInfo.has("code")) {
                Thread.sleep(BUILD_INFO_POLL_INTERVAL_MS);
                continue;
            }

            int code = buildInfo.get("code").getAsInt();
            if (code == 0 && buildInfo.has("data") && !buildInfo.get("data").isJsonNull()) {
                log(resp);
                return gson.fromJson(buildInfo.get("data"), Map.class);
            }

            Thread.sleep(BUILD_INFO_POLL_INTERVAL_MS);
        }

        throw new TimeoutException("Build processing timed out after " + BUILD_INFO_MAX_ATTEMPTS + " seconds.");
    }

    private String sendPost(String url, Map<String, Object> params) throws IOException {
        String fullUrl = buildFullUrl(url);

        HttpPost httpPost = new HttpPost(fullUrl);
        httpPost.setConfig(requestConfig(10000, 30000));

        if (params != null && !params.isEmpty()) {
            MultipartEntityBuilder builder = MultipartEntityBuilder.create();
            for (Map.Entry<String, Object> entry : params.entrySet()) {
                if (entry.getValue() != null) {
                    builder.addTextBody(entry.getKey(), entry.getValue().toString(), ContentType.TEXT_PLAIN);
                }
            }
            httpPost.setEntity(builder.build());
        }

        try (CloseableHttpClient httpClient = createHttpClientWithResolver();
             CloseableHttpResponse response = httpClient.execute(httpPost)) {
            String body = response.getEntity() == null
                    ? ""
                    : EntityUtils.toString(response.getEntity(), StandardCharsets.UTF_8);
            int statusCode = response.getStatusLine().getStatusCode();
            if (statusCode < 200 || statusCode >= 300) {
                throw new IOException("POST " + url + " failed with HTTP " + statusCode + ": " + body);
            }
            return body;
        }
    }

    private String sendGet(String url) throws IOException {
        String fullUrl = buildFullUrl(url);

        HttpGet httpGet = new HttpGet(fullUrl);
        httpGet.setConfig(requestConfig(10000, 30000));

        try (CloseableHttpClient httpClient = createHttpClientWithResolver();
             CloseableHttpResponse response = httpClient.execute(httpGet)) {
            String body = response.getEntity() == null
                    ? ""
                    : EntityUtils.toString(response.getEntity(), StandardCharsets.UTF_8);
            int statusCode = response.getStatusLine().getStatusCode();
            if (statusCode < 200 || statusCode >= 300) {
                throw new IOException("GET " + url + " failed with HTTP " + statusCode + ": " + body);
            }
            return body;
        }
    }

    private String buildFullUrl(String url) {
        if (url.startsWith("/")) {
            return "https://" + hostname + url;
        }
        return url;
    }

    private RequestConfig requestConfig(int connectTimeout, int socketTimeout) {
        return RequestConfig.custom()
                .setConnectTimeout(connectTimeout)
                .setSocketTimeout(socketTimeout)
                .build();
    }

    private UploadResult uploadFile(File file, String endpoint, JsonObject params) throws IOException {
        HttpPost httpPost = new HttpPost(endpoint);
        httpPost.setConfig(requestConfig(60000, 120000));

        MultipartEntityBuilder builder = MultipartEntityBuilder.create();

        for (String key : params.keySet()) {
            JsonElement element = params.get(key);
            if (element.isJsonPrimitive()) {
                builder.addTextBody(key, element.getAsString(), ContentType.TEXT_PLAIN);
            }
        }

        builder.addTextBody("x-cos-meta-file-name", file.getName(), ContentType.TEXT_PLAIN);
        builder.addBinaryBody("file", file, ContentType.APPLICATION_OCTET_STREAM, file.getName());

        httpPost.setEntity(builder.build());

        try (CloseableHttpClient httpClient = createHttpClientWithResolver();
             CloseableHttpResponse response = httpClient.execute(httpPost)) {
            int statusCode = response.getStatusLine().getStatusCode();
            String responseBody = response.getEntity() == null
                    ? ""
                    : EntityUtils.toString(response.getEntity(), StandardCharsets.UTF_8);
            if (statusCode != HttpStatus.SC_NO_CONTENT) {
                log("Upload response: " + responseBody);
            }
            return new UploadResult(statusCode, responseBody);
        }
    }

    /**
     * 检查连接性。首先尝试直接连接，如果失败则通过 DNS 服务查询 IP 地址。
     */
    private void checkConnectivity() {
        for (String serviceHost : serviceHosts) {
            try {
                String url = "https://" + serviceHost + "/apiv2";
                HttpGet httpGet = new HttpGet(url);
                httpGet.setConfig(requestConfig(5000, 5000));

                try (CloseableHttpClient httpClient = HttpClients.createDefault();
                     CloseableHttpResponse response = httpClient.execute(httpGet)) {
                    String responseBody = response.getEntity() == null
                            ? ""
                            : EntityUtils.toString(response.getEntity(), StandardCharsets.UTF_8);
                    log(responseBody);
                    JsonObject jsonResponse = gson.fromJson(responseBody, JsonObject.class);
                    if (jsonResponse != null && jsonResponse.has("code") &&
                            jsonResponse.get("code").getAsInt() == 1001) {
                        this.host = serviceHost;
                        this.hostname = serviceHost;
                        return;
                    }
                }
            } catch (Exception e) {
                log("Direct connection to " + serviceHost + " failed, trying DNS service...");
            }

            try {
                String dnsUrl = dnsService + "?name=" + serviceHost + "&type=A";
                HttpGet httpGet = new HttpGet(dnsUrl);
                httpGet.setConfig(requestConfig(5000, 5000));

                try (CloseableHttpClient httpClient = HttpClients.createDefault();
                     CloseableHttpResponse response = httpClient.execute(httpGet)) {
                    String responseBody = response.getEntity() == null
                            ? ""
                            : EntityUtils.toString(response.getEntity(), StandardCharsets.UTF_8);
                    JsonObject dnsResponse = gson.fromJson(responseBody, JsonObject.class);

                    if (dnsResponse != null && dnsResponse.has("Answer")) {
                        for (JsonElement element : dnsResponse.getAsJsonArray("Answer")) {
                            JsonObject answer = element.getAsJsonObject();
                            if (answer.has("type") && answer.get("type").getAsInt() == 1) {
                                String ipAddress = answer.get("data").getAsString();
                                this.host = ipAddress;
                                this.hostname = serviceHost;
                                log("Found IP address for " + serviceHost + ": " + ipAddress);
                                return;
                            }
                        }
                    }
                }
            } catch (Exception e) {
                log("DNS query for " + serviceHost + " failed, trying next service host...");
            }
        }

        throw new RuntimeException("Cannot connect to PGYER API service.");
    }

    private String getFileExtension(String filePath) {
        int lastDot = filePath.lastIndexOf('.');
        if (lastDot > 0) {
            return filePath.substring(lastDot + 1).toLowerCase();
        }
        return "";
    }

    private boolean isValidExtension(String ext) {
        return ext.equals("ipa") || ext.equals("apk") || ext.equals("hap");
    }

    private String getBuildType(String ext) throws Exception {
        switch (ext.toLowerCase()) {
            case "ipa":
                return "ios";
            case "apk":
                return "android";
            case "hap":
                return "harmony";
            default:
                throw new Exception("Unsupported file type: " + ext);
        }
    }

    private String buildQueryString(Map<String, Object> params) throws IOException {
        StringBuilder builder = new StringBuilder();
        for (Map.Entry<String, Object> entry : params.entrySet()) {
            if (entry.getValue() == null) {
                continue;
            }
            if (builder.length() > 0) {
                builder.append("&");
            }
            builder.append(URLEncoder.encode(entry.getKey(), "UTF-8"));
            builder.append("=");
            builder.append(URLEncoder.encode(entry.getValue().toString(), "UTF-8"));
        }
        return builder.toString();
    }

    private String formatParams(Map<String, Object> params) {
        StringBuilder builder = new StringBuilder();
        for (Map.Entry<String, Object> entry : params.entrySet()) {
            if (builder.length() > 0) {
                builder.append("&");
            }
            builder.append(entry.getKey()).append("=");
            builder.append(isSensitiveKey(entry.getKey()) ? "***" : entry.getValue());
        }
        return builder.toString();
    }

    private String formatJsonObject(JsonObject object) {
        return redactSensitiveText(gson.toJson(object));
    }

    private boolean isSensitiveKey(String key) {
        return "_api_key".equalsIgnoreCase(key)
                || "key".equalsIgnoreCase(key)
                || "signature".equalsIgnoreCase(key)
                || "x-cos-security-token".equalsIgnoreCase(key)
                || "buildPassword".equalsIgnoreCase(key)
                || "buildKey".equalsIgnoreCase(key);
    }

    private String redactSensitiveText(String message) {
        String redacted = FORM_SECRET_PATTERN.matcher(message).replaceAll("$1***");
        return JSON_SECRET_PATTERN.matcher(redacted).replaceAll("$1***$3");
    }

    private void log(String message) {
        if (!logEnabled) {
            return;
        }
        System.out.println("[" + java.time.LocalDateTime.now() + "] " + redactSensitiveText(message));
    }

    private static class UploadResult {
        private final int statusCode;
        private final String body;

        private UploadResult(int statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }
    }
}
