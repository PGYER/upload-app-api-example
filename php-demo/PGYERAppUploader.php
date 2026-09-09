<?php
/**
* 此 Demo 用演示如何使用 PGYER API 上传 App
* 详细文档参照 https://www.pgyer.com/doc/view/api#fastUploadApp
* 适用于 php 项目
* 支持上传 iOS (.ipa)、Android (.apk) 和 HarmonyOS (.hap) 应用
*/

/*
* 以下代码为示例代码，可以在生产环境中使用。使用方法如下:
* 
* 先实例化上传器
* 
* $uploader = new PGYERAppUploader(<your api key>);
* 
* 在上传器实例化以后, 通过调用 upload 方法即可完成 App 上传。
* 
*  $uploader->upload($config);
* 
*  示例: 
*  $uploader = new PGYERAppUploader('apikey');
*  $uploader->upload(['filePath' => './app.ipa']);  // iOS应用
*  $uploader->upload(['filePath' => './app.apk']);  // Android应用
*  $uploader->upload(['filePath' => './app.hap']);  // HarmonyOS应用

* 
* uploadOptions 参数说明: (https://www.pgyer.com/doc/view/api#fastUploadApp)
* 
* 对象成员名                是否必选    含义
* filePath                Y          App 文件的路径，可以是相对路径
* buildInstallType        N          应用安装方式，值为(1,2,3，默认为1 公开安装)。1：公开安装，2：密码安装，3：邀请安装
* buildPassword           N          设置App安装密码，密码为空时默认公开安装
* buildUpdateDescription  N          版本更新描述，请传空字符串，或不传。
* buildInstallDate        N          是否设置安装有效期，值为：1 设置有效时间， 2 长期有效，如果不填写不修改上一次的设置
* buildInstallStartDate   N          安装有效期开始时间，字符串型，如：2018-01-01
* buildInstallEndDate     N          安装有效期结束时间，字符串型，如：2018-12-31
* buildChannelShortcut    N          所需更新的指定渠道的下载短链接，只可指定一个渠道，字符串型，如：abcd
* 
* 
* 返回结果
* 
* 返回结果是一个数组, 主要返回 API 调用的结果, 示例如下:
* 
* {
*   code: 0,
*   message: '',
*   data: {
*     buildKey: 'xxx',
*     buildType: '1',
*     buildIsFirst: '0',
*     buildIsLastest: '1',
*     buildFileKey: 'xxx.ipa',
*     buildFileName: '',
*     buildFileSize: '40095060',
*     buildName: 'xxx',
*     buildVersion: '2.2.0',
*     buildVersionNo: '1.0.1',
*     buildBuildVersion: '9',
*     buildIdentifier: 'xxx.xxx.xxx',
*     buildIcon: 'xxx',
*     buildDescription: '',
*     buildUpdateDescription: '',
*     buildScreenshots: '',
*     buildShortcutUrl: 'xxxx',
*     buildCreated: 'xxxx-xx-xx xx:xx:xx',
*     buildUpdated: 'xxxx-xx-xx xx:xx:xx',
*     buildQRCodeURL: 'https://www.pgyer.com/app/qrcodeHistory/xxxx'
*   }
* }
* 
*/

class PGYERAppUploader
{

    private $apikey = '';
    public $log = false;
    private $connectTimeout = 30;
    private $requestTimeout = 120;
    private $uploadTimeout = 0;
    private $uploadMaxRetries = 3;
    private $dnsService = 'https://dns.alidns.com/resolve';
    private $serviceHosts = [
        'api.pgyer.com',
        'api.xcxwo.com',
        'api.pgyerapp.com'
    ];

    private $host = NULL;
    private $hostname = NULL;

    public function __construct($apikey)
    {
        $this->apikey = $apikey;
        $this->checkConnectivity();
    }

