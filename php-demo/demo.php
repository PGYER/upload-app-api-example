<?php
/**
* 此 Demo 用演示如何使用 PGYER API 上传 App
* 详细文档参照 https://www.pgyer.com/doc/view/api#fastUploadApp
* 适用于 php 项目
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
*  $uploader->upload(['buildType' => 'ios', 'filePath' => './app.ipa']);

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

require_once 'PGYERAppUploader.php';

try {
    $uploader = new PGYERAppUploader('<your api key>');
    $uploader->log = true;
    $info = $uploader->upload([
        'filePath' => '<your app file path>',
        'buildInstallType' => 2,
        'buildPassword' => '123456',
        'buildUpdateDescription' => 'update by api',
    ]);

    print_r($info);
} catch (Exception $e) {
    echo $e->getMessage();
}