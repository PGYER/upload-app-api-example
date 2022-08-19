// 此 Demo 用演示如何使用 PGYER API 上传 App
// 详细文档参照 https://www.pgyer.com/doc/view/api#fastUploadApp
// 适用于 nodejs 项目
// 本代码需要 npm 包 form-data 支持 运行 npm install --save form-data 即可

const https = require('https');
const fs = require('fs');
const querystring = require('querystring');
const FormData = require('form-data');

const API_KEY_PRODUCTION = '<your api key>';
const APP_PATH = '<your app path>';

function upload (apiKey, appPath, callback) {
  function getUploadResult (uploadData) {
    const uploadResultRequest = https.request({
      hostname: 'www.pgyer.com',
      path: '/apiv2/app/buildInfo?_api_key=' + apiKey + '&buildKey=' + uploadData.data.key,
      method: 'POST',
      headers: {
        'Content-Type' : 'application/x-www-form-urlencoded',
        'Content-Length' : 0
      }
    }, response => {
      if (response.statusCode !== 200) {
        throw new Error('PGYER Service is down.');
      }
    
      let responseData = '';
      response.on('data', data => {
        responseData += data.toString();
      })
    
      response.on('end', () => {
        const responseText = responseData.toString();
        try {
          const responseInfo = JSON.parse(responseText);
          if (responseInfo.code === 1247) {
            console.log('Parsing App Data ... Please Wait ... \n');
            setTimeout(() => getUploadResult(uploadData), 1000);
          } else if (responseInfo.code) {
            throw new Error('PGYER Service Error > ' + responseInfo.code + ': ' + responseInfo.message);
          }
          callback(responseInfo);
        } catch (error) {
          throw error;
        }
      })
    
    })
  
    uploadResultRequest.write(uploadTokenRequestData);
    uploadResultRequest.end();
  }

  function uploadApp(uploadData) {
    const uploadAppRequestData = new FormData()
    uploadAppRequestData.append('signature', uploadData.data.params.signature);
    uploadAppRequestData.append('x-cos-security-token', uploadData.data.params['x-cos-security-token']);
    uploadAppRequestData.append('key', uploadData.data.params.key);
    uploadAppRequestData.append('file', fs.createReadStream(appPath))
    
    uploadAppRequestData.submit(uploadData.data.endpoint, function (error, response) {
      if (response.statusCode === 204) {
        setTimeout(() => getUploadResult(uploadData), 1000);
      } else {
        throw new Error('Upload Error!')
      }
    });
  }

  const uploadTokenRequestData = querystring.stringify({
    _api_key: apiKey,  // 填写您在平台注册的 API Key （具体参照文档）
    buildType: 'ios',  // 填写应用类型，可选值为: ios、android （具体参照文档）
    buildInstallType: 2,  // 填写安装类型，可选值为: 1 公开， 2密码 （具体参照文档）
    buildPassword: '123456',  // 填写密码安装时的密码 （具体参照文档）
  });
  
  const uploadTokenRequest = https.request({
    hostname: 'www.pgyer.com',
    path: '/apiv2/app/getCOSToken',
    method: 'POST',
    headers: {
      'Content-Type' : 'application/x-www-form-urlencoded',
      'Content-Length' : uploadTokenRequestData.length
    }
  }, response => {
    if (response.statusCode !== 200) {
      throw new Error('PGYER Service is down.');
    }
  
    let responseData = '';
    response.on('data', data => {
      responseData += data.toString();
    })
  
    response.on('end', () => {
      const responseText = responseData.toString();
      try {
        const responseInfo = JSON.parse(responseText);
        if (responseInfo.code) {
          throw new Error('PGYER Service Error > ' + responseInfo.code + ': ' + responseInfo.message);
        }
        uploadApp(responseInfo);
      } catch (error) {
        throw error;
      }
    })
  
  })

  uploadTokenRequest.write(uploadTokenRequestData);
  uploadTokenRequest.end();
}

// 调用说明:
// upload(apikey, appPath, successCallback): void
// apikey: 你的 API Key
// appPath: 你的 app 路径，绝对路径相对路径均可
// successCallback: 成功后的回调函数, 传入一个参数为 App 信息 类似如下对象描述
// {
//   code: 0,
//   message: '',
//   data: {
//     buildKey: 'xxx',
//     buildType: '1',
//     buildIsFirst: '0',
//     buildIsLastest: '1',
//     buildFileKey: 'xxx.ipa',
//     buildFileName: '',
//     buildFileSize: '40095060',
//     buildName: 'xxx',
//     buildVersion: '2.2.0',
//     buildVersionNo: '1.0.1',
//     buildBuildVersion: '9',
//     buildIdentifier: 'xxx.xxx.xxx.xxx',
//     buildIcon: 'xxx',
//     buildDescription: '',
//     buildUpdateDescription: '',
//     buildScreenshots: '',
//     buildShortcutUrl: 'xxxx',
//     buildCreated: 'xxxx-xx-xx xx:xx:xx',
//     buildUpdated: 'xxxx-xx-xx xx:xx:xx',
//     buildQRCodeURL: 'https://www.pgyer.com/app/qrcodeHistory/xxxx'
//   }
// }

upload(API_KEY_PRODUCTION, APP_PATH, console.log);