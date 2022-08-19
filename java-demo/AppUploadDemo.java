package com.pgyer.app_upload_demo;

import org.json.JSONObject;

import java.io.File;
import java.io.FilterOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.charset.Charset;
import java.util.HashMap;
import java.util.Map;
import java.util.Timer;

/**
 * @describe
 * @author: Caoxy
 * @date: 2022/8/19
 */
public class AppUploadDemo implements AppUploadDemo.ProgressHttpEntityWrapper.ProgressCallback{
    public static final String API_KEY_DEV = "";//测试环境apikey
    public static final String API_KEY_PRODUCTION = "";//线上环境apikey
    public static final String APP_PATH = "";//文件地址
    public static final String  GET_TOKEN_URL = "https://www.pgyer.com/apiv2/app/getCOSToken";
    public static final int FILE_UPLOAD_SUCCESSFUL = 1001;

    private UploadFileToServiceCallback uploadFileToServiceCallback;
    Timer timers = null;

    /**
     * 例子
     */
    public void uploadApk(){
        Map<String, String> params = new HashMap<>();
        params.put("_api_key", API_KEY_DEV);
        int buildInstallType = 1;
        params.put("buildInstallType", buildInstallType+"");//buildInstallType 1,2,3，默认为1 公开安装 1：公开安装，2：密码安装，3：邀请安装
        if (buildInstallType == 2) {
            params.put("buildPassword", "");//需要安装密码
        }
        params.put("buildUpdateDescription", "");//版本更新日志

        File uploadFile = new File(APP_PATH);//apk文件路径
        params.put("buildType", "android");
        String url = GET_TOKEN_URL;//
        getToken(params, url, _api_key, uploadFile, new UploadFileToServiceCallback() {
            @Override
            public void onUploadBack(int code, String msg) {//查看上传是否成功 和 同步是否成功
                if(code == FILE_UPLOAD_SUCCESSFUL){//文件长传成功等待同步

                } else if(code == 1246){//数据正在同步等待两秒后再次请求
                    timers = new Timer(2000, new ActionListener() {
                        @Override
                        public void actionPerformed(ActionEvent e) {
                            if(timers != null){
                                timers.stop();
                                timers = null;
                                uploadResult(msg);
                            }
                        }
                    });
                    timers.start();
                } else {//上传成功了做相应操作

                }
            }

            @Override
            public void onPackageSizeComputed(long param1Long) {//上传文件的大小 去做度更新UI

            }

            @Override
            public void onProgressChanged(float param1Long) {//上传文件的进  去做度更新UI

            }

            @Override
            public void onUploadError(int code, String error) {//文件上传失败返回

            }
        });
    }


    /**
     * 获取文件相关参数
     * @param params
     * @param url
     * @param files
     * @param uploadFileToServiceCallback
     */
    public void getToken(Map<String, String> params, String url, String apikey, final File files, UploadFileToServiceCallback uploadFileToServiceCallback){
        new Thread(new Runnable() {
            @Override
            public void run() {
                // TODO Auto-generated method stub
                try {
                    HttpClient client = HttpClientBuilder.create().build();// 开启一个客户端 HTTP 请求
                    HttpPost post = new HttpPost(url);//创建 HTTP POST 请求
                    MultipartEntityBuilder builder = MultipartEntityBuilder.create();
                    builder.setMode(HttpMultipartMode.BROWSER_COMPATIBLE);//设置浏览器兼容模式
                    for(Map.Entry<String, String> entry:params.entrySet()){
                        builder.addTextBody(entry.getKey(), entry.getValue());//设置请求参数
                        if(entry.getKey().equals("buildUpdateDescription")){
                            builder.addTextBody(entry.getKey(), entry.getValue(), ContentType.create(entry.getValue(), Charset.forName("UTF-8")));
                        }
                    }
                    HttpEntity entity = builder.build();// 生成 HTTP POST 实体
                    post.setEntity(new HttpEntityWrapper(entity));//设置请求参数
                    HttpResponse response = client.execute(post);// 发起请求 并返回请求的响应
                    if (response.getStatusLine().getStatusCode() == 200) {
                        String responseString = EntityUtils.toString(response.getEntity(), "UTF-8");
                        JSONObject backData = new JSONObject(responseString);
                        int code = backData.getInt("code");
                        JSONObject jsonObject = backData.getJSONObject("data");
                        if(code == 0 && jsonObject != null){
                            JSONObject jsonObjectparams = jsonObject.getJSONObject("params");
                            Map<String, String> params = new HashMap<>();
                            String key = jsonObjectparams.getString("key");
                            params.put("key",key);
                            params.put("signature",jsonObjectparams.getString("signature"));
                            params.put("x-cos-security-token",jsonObjectparams.getString("x-cos-security-token"));
                            String url = jsonObject.getString("endpoint");
                            uploadFileToServer(params, url, files, apikey, key,uploadFileToServiceCallback);
                        } else {
                            String msg = jsonObjectparams.getString("message");
                            uploadFileToServiceCallback.onUploadError(code,msg);
                        }
                    }
                } catch (Exception e) {
                    // TODO Auto-generated catch block
                    e.printStackTrace();
                    uploadFileToServiceCallback.onUploadError(-1,e.getMessage());
                }
            }
        }).start();
    }

