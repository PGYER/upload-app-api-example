/*
 * 此 Demo 用演示如何使用 PGYER API 上传 App
 * 详细文档参照 https://www.pgyer.com/doc/view/api#fastUploadApp
 * 适用于 nodejs 项目
 * 本代码需要 npm 包 form-data 支持 运行 npm install --save form-data 即可
 * 支持上传 iOS (.ipa)、Android (.apk) 和 HarmonyOS (.hap) 应用
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
 *  uploader.upload({ filePath: './app.ipa' }, function (error, data) {  // iOS应用
 *    // code here
 *  })
 *  uploader.upload({ filePath: './app.apk' }, function (error, data) {  // Android应用
 *    // code here
 *  })
 *  uploader.upload({ filePath: './app.hap' }, function (error, data) {  // HarmonyOS应用
 *    // code here
 *  })
 *
 * 2. 使用 promise 方式调用
 *
 * uploader.upload(uploadOptions: Object): Promise
 *
 * 示例: 
 * const uploader = new PGYERAppUploader('apikey');
 * uploader.upload({ filePath: './app.ipa' }).then(function (data) {  // iOS应用
 *   // code here
 * }).catch(fucntion (error) {
 *   // code here
 * })
 * uploader.upload({ filePath: './app.apk' }).then(function (data) {  // Android应用
 *   // code here
 * }).catch(fucntion (error) {
 *   // code here
 * })
 * uploader.upload({ filePath: './app.hap' }).then(function (data) {  // HarmonyOS应用
 *   // code here
 * }).catch(fucntion (error) {
 *   // code here
 * })
 * 
 * uploadOptions 参数说明: (https://www.pgyer.com/doc/view/api#fastUploadApp)
 * 
 * 对象成员名                是否必选    含义
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
const path = require('path');
const querystring = require('querystring');
const FormData = require('form-data');

module.exports = function (apiKey) {
  const LOG_TAG = '[PGYER APP UPLOADER]';
  const MAIN_SERVICES = ['api.pgyer.com', 'api.xcxwo.com', 'api.pgyerapp.com'];
  const DNS_SERVICE = 'https://dns.alidns.com/resolve';
  const service = {};

  function checkServiceConnectivity(hostname, host = false) {
    if (!host) {
      host = hostname;
    }

    return new Promise(function (resolve, reject) {
      const req = https.request({
        hostname: host,
        servername: hostname,
        path: '/apiv2',
        method: 'GET',
        agent: false,
        headers: {
          'HOST': hostname
        }
      }, response => {
        response.resume();
        if (response.statusCode === 200) {
          resolve({ host: host, hostname: hostname });
        } else {
          reject(false);
        }
      });

      req.on('error', function () {
        req.destroy();
        reject(false);
      });

      req.setTimeout(3000, function () {
        req.destroy();
        reject(false);
      });

      req.end();
    });
  }

  function checkServiceConnectivityDNS(host) {
    return new Promise(function (resolve, reject) {
      const req = https.request(DNS_SERVICE + '?name=' + host + '&type=A', {
        method: 'GET',
        agent: false,
        headers: {
          'HOST': 'dns.alidns.com'
        }
      }, response => {
        if (response.statusCode !== 200) {
          reject(false);
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
            if (responseInfo.Status === 0 && responseInfo.Answer && responseInfo.Answer.length > 0) {
              for (let i = 0; i < responseInfo.Answer.length; i++) {
                if (responseInfo.Answer[i].type === 1) {
                  checkServiceConnectivity(host, responseInfo.Answer[i].data).then(resolve).catch(reject);
                  return;
                }
              }
            }
            reject(false);
          } catch (error) {
            reject(false);
          }
        })
      });

      req.on('error', function () {
        req.destroy();
        reject(false);
      });

      req.setTimeout(3000, function () {
        req.destroy();
        reject(false);
      });

      req.end();
    });
  }

  function checkServiceHost() {
    const checks = [
      ...MAIN_SERVICES.map(checkServiceConnectivity),
      ...MAIN_SERVICES.map(checkServiceConnectivityDNS),
    ];

    return new Promise(function (resolve, reject) {
      let finished = false;
      let pending = checks.length;
      const timer = setTimeout(function () {
        if (finished) {
          return;
        }
        finished = true;
        reject(new Error(LOG_TAG + ' All services are down.'));
      }, 5000);

      checks.forEach(function (check) {
        check.then(function (result) {
          if (finished) {
            return;
          }
          finished = true;
          clearTimeout(timer);
          service.host = result.host;
          service.hostname = result.hostname;
          resolve(result);
        }).catch(function () {
          pending -= 1;
          if (!finished && pending === 0) {
            finished = true;
            clearTimeout(timer);
            reject(new Error(LOG_TAG + ' All services are down.'));
          }
        });
      });
    });
  }

  this.upload = function (options, callback) {
    if (options && typeof options.filePath === 'string') {
      if (typeof callback === 'function') {
        checkServiceHost()
          .then(function () { uploadApp(options, callback); })
          .catch(function (error) { callback(error, null); });
        return null;
      }

      return new Promise(function(resolve, reject) {
        checkServiceHost()
          .then(function () {
            uploadApp(options, function (error, data) {
              if (error) {
                reject(error);
                return;
              }
              resolve(data);
            });
          })
          .catch(function (error) {
            reject(error);
          });
      });
    }

    throw new Error('filePath must be a string');
  }

  function uploadApp (uploadOptions, callback) {
    let finished = false;

    function done(error, data) {
      if (finished) {
        return;
      }
      finished = true;
      callback(error, data);
    }

    uploadOptions.log && console.log(LOG_TAG + 'Start upload, using service: ' + service.hostname + ' (' + service.host + ') ...');
    // step 1: get app upload token
    const fileExt = uploadOptions.filePath.split('.').pop().toLowerCase();
    let buildType;
    
    // 根据文件扩展名确定buildType
    switch (fileExt) {
      case 'ipa':
        buildType = 'ios';
        break;
      case 'apk':
        buildType = 'android';
        break;
      case 'hap':
        buildType = 'harmony';
        break;
      default:
        done(new Error(LOG_TAG + ' Unsupported file type: ' + fileExt + '. Supported types: ipa, apk, hap'), null);
        return;
    }
    
    const tokenParams = {
      _api_key: apiKey,
      buildType: buildType
    };

    [
      'buildInstallType',
      'buildPassword',
      'buildUpdateDescription',
      'buildInstallDate',
      'buildInstallStartDate',
      'buildInstallEndDate',
      'buildChannelShortcut'
    ].forEach(function (key) {
      if (uploadOptions[key] !== undefined && uploadOptions[key] !== null && uploadOptions[key] !== '') {
        tokenParams[key] = uploadOptions[key];
      }
    });

    const uploadTokenRequestData = querystring.stringify(tokenParams);
    
    uploadOptions.log && console.log(LOG_TAG + ' Check API Key ... Please Wait ...');

    const uploadTokenRequest = https.request({
      hostname: service.host,
      servername: service.hostname,
      path: '/apiv2/app/getCOSToken',
      method: 'POST',
      agent: false,
      headers: {
        'HOST': service.hostname,
        'Content-Type' : 'application/x-www-form-urlencoded',
        'Content-Length' : uploadTokenRequestData.length
      }
    }, response => {
      if (response.statusCode !== 200) {
        response.resume();
        done(new Error(LOG_TAG + ' Service down: cannot get upload token. HTTP status: ' + response.statusCode), null);
        return;
      }
    
      let responseData = '';
      response.on('data', data => {
        responseData += data.toString();
      })
    
      response.on('end', () => {
        uploadTokenRequest.destroy();
        const responseText = responseData.toString();
        try {
          const responseInfo = JSON.parse(responseText);
          if (responseInfo.code) {
            done(new Error(LOG_TAG + 'Service down: ' + responseInfo.code + ': ' + responseInfo.message), null);
            return;
          }
          uploadApp(responseInfo);
        } catch (error) {
          done(error, null);
        }
      })
    })

    uploadTokenRequest.on('error', function(error) {
      done(error, null);
    });

    uploadTokenRequest.setTimeout(30000, function () {
      uploadTokenRequest.destroy(new Error(LOG_TAG + ' Get upload token request timed out.'));
    });

    uploadTokenRequest.write(uploadTokenRequestData);
    uploadTokenRequest.end();


    // step 2: upload app to bucket
    function uploadApp(uploadData) {
      uploadOptions.log && console.log(LOG_TAG + ' Uploading app ... Please Wait ...');
      const exsit = fs.existsSync(uploadOptions.filePath);
      if (!exsit) {
        done(new Error(LOG_TAG + ' filePath: file not exist'), null);
        return;
      }

      const statResult = fs.statSync(uploadOptions.filePath);
      if (!statResult || !statResult.isFile()) {
        done(new Error(LOG_TAG + ' filePath: path not a file'), null);
        return;
      }

      const uploadAppRequestData = new FormData();
      uploadAppRequestData.append('signature', uploadData.data.params.signature);
      uploadAppRequestData.append('x-cos-security-token', uploadData.data.params['x-cos-security-token']);
      uploadAppRequestData.append('key', uploadData.data.params.key);
      uploadAppRequestData.append('x-cos-meta-file-name', path.basename(uploadOptions.filePath));
      uploadAppRequestData.append('file', fs.createReadStream(uploadOptions.filePath));

      uploadAppRequestData.submit(uploadData.data.endpoint, function (error, response) {
        if (error) {
          uploadAppRequestData.destroy();
          done(error, null);
          return;
        }

        response.resume();
        if (response.statusCode === 204) {
          setTimeout(() => getUploadResult(uploadData), 1000);
          uploadAppRequestData.destroy();
        } else {
          uploadAppRequestData.destroy();
          done(new Error(LOG_TAG + ' Upload Error! HTTP status: ' + response.statusCode), null);
        }
      });
    }

    // step 3: get uploaded app data
    function getUploadResult (uploadData, retryCount = 0) {
      if (retryCount >= 60) {
        done(new Error(LOG_TAG + ' Build check timed out after 60 seconds.'), null);
        return;
      }

      const uploadResultRequest = https.request({
        hostname: service.host,
        servername: service.hostname,
        path: '/apiv2/app/buildInfo?' + querystring.stringify({
          _api_key: apiKey,
          buildKey: uploadData.data.key
        }),
        method: 'POST',
        agent: false,
        headers: {
          'HOST': service.hostname,
          'Content-Type' : 'application/x-www-form-urlencoded',
          'Content-Length' : 0
        }
      }, response => {
        if (response.statusCode !== 200) {
          response.resume();
          done(new Error(LOG_TAG + ' Service is down.'), null);
          return;
        }
      
        let responseData = '';
        response.on('data', data => {
          responseData += data.toString();
        })
      
        response.on('end', () => {
          uploadResultRequest.destroy();
          const responseText = responseData.toString();
          try {
            const responseInfo = JSON.parse(responseText);
            if (responseInfo.code === 1247) {
              uploadOptions.log && console.log(LOG_TAG + ' Parsing App Data ... Please Wait ...');
              setTimeout(() => getUploadResult(uploadData, retryCount + 1), 1000);
              return;
            } else if (responseInfo.code) {
              done(new Error(LOG_TAG + 'Service down: ' + responseInfo.code + ': ' + responseInfo.message), null);
              return;
            }
            done(null, responseInfo);
          } catch (error) {
            done(error, null);
          }
        })
      })

      uploadResultRequest.on('error', function(error) {
        done(error, null);
      });

      uploadResultRequest.setTimeout(30000, function () {
        uploadResultRequest.destroy(new Error(LOG_TAG + ' Build info request timed out.'));
      });

      uploadResultRequest.end();
    }
  }
}
