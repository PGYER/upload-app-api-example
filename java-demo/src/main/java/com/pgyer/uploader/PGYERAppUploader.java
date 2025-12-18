package com.pgyer.uploader;

import com.google.gson.Gson;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import org.apache.http.HttpEntity;
import org.apache.http.client.config.RequestConfig;
import org.apache.http.client.methods.CloseableHttpResponse;
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
import java.net.UnknownHostException;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;

/**
 * PGYER App 上传器
 * 此类用于演示如何使用 PGYER API 上传 App
 * 详细文档参照 https://www.pgyer.com/doc/view/api#fastUploadApp
 * 支持上传 iOS (.ipa)、Android (.apk) 和 HarmonyOS (.hap) 应用
 */
public class PGYERAppUploader {

    private String apiKey;
    private boolean logEnabled = false;
    private String dnsService = "https://dns.alidns.com/resolve";
    private String[] serviceHosts = {"api.pgyer.com", "api.xcxwo.com", "api.pgyerapp.com"};
    private String host;
    private String hostname;
    private Gson gson = new Gson();

    /**
     * 构造函数
     * @param apiKey PGYER API 密钥
     */
    public PGYERAppUploader(String apiKey) {
        this(apiKey, true);
    }

    /**
     * 构造函数
     * @param apiKey PGYER API 密钥
     * @param logEnabled 是否启用日志
     */
    public PGYERAppUploader(String apiKey, boolean logEnabled) {
        this.apiKey = apiKey;
        this.logEnabled = logEnabled;
        checkConnectivity();
    }

    /**
     * 设置是否启用日志
     */
    public void setLogEnabled(boolean enabled) {
        this.logEnabled = enabled;
    }

    /**
     * 自定义 DNS 解析器，将指定的 hostname 解析到 host（IP 地址）
     */
    private class CustomDnsResolver implements DnsResolver {
        @Override
        public InetAddress[] resolve(String hostname) throws UnknownHostException {
            // 如果是目标服务器，解析到指定的 IP 地址
            if (PGYERAppUploader.this.hostname != null && 
                PGYERAppUploader.this.hostname.equals(hostname)) {
                return new InetAddress[] { InetAddress.getByName(PGYERAppUploader.this.host) };
            }
            // 其他域名使用默认解析
            return new InetAddress[] { InetAddress.getByName(hostname) };
        }
    }

    /**
     * 创建使用自定义 DNS 解析器的 HttpClient
     */
    private CloseableHttpClient createHttpClientWithResolver() {
        return HttpClients.custom()
                .setDnsResolver(new CustomDnsResolver())
                .build();
    }

