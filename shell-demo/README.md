# shell 脚本使用说明

使用 curl 命令上传 app 安装包到蒲公英平台。

默认支持 Linux、Mac 平台。如需在 Windows 上使用，请安装 [git bash](https://gitforwindows.org)。

## 使用说明

命令格式：

    ./pgyer_upload.sh -k <your-pgyer-api-key> <your-ipa-or-apk-file-path>

## 输出

上传成功后，输出上传后的结果，类型为 JSON 格式的字符

## 显示帮助

    $ ./pgyer_upload.sh -h
    
    Usage: ./pgyer_upload.sh -k <api_key> [OPTION]... file
    Upload iOS or Android app package file to PGYER.
    Example: ./pgyer_upload.sh -k xxxxxxxxxxxxxxx /data/app.ipa

    Description:
      -k api_key                       (required) api key from PGYER
      -t buildInstallType              build install type, 1=public, 2=password, 3=invite
      -p buildPassword                 build password, required if buildInstallType=2
      -d buildUpdateDescription        build update description
      -e buildInstallDate              build install date, 1=buildInstallStartDate~buildInstallEndDate, 2=forever
      -s buildInstallStartDate         build install start date, format: yyyy-MM-dd
      -e buildInstallEndDate           build install end date, format: yyyy-MM-dd
      -c buildChannelShortcut          build channel shortcut
      -q                               quiet mode, disable progress bar
      -j                               output full JSON response after completion
      -h help                          show this help

    Report bugs to: <https://github.com/PGYER/pgyer_api_example/issues>
    Project home page: <https://github.com/PGYER/pgyer_api_example>

## 日志

默认为关闭状态。您可以修改文件中的 `LOG_ENABLE=1` 来开启日志，这样可以在遇到错误时方便调试

## Windows 用户

1. 安装 [git bash](https://gitforwindows.org)，以便让 windows 具备 bash 环境
2. 以`bash.exe`来执行 `pgyer_upload.sh` 脚本

命令如下（注意您的安装目录可能有所不同，请相应替换）：

    D:\> & 'C:\Program Files\Git\bin\bash.exe' .\pgyer_upload.sh -k <your-pgyer-api-key> <your-ipa-or-apk-file>

完成后，就会直接返回 App 的上传结果

## 其他

[显示上传进度](https://github.com/PGYER/pgyer_api_example/issues/19)