    public function upload($config)
    {
        if (empty($config['filePath'])) {
            throw new Exception('filePath is required');
        }

        $filePath = $config['filePath'];
        if (!is_file($filePath)) {
            throw new Exception('App file does not exist: ' . $filePath);
        }

        if (!is_readable($filePath)) {
            throw new Exception('App file is not readable: ' . $filePath);
        }

        // step 1: get app upload token
        $ext = strtolower(pathinfo($filePath, PATHINFO_EXTENSION));
        if (!in_array($ext, ['ipa', 'apk', 'hap'])) {
            throw new Exception('Invalid file type. Supported types: ipa, apk, hap');
        }

        // 根据文件扩展名确定buildType
        $buildType = '';
        switch (strtolower($ext)) {
            case 'ipa':
                $buildType = 'ios';
                break;
            case 'apk':
                $buildType = 'android';
                break;
            case 'hap':
                $buildType = 'harmony';
                break;
            default:
                throw new Exception('Unsupported file type: ' . $ext);
        }

        $this->log("Start upload, using service: {$this->hostname} ({$this->host}) ...");

        $params = [
            "_api_key" => $this->apikey,
            "buildType" => $buildType
        ];

        $otherParams = ["buildInstallType", "buildPassword", "buildUpdateDescription", "buildInstallDate", "buildInstallStartDate", "buildInstallEndDate", "buildChannelShortcut"];
        foreach ($otherParams as $key) {
            if (isset($config[$key])) {
                $params[$key] = $config[$key];
            }
        }

        $this->log("get upload token with params: " . json_encode($this->redactSensitiveData($params), JSON_UNESCAPED_UNICODE));

        $res = $this->sendRequest("/apiv2/app/getCOSToken", $params);
        $res = json_decode($res, true);
        if (!is_array($res)) {
            throw new Exception('Failed to parse upload token response: ' . json_last_error_msg());
        }
        $this->log(json_encode($this->redactSensitiveData($res), JSON_UNESCAPED_UNICODE));

        if (($res['code'] ?? -1) != 0 || empty($res['data'])) {
            throw new Exception('Failed to get upload token: ' . ($res['message'] ?? 'unknown error'));
        }
        if (empty($res['data']['key']) || empty($res['data']['endpoint']) || empty($res['data']['params'])) {
            throw new Exception('Invalid upload token response: missing key, endpoint or params');
        }

        $buildKey = $res['data']['key'];

        // step 2: upload app to bucket
        $params = $res['data']['params'];
        $params['x-cos-meta-file-name'] = pathinfo($filePath, PATHINFO_BASENAME);
        $params['file'] = new CURLFile($filePath);
        $this->log("upload app to bucket with params: " . json_encode($this->redactSensitiveData($params), JSON_UNESCAPED_UNICODE));
        $this->uploadToBucket($res['data']['endpoint'], $params);

        // step 3: get uploaded app data
        $url = "/apiv2/app/buildInfo?" . http_build_query([
            '_api_key' => $this->apikey,
            'buildKey' => $buildKey
        ]);
        $this->log("get build info from: /apiv2/app/buildInfo?" . http_build_query([
            '_api_key' => '***',
            'buildKey' => '***'
        ]));
        for ($i = 0; $i < 60; $i++) {
            $resp = $this->sendRequest($url);
            $res = json_decode($resp, true);
            if (!is_array($res)) {
                throw new Exception('Failed to parse build info response: ' . json_last_error_msg());
            }

            if (($res['code'] ?? -1) != 0) {
                sleep(1);
                $this->log("[$i] get app build info...");
                continue;
            }

            $this->log($resp);
            return $res['data'];
        }

        return false;
    }

    public function sendRequest($url, $params = [], &$httpcode = 0, $timeout = null)
    {
        $ch = curl_init();
        if (strpos($url, '/') === 0) {
            curl_setopt($ch, CURLOPT_URL, "https://{$this->hostname}{$url}");
            if ($this->host && filter_var($this->host, FILTER_VALIDATE_IP)) {
                curl_setopt($ch, CURLOPT_RESOLVE, [
                    "{$this->hostname}:443:{$this->host}",
                    "{$this->hostname}:80:{$this->host}",
                ]);
            }
        } else {
            curl_setopt($ch, CURLOPT_URL, $url);
        }

        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, $this->connectTimeout);
        curl_setopt($ch, CURLOPT_TIMEOUT, $timeout === null ? $this->requestTimeout : $timeout);