    /**
     * 上传文件
     * @param params 请求参数，包括请求的的方法参数method如：“upload”，
     *               请求上传的文件类型fileTypes如：“.jpg.png.docx”
     * @param files  要上传的文件集合
     */
    public void uploadFileToServer(final Map<String, String> params, String url ,final File files, String apikey, String buildKey, UploadFileToServiceCallback uploadFileToServiceCallback) {
        this.uploadFileToServiceCallback = uploadFileToServiceCallback;
        // TODO Auto-generated method stub
        new Thread(new Runnable() {
            @Override
            public void run() {
                // TODO Auto-generated method stub
                try {
                    uploadFiles(params, url, files, apikey, buildKey, uploadFileToServiceCallback);
                } catch (Exception e) {
                    // TODO Auto-generated catch block
                    e.printStackTrace();
                    uploadFileToServiceCallback.onUploadError(-1,e.getMessage());
                }
            }
        }).start();
    }

    /**
     * 上传文件实现
     * @param params 请求参数，包括请求的的方法参数method如：“upload”，
     *               请求上传的文件类型fileTypes如：“.jpg.png.docx”
     * @param files  要上传的文件集合
     */
    public void uploadFiles(final Map<String, String> params, String url ,final File files, String apikey, String buildKey, UploadFileToServiceCallback uploadFileToServiceCallback,) {
        // TODO Auto-generated method stub
        HttpClient client = HttpClientBuilder.create().build();// 开启一个客户端 HTTP 请求
        HttpPost post = new HttpPost(url);//创建 HTTP POST 请求
        MultipartEntityBuilder builder = MultipartEntityBuilder.create();
        builder.setMode(HttpMultipartMode.BROWSER_COMPATIBLE);//设置浏览器兼容模式
        for(Map.Entry<String, String> entry:params.entrySet()){
            System.out.println(entry.getKey()+"--->"+entry.getValue());
            builder.addTextBody(entry.getKey(), entry.getValue());//设置请求参数
            if(entry.getKey().equals("buildUpdateDescription")){
                builder.addTextBody(entry.getKey(), entry.getValue(), ContentType.create(entry.getValue(),Charset.forName("UTF-8")));
            }
        }
        builder.addBinaryBody("file", files);
        if (this.uploadFileToServiceCallback != null)
            this.uploadFileToServiceCallback.onPackageSizeComputed(100);
        HttpEntity entity = builder.build();// 生成 HTTP POST 实体
        post.setEntity(new ProgressHttpEntityWrapper(entity,this));//设置请求参数
        HttpResponse response = client.execute(post);// 发起请求 并返回请求的响应
        int httpCode = response.getStatusLine().getStatusCode();
        if (httpCode == 204) {
            uploadFileToServiceCallback.onUploadBack(FILE_UPLOAD_SUCCESSFUL,"文件上传成功等待同步数据");
            //数据同步需要时间延时5秒请求同步结果
            timers = new Timer(5000, new ActionListener() {
                @Override
                public void actionPerformed(ActionEvent e) {
                    if(timers != null){
                        timers.stop();
                        timers = null;
                        String url = "https://www.pgyer.com/apiv2/app/buildInfo?_api_key="+apikey+"&buildKey="+buildKey;
                        uploadResult(url,uploadFileToServiceCallback);
                    }
                }
            });
            timers.start();
        } else {
            if(uploadFileToServiceCallback != null){
                uploadFileToServiceCallback.onUploadError(httpCode,"上传失败！");
            }
        }

    }

