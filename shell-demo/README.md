# shell 脚本使用说明

使用 curl 命令上传 app 安装包到蒲公英平台

## 使用说明

命令格式：

    ./pgyer-upload.sh <your-pgyer-api-key> <your-ipa-or-apk-file-path>
  
例如：

    ./demo.sh af91xxxxxxxxxxxxxxxxxxxxxxx5d39 /app/packages/demo.ipa
    
## 输出

上传成功后，返回上传后的结果，类型为 JSON 格式的字符

## 日志

默认为关闭状态，可以修改文件中的 `LOG_ENABLE=1` 来开启日志，这样可以在遇到错误时方便调试

## Windows 用户

1. 首先安装 git bash，以便让 windows 具备 bash 环境
2. 以`bash.exe`来执行 `pgyer_upload.sh` 脚本

命令如下（注意您的安装目录可能有所不同，请相应替换）：

    D:\> & 'C:\Program Files\Git\bin\bash.exe' .\pgyer_upload.sh <your-pgyer-api-key> <your-ipa-or-apk-file>

完成后，就会直接返回相应结果
