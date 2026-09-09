const http = require('http');
const https = require('https');
const base = new URL(process.argv[2]);
https.request = (options, callback) => {
  const path = typeof options === 'string' ? new URL(options).pathname + new URL(options).search : options.path;
  return http.request({hostname:base.hostname, port:base.port, path,
    method:options.method || 'GET', headers:options.headers}, callback);
};
https.get = (options, callback) => {const req=https.request(options,callback);req.end();return req;};
const Uploader=require('../nodejs-demo/PGYERAppUploader');
new Uploader('fixture').upload({filePath:process.argv[3],log:false}).then(() => process.exit(0)).catch(error => {
  console.error(error.message);process.exit(1);
});
