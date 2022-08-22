# shell 脚本使用说明

使用 curl 命令上传 app 安装包到蒲公英平台

### 使用说明

命令格式：

    ./pgyer-upload.sh <your-pgyer-api-key> <your-ipa-or-apk-file-path>
  
例如：

    ./demo.sh af91xxxxxxxxxxxxxxxxxxxxxxx5d39 /app/packages/demo.ipa
    
### 输出

上传成功后，返回上传后的结果，类型为JSON格式的字符

### 日志

默认为关闭状态，可以修改文件中的 `LOG_ENABLE=1` 来开启日志，这样可以在遇到错误时方便调试