        if (!empty($params)) {
            curl_setopt($ch, CURLOPT_POST, true);
            curl_setopt($ch, CURLOPT_POSTFIELDS, $params);
        }

        $result = curl_exec($ch);
        $httpcode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $errno = curl_errno($ch);
        $error = curl_error($ch);

        @curl_close($ch);

        if ($result === false) {
            throw new Exception("Request failed: curl errno {$errno}, HTTP status {$httpcode}, error: {$error}");
        }

        return $result;
    }

    private function uploadToBucket($endpoint, $params)
    {
        $lastError = null;

        for ($attempt = 1; $attempt <= $this->uploadMaxRetries; $attempt++) {
            $httpcode = 0;
            try {
                $result = $this->sendRequest($endpoint, $params, $httpcode, $this->uploadTimeout);
                if ($httpcode == 204) {
                    $this->log("upload success");
                    return;
                }

                $lastError = "HTTP status {$httpcode}, response: {$result}";
            } catch (Exception $e) {
                $lastError = $e->getMessage();
                $httpcode = $this->extractHttpStatus($lastError);
            }

            $this->log("upload attempt {$attempt} failed: {$lastError}");
            if ($attempt >= $this->uploadMaxRetries || !$this->shouldRetryUpload($httpcode, $lastError)) {
                break;
            }

            sleep($attempt);
        }

        throw new Exception('Failed to upload app: ' . ($lastError ?: 'unknown error'));
    }

    private function shouldRetryUpload($httpcode, $errorMessage)
    {
        if (in_array((int) $httpcode, [408, 429, 500, 502, 503, 504], true)) {
            return true;
        }

        foreach ([28, 35, 52, 56] as $errno) {
            if (strpos($errorMessage, "curl errno {$errno}") !== false) {
                return true;
            }
        }

        return false;
    }

    private function extractHttpStatus($message)
    {
        if (preg_match('/HTTP status (\d+)/', $message, $matches)) {
            return (int) $matches[1];
        }

        return 0;
    }

    private function redactSensitiveData($data)
    {
        if (!is_array($data)) {
            return $data;
        }

        $sensitiveKeys = [
            '_api_key',
            'buildPassword',
            'key',
            'signature',
            'x-cos-security-token',
            'buildKey',
        ];

        $redacted = [];
        foreach ($data as $key => $value) {
            if (in_array($key, $sensitiveKeys, true)) {
                $redacted[$key] = '***';
            } elseif ($value instanceof CURLFile) {
                $redacted[$key] = '@' . $value->getFilename();
            } elseif (is_array($value)) {
                $redacted[$key] = $this->redactSensitiveData($value);
            } else {
                $redacted[$key] = $value;
            }
        }

        return $redacted;
    }

    public function log($message)
    {
        if (!$this->log) {
            return;
        }

        if (is_array($message) || is_object($message)) {
            $message = var_export($message, true);
        }

        echo date("Y-m-d H:i:s") . " " . $message . "\n";
    }

    private function checkConnectivity ()
    {
        $context = stream_context_create([
            'http' => [
                'timeout' => 5
            ]
        ]);
        foreach ($this->serviceHosts as $host) {
            $data = @json_decode(file_get_contents("https://{$host}/apiv2", false, $context), TRUE);
            if ($data && $data['code'] === 1001) {
                $this->host = $host;
                $this->hostname = $host;
                return;
            }

            $data = @json_decode(file_get_contents("{$this->dnsService}?name={$host}&type=A", false, $context), TRUE);
            $data = array_values(array_filter($data['Answer'] ?? [], function ($item) use ($host) {
                return $item['type'] === 1;
            }));

            if ($data && count($data) > 0) {
                $this->host = $data[0]['data'];
                $this->hostname = $host;
                return;
            }
        }

        throw new Exception('Cannot connect to PGYER API service.');
    }
}
