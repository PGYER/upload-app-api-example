

/*
* 以下代码为示例代码，可以在生产环境中使用。使用方法如下:
* 
* 先实例化上传器
* 
* PGYERAppUploader uploader = new PGYERAppUploader("<your api key>");
* 
* 在上传器实例化以后, 通过调用 Upload 方法即可完成 App 上传。
* 
*  
* 
*  示例: 
*  PGYERAppUploader uploader = new PGYERAppUploader("<your api key>");
*  uploader.Upload(option);

* 
* UploadOption 参数说明: (https://www.pgyer.com/doc/view/api#fastUploadApp)
* 
* 对象成员名                是否必选    含义
* FilePath                Y          App 文件的路径，可以是相对路径
* Oversea                 Y          是否使用海外加速上传，值为：1 使用海外加速上传，2 国内加速上传；留空根据 IP 自动判断海外加速或国内加速
* BuildInstallType        N          应用安装方式，值为(1,2,3，默认为1 公开安装)。1：公开安装，2：密码安装，3：邀请安装
* BuildPassword           N          设置App安装密码，密码为空时默认公开安装
* buildDescription        N          应用介绍，如没有介绍请传空字符串，或不传。
* BuildUpdateDescription  N          版本更新描述，请传空字符串，或不传。
* BuildInstallDate        N          是否设置安装有效期，值为：1 设置有效时间， 2 长期有效，如果不填写不修改上一次的设置
* BuildInstallStartDate   N          安装有效期开始时间，字符串型，如：2018-01-01
* BuildInstallEndDate     N          安装有效期结束时间，字符串型，如：2018-12-31
* BuildChannelShortcut    N          所需更新的指定渠道的下载短链接，只可指定一个渠道，字符串型，如：abcd
* 
* 
* 返回结果
* 
* 返回 Response<BuildInfoResponse> 对象, 主要返回 API 调用的结果, 示例如下:
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


using System.Text.Json;


/**
* 此 Demo 用演示如何使用 PGYER API 上传 App
* 详细文档参照 https://www.pgyer.com/doc/view/api#fastUploadApp
* 适用于 c# 项目
*/
class Demo
{

    public static void Main(string[] args)
    {
        PGYERAppUploader uploader = new PGYERAppUploader("your api key");
        // enable debug info
        uploader.WithDebug();
        UploadOption option = new UploadOption
        {
            FilePath = "./your-app.apk",
        };
        Response<BuildInfoResponse> response = uploader.Upload(option);
        if (response != null)
        {
            Console.WriteLine(JsonSerializer.Serialize(response));
        }
    }
}