    /**
     * 获取上传文件后同步信息
     * @param url
     */
    public void uploadResult(String url,UploadFileToServiceCallback uploadFileToServiceCallback){
        new Thread(new Runnable() {
            @Override
            public void run() {
                // TODO Auto-generated method stub
                try {
                    HttpClient client = HttpClientBuilder.create().build();// 开启一个客户端 HTTP 请求
                    HttpGet get = new HttpGet(url);//创建 HTTP POST 请求
                    HttpResponse response = client.execute(get);// 发起请求 并返回请求的响应
                    if (response.getStatusLine().getStatusCode() == 200) {
                        String responseString = EntityUtils.toString(response.getEntity(), "UTF-8");
                        JSONObject backDatas = new JSONObject(responseString);
                        int code = backDatas.getInt("code");
                        if(code == 0){//上传成功
                            backData = responseString;
                            JSONObject data = backDatas.getJSONObject("data");
                            //返回成功后相关文件信息
                            if (uploadFileToServiceCallback != null) {
                                uploadFileToServiceCallback.onUploadBack(code,responseString);
                            }
                        } else if(code == 1246){//等待同步
                            uploadFileToServiceCallback.onUploadBack(code,url);
                        } else {//上传失败
                            if (uploadFileToServiceCallback != null) {
                                uploadFileToServiceCallback.onUploadError(code,"上传失败");
                            }
                        }
                    }
                } catch (Exception e) {
                    // TODO Auto-generated catch block
                    e.printStackTrace();
                    uploadFileToServiceCallback.onUploadError(-1,e.getMessage());
                }
            }
        }).start();
    }

    @Override
    public void progress(float progress) {
        uploadFileToServiceCallback.onProgressChanged(progress);
    }

    /**
     * 上传文件封装监听
     */
    public class ProgressHttpEntityWrapper extends HttpEntityWrapper {

        private final ProgressCallback progressCallback;

        public static interface ProgressCallback {
            public void progress(float progress);
        }

        public ProgressHttpEntityWrapper(final HttpEntity entity, final ProgressCallback progressCallback) {
            super(entity);
            this.progressCallback = progressCallback;
        }

        @Override
        public void writeTo(final OutputStream out) throws IOException {
            this.wrappedEntity.writeTo(out instanceof ProgressFilterOutputStream ? out : new ProgressFilterOutputStream(out, this.progressCallback, getContentLength()));
        }

        public static class ProgressFilterOutputStream extends FilterOutputStream {

            private final ProgressCallback progressCallback;
            private long transferred;
            private long totalBytes;

            ProgressFilterOutputStream(final OutputStream out, final ProgressCallback progressCallback, final long totalBytes) {
                super(out);
                this.progressCallback = progressCallback;
                this.transferred = 0;
                this.totalBytes = totalBytes;
            }

            @Override
            public void write(final byte[] b, final int off, final int len) throws IOException {
                //super.write(byte b[], int off, int len) calls write(int b)
                out.write(b, off, len);
                this.transferred += len;
                this.progressCallback.progress(getCurrentProgress());
            }

            @Override
            public void write(final int b) throws IOException {
                out.write(b);
                this.transferred++;
                this.progressCallback.progress(getCurrentProgress());
            }

            private float getCurrentProgress() {
                return ((float) this.transferred / this.totalBytes) * 100;
            }

        }
    }

    public interface UploadFileToServiceCallback {
        //上传成功 或者 同步数据接口成功返回
        void onUploadBack(int code,String msg);
        //上传文件大小
        void onPackageSizeComputed(long param1Long);
        //上传文件进度
        void onProgressChanged(float param1Long);
        //上传失败返回
        void onUploadError(int code,String error);
    }

    public interface HttpCallback{
        void onSuccessful(int code, String data){

        }
        void onError(int code, String data){

        }
    }
}
