<?php
/**
 * 通过API上传App到蒲公英的示例代码
 *
 * 更多信息请见： https://www.pgyer.com/doc/view/api#fastUploadApp
 */

const API_KEY_DEV = "";
const API_KEY_PRODUCTION = "";
const APP_PATH = "";

// 获取上传凭证和上传地址
$res = sendRequest("http://www.pgyer.com/apiv2/app/getCOSToken", [
    "_api_key" => API_KEY_PRODUCTION,  // 填写您在平台注册的 API Key
    "buildType" => 'ios',  // 填写应用类型，可选值为: ios、android
    "buildInstallType" => 2,  // 填写安装类型，可选值为: 1 公开， 2密码
    "buildPassword" => '123456',  // 填写密码
]);
$res = json_decode($res, true);
// _log($res);

if ($res['code'] != 0 || empty($res['data'])) {
    exit($res['message']);
}
$key = $res['data']['key'];

// 开始上传
$params = $res['data']['params'];
$params['file'] = new CURLFile(APP_PATH);  // 填写待上传文件的路径
$httpcode = 0;

$result = sendRequest($res['data']['endpoint'], $params, $httpcode);
if ($httpcode == 204) {
    _log("upload success");
} else {
    _log("upload failed");
    _log($result);
    exit;
}

// 获取版本信息
getBuildInfo("http://www.pgyer.com/apiv2/app/buildInfo?_api_key=" . API_KEY_PRODUCTION . "&buildKey=$key");

// functions
function sendRequest($url, $params = [], &$httpcode = 0)
{
    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);

    if (!empty($params)) {
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $params);
    }

    $result = curl_exec($ch);
    $httpcode = curl_getinfo($ch, CURLINFO_HTTP_CODE);

    curl_close($ch);
    return $result;
}

function getBuildInfo($url)
{
    _log($url);
    for ($i = 0; $i < 60; $i++) {
        $res = json_decode(sendRequest($url), true);
        if ($res['code'] == 0) {
            _log($res['data']);
            break;
        } else {
            _log("[$i] get app build info...");
            sleep(1);
        }
    }
}

function _log($message) {
    if (is_array($message) || is_object($message)) {
        $message = var_export($message, true);
    }
    echo date("Y-m-d H:i:s") . " " . $message . "\n";
}