    /**
     * 上传应用
     * 使用方法:
     * Map<String, Object> config = new HashMap<>();
     * config.put("filePath", "./app.ipa");
     * config.put("buildInstallType", 2);
     * config.put("buildPassword", "123456");
     * Map<String, Object> result = uploader.upload(config);
     *
     * @param config 上传配置，包含以下参数:
     *    - filePath (必选): App 文件的路径
     *    - buildInstallType (可选): 安装方式 (1:公开, 2:密码, 3:邀请)
     *    - buildPassword (可选): 安装密码
     *    - buildUpdateDescription (可选): 版本更新描述
     *    - buildInstallDate (可选): 是否设置安装有效期 (1:设置时间, 2:长期有效)
     *    - buildInstallStartDate (可选): 有效期开始时间 (格式: 2018-01-01)
     *    - buildInstallEndDate (可选): 有效期结束时间 (格式: 2018-12-31)
     *    - buildChannelShortcut (可选): 下载短链接
     * @return 上传结果，包含应用信息
     */
    public Map<String, Object> upload(Map<String, Object> config) throws Exception {
        String filePath = (String) config.get("filePath");
        
        // 验证文件类型
        String ext = getFileExtension(filePath);
        if (!isValidExtension(ext)) {
            throw new Exception("Invalid file type. Supported types: ipa, apk, hap");
        }

        // 根据文件扩展名确定 buildType
        String buildType = getBuildType(ext);
        
        log("Start upload, using service: " + hostname + " (" + host + ") ...");

        // step 1: 获取上传令牌
        Map<String, Object> params = new HashMap<>();
        params.put("_api_key", apiKey);
        params.put("buildType", buildType);

        String[] otherParams = {"buildInstallType", "buildPassword", "buildUpdateDescription",
                "buildInstallDate", "buildInstallStartDate", "buildInstallEndDate", "buildChannelShortcut"};
        for (String key : otherParams) {
            if (config.containsKey(key)) {
                params.put(key, config.get(key));
            }
        }

        log("get upload token with params: " + gson.toJson(params));

        String res = sendRequest("/apiv2/app/getCOSToken", params);
        log(res);

        JsonObject responseJson = gson.fromJson(res, JsonObject.class);
        if (responseJson.get("code").getAsInt() != 0 || !responseJson.has("data") || responseJson.get("data").isJsonNull()) {
            throw new Exception("Failed to get upload token: " + responseJson.get("message").getAsString());
        }

        JsonObject dataObj = responseJson.getAsJsonObject("data");
        String key = dataObj.get("key").getAsString();

        // step 2: 上传应用到 bucket
        JsonObject cosParams = dataObj.getAsJsonObject("params");
        String endpoint = dataObj.get("endpoint").getAsString();
        String fileName = new File(filePath).getName();

        log("upload app to bucket with params: " + gson.toJson(cosParams));

        int httpCode = uploadFile(filePath, endpoint, cosParams, fileName);
        if (httpCode == 204) {
            log("upload success");
        } else {
            log("upload failed");
            throw new Exception("Failed to upload app, http code: " + httpCode);
        }

        // step 3: 获取已上传的应用数据
        String url = "/apiv2/app/buildInfo?_api_key=" + apiKey + "&buildKey=" + key;
        log("get build info from: " + url);

        for (int i = 0; i < 60; i++) {
            String resp = sendRequest(url);
            JsonObject buildInfo = gson.fromJson(resp, JsonObject.class);
            if (buildInfo.get("code").getAsInt() != 0) {
                try {
                    Thread.sleep(1000);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
                log("[" + i + "] get app build info...");
                continue;
            }

            log(resp);
            return gson.fromJson(buildInfo.get("data"), Map.class);
        }

        return null;
    }

    /**
     * 发送 HTTP 请求
     */
    private String sendRequest(String url, Map<String, Object> params) throws IOException {
        String fullUrl;
        
        if (url.startsWith("/")) {
            // 使用 hostname 构建 URL，通过自定义 DNS 解析器将其解析到 host（IP 地址）
            fullUrl = "https://" + hostname + url;
        } else {
            fullUrl = url;
        }

        CloseableHttpClient httpClient = createHttpClientWithResolver();
        HttpPost httpPost = new HttpPost(fullUrl);

        // 设置超时
        RequestConfig requestConfig = RequestConfig.custom()
                .setConnectTimeout(10000)
                .setSocketTimeout(30000)
                .build();
        httpPost.setConfig(requestConfig);

        // 构建请求参数
        if (params != null && !params.isEmpty()) {
            MultipartEntityBuilder builder = MultipartEntityBuilder.create();
            for (Map.Entry<String, Object> entry : params.entrySet()) {
                builder.addTextBody(entry.getKey(), entry.getValue().toString(), ContentType.TEXT_PLAIN);
            }
            httpPost.setEntity(builder.build());
        }

        try (CloseableHttpResponse response = httpClient.execute(httpPost)) {
            return EntityUtils.toString(response.getEntity(), StandardCharsets.UTF_8);
        }
    }

    /**
     * 发送 POST 请求（无参数）
     */
    private String sendRequest(String url) throws IOException {
        String fullUrl;
        
        if (url.startsWith("/")) {
            // 使用 hostname 构建 URL，通过自定义 DNS 解析器将其解析到 host（IP 地址）
            fullUrl = "https://" + hostname + url;
        } else {
            fullUrl = url;
        }

        CloseableHttpClient httpClient = createHttpClientWithResolver();
        HttpPost httpPost = new HttpPost(fullUrl);

        RequestConfig requestConfig = RequestConfig.custom()
                .setConnectTimeout(10000)
                .setSocketTimeout(30000)
                .build();
        httpPost.setConfig(requestConfig);

        try (CloseableHttpResponse response = httpClient.execute(httpPost)) {
            return EntityUtils.toString(response.getEntity(), StandardCharsets.UTF_8);
        }
    }

    /**
     * 上传文件到 COS
     */
    private int uploadFile(String filePath, String endpoint, JsonObject params, String fileName) throws IOException {
        CloseableHttpClient httpClient = createHttpClientWithResolver();
        HttpPost httpPost = new HttpPost(endpoint);

        RequestConfig requestConfig = RequestConfig.custom()
                .setConnectTimeout(60000)
                .setSocketTimeout(60000)
                .build();
        httpPost.setConfig(requestConfig);

        MultipartEntityBuilder builder = MultipartEntityBuilder.create();

        // 添加 COS 参数
        for (String key : params.keySet()) {
            JsonElement element = params.get(key);
            if (element.isJsonPrimitive()) {
                builder.addTextBody(key, element.getAsString(), ContentType.TEXT_PLAIN);
            }
        }

        // 添加文件元数据
        builder.addTextBody("x-cos-meta-file-name", fileName, ContentType.TEXT_PLAIN);

        // 添加文件
        builder.addBinaryBody("file", new File(filePath));

        httpPost.setEntity(builder.build());

        try (CloseableHttpResponse response = httpClient.execute(httpPost)) {
            int statusCode = response.getStatusLine().getStatusCode();
            if (statusCode != 204) {
                String responseBody = EntityUtils.toString(response.getEntity(), StandardCharsets.UTF_8);
                log("Upload response: " + responseBody);
            }
            return statusCode;
        }
    }

    /**
     * 检查连接性
     * 首先尝试直接连接，如果失败则通过 DNS 服务查询 IP 地址
     */
    private void checkConnectivity() {
        for (String serviceHost : serviceHosts) {            
            // step 1: 尝试直接连接
            try {
                String url = "https://" + serviceHost + "/apiv2";
                CloseableHttpClient httpClient = HttpClients.createDefault();
                HttpPost httpPost = new HttpPost(url);
                
                RequestConfig requestConfig = RequestConfig.custom()
                        .setConnectTimeout(5000)
                        .setSocketTimeout(5000)
                        .build();
                httpPost.setConfig(requestConfig);
                
                try (CloseableHttpResponse response = httpClient.execute(httpPost)) {
                    String responseBody = EntityUtils.toString(response.getEntity(), StandardCharsets.UTF_8);
                    log(responseBody);
                    JsonObject jsonResponse = gson.fromJson(responseBody, JsonObject.class);
                    if (jsonResponse != null && jsonResponse.has("code") && jsonResponse.get("code").getAsInt() == 1001) {
                        this.host = serviceHost;
                        this.hostname = serviceHost;
                        return;
                    }
                }
            } catch (Exception e) {
                log("Direct connection to " + serviceHost + " failed, trying DNS service...");
            }

            // step 2: 通过 DNS 服务查询 IP 地址
            try {
                String dnsUrl = dnsService + "?name=" + serviceHost + "&type=A";
                CloseableHttpClient httpClient = HttpClients.createDefault();
                HttpPost httpPost = new HttpPost(dnsUrl);
                
                RequestConfig requestConfig = RequestConfig.custom()
                        .setConnectTimeout(5000)
                        .setSocketTimeout(5000)
                        .build();
                httpPost.setConfig(requestConfig);
                
                try (CloseableHttpResponse response = httpClient.execute(httpPost)) {
                    String responseBody = EntityUtils.toString(response.getEntity(), StandardCharsets.UTF_8);
                    JsonObject dnsResponse = gson.fromJson(responseBody, JsonObject.class);
                    
                    if (dnsResponse != null && dnsResponse.has("Answer")) {
                        com.google.gson.JsonArray answerArray = dnsResponse.getAsJsonArray("Answer");
                        for (JsonElement element : answerArray) {
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

    /**
     * 获取文件扩展名
     */
    private String getFileExtension(String filePath) {
        int lastDot = filePath.lastIndexOf('.');
        if (lastDot > 0) {
            return filePath.substring(lastDot + 1).toLowerCase();
        }
        return "";
    }

    /**
     * 检查文件扩展名是否有效
     */
    private boolean isValidExtension(String ext) {
        return ext.equals("ipa") || ext.equals("apk") || ext.equals("hap");
    }

    /**
     * 根据文件扩展名获取 buildType
     */
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

    /**
     * 记录日志
     */
    private void log(String message) {
        if (!logEnabled) {
            return;
        }
        System.out.println("[" + java.time.LocalDateTime.now() + "] " + message);
    }
}
