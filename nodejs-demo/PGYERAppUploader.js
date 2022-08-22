/*
 * 此 Demo 用演示如何使用 PGYER API 上传 App
 * 详细文档参照 https://www.pgyer.com/doc/view/api#fastUploadApp
 * 适用于 nodejs 项目
 * 本代码需要 npm 包 form-data 支持 运行 npm install --save form-data 即可
 */

/*
 * 以下代码为示例代码，可以在生产环境中使用。使用方法如下:
 * 
 * 先实例化上传器
 * 
 * const uploader = new PGYERAppUploader(<your api key>);
 * 
 * 在上传器实例化以后, 通过调用 upload 方法即可完成 App 上传。
 * 
 * upload 方法有两种调用方式
 * 
 * 1. 回调方式调用
 * 
 *  uploader.upload(uploadOptions: Object, callbackFn(error: Error, result: Object): any): void
 * 
 *  示例: 
 *  const uploader = new PGYERAppUploader('apikey');
 *  uploader.upload({ buildType: 'ios', filePath: './app.ipa' }, function (error, data) {
 *    // code here
 *  })
 * 
 * 2. 使用 promise 方式调用
 * 
 * uploader.upload(uploadOptions: Object): Promise
 * 
 * 示例: 
 * const uploader = new PGYERAppUploader('apikey');
 * uploader.upload({ buildType: 'ios', filePath: './app.ipa' }).then(function (data) {
 *   // code here
 * }).catch(fucntion (error) {
 *   // code here
 * })
 * 
 * uploadOptions 参数说明: (https://www.pgyer.com/doc/view/api#fastUploadApp)
 * 
 * 对象成员名                是否必选    含义
 * buildType               Y          需要上传的应用类型，ios 或 android
 * filePath                Y          App 文件的路径，可以是相对路径
 * log                     N          Bool 类型，是否打印 log
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
 * 返回结果是一个对象, 主要返回 API 调用的结果, 示例如下:
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

const https = require('https');
const fs = require('fs');
const querystring = require('querystring');
const FormData = require('form-data');

module.exports = function (apiKey) {
  const LOG_TAG = '[PGYER APP UPLOADER]';
  let uploadOptions = '';
  this.upload = function (options, callback) {
    if (
      options &&
      ['ios', 'android'].includes(options.buildType) &&
      typeof options.filePath === 'string'
    ) {
      uploadOptions = options;
      if (typeof callback === 'function') {
        uploadApp(callback);
        return null;
      } else {
        return new Promise(function(resolve, reject) {
          uploadApp(function (error, data) {
            if (error === null) {
              return resolve(data);
            }
            return reject(error);
          });
        });
      }
    }

    throw new Error('filePath must be a string');
  }

  function uploadApp (callback) {
    // step 1: get app upload token
    const uploadTokenRequestData = querystring.stringify({ ...uploadOptions, _api_key: apiKey });
    
    uploadOptions.log && console.log(LOG_TAG + ' Check API Key ... Please Wait ...');
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
        callback(new Error(LOG_TAG + 'Service down: cannot get upload token.'), null);
        return;
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
            callback(new Error(LOG_TAG + 'Service down: ' + responseInfo.code + ': ' + responseInfo.message), null);
            return;
          }
          uploadApp(responseInfo);
        } catch (error) {
          callback(error, null);
        }
      })
    })

    uploadTokenRequest.write(uploadTokenRequestData);
    uploadTokenRequest.end();


    // step 2: upload app to bucket
    function uploadApp(uploadData) {
      uploadOptions.log && console.log(LOG_TAG + ' Uploading app ... Please Wait ...');
      const exsit = fs.existsSync(uploadOptions.filePath);
      if (!exsit) {
        callback(new Error(LOG_TAG + ' filePath: file not exist'), null);
        return;
      }

      const statResult = fs.statSync(uploadOptions.filePath);
      if (!statResult || !statResult.isFile()) {
        callback(new Error(LOG_TAG + ' filePath: path not a file'), null);
        return;
      }

      const uploadAppRequestData = new FormData();
      uploadAppRequestData.append('signature', uploadData.data.params.signature);
      uploadAppRequestData.append('x-cos-security-token', uploadData.data.params['x-cos-security-token']);
      uploadAppRequestData.append('key', uploadData.data.params.key);
      uploadAppRequestData.append('file', fs.createReadStream(uploadOptions.filePath));

      uploadAppRequestData.submit(uploadData.data.endpoint, function (error, response) {
        if (error) {
          callback(error, null);
          return;
        }
        if (response.statusCode === 204) {
          setTimeout(() => getUploadResult(uploadData), 1000);
        } else {
          callback(new Error(LOG_TAG + ' Upload Error!'), null);
        }
      });
    }

    // step 3: get uploaded app data
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
          callback(new Error(LOG_TAG + ' Service is down.'), null);
          return;
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
              uploadOptions.log && console.log(LOG_TAG + ' Parsing App Data ... Please Wait ...');
              setTimeout(() => getUploadResult(uploadData), 1000);
              return;
            } else if (responseInfo.code) {
              callback(new Error(LOG_TAG + 'Service down: ' + responseInfo.code + ': ' + responseInfo.message), null);
            }
            callback(null, responseInfo);
          } catch (error) {
            callback(error, null);
          }
        })
      
      })
    
      uploadResultRequest.write(uploadTokenRequestData);
      uploadResultRequest.end();
    }
  }
}
