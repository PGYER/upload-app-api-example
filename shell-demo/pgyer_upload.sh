#!/bin/bash
#
# 通过shell脚本来实现将本地app文件通过API上传到蒲公英
# https://www.pgyer.com/doc/view/api#fastUploadApp
#

# Display log. 1=enable, 0=disable
LOG_ENABLE=1

printHelp() {
    echo "Usage: $0 -k <api_key> [OPTION]... file"
    echo "Upload iOS or Android app package file to PGYER."
    echo "Example: $0 -k xxxxxxxxxxxxxxx /data/app.ipa"
    echo ""
    echo "Description:"
    echo "  -k api_key                       (required) api key from PGYER"
    echo "  -t buildInstallType              build install type, 1=public, 2=password, 3=invite"
    echo "  -p buildPassword                 build password, required if buildInstallType=2"
    echo "  -d buildUpdateDescription        build update description"
    echo "  -e buildInstallDate              build install date, 1=buildInstallStartDate~buildInstallEndDate, 2=forever"
    echo "  -s buildInstallStartDate         build install start date, format: yyyy-MM-dd"
    echo "  -e buildInstallEndDate           build install end date, format: yyyy-MM-dd"
    echo "  -c buildChannelShortcut          build channel shortcut"
    echo "  -h help                          show this help"
    echo ""
    echo "Report bugs to: <https://github.com/PGYER/pgyer_api_example/issues>" 
    echo "Project home page: <https://github.com/PGYER/pgyer_api_example>" 
    exit 1
}

while getopts 'k:t:p:d:s:e:c:h' OPT; do
    case $OPT in
        k) api_key="$OPTARG";;
        t) buildInstallType="$OPTARG";;
        p) buildPassword="$OPTARG";;
        d) buildUpdateDescription="$OPTARG";;
        e) buildInstallDate="$OPTARG";;
        s) buildInstallStartDate="$OPTARG";;
        e) buildInstallEndDate="$OPTARG";;
        c) buildChannelShortcut="$OPTARG";;
        ?) printHelp;;
    esac
done

shift $(($OPTIND - 1))
readonly file=$1

# check api_key exists
if [ -z "$api_key" ]; then
    echo "api_key is empty"
    printHelp
fi

# check file exists
if [ ! -f "$file" ]; then
    echo "file not exists"
    printHelp
fi

# check ext supported
buildType=${file##*.}
if [ "$buildType" != "ipa" ] && [ "$buildType" != "apk" ]; then
    echo "file ext is not supported"
    printHelp
fi

# ---------------------------------------------------------------
# functions
# ---------------------------------------------------------------

log() {
    [ $LOG_ENABLE -eq 1 ]  && echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

logTitle() {
    log "-------------------------------- $* --------------------------------"
}

execCommand() {
    log "$@"
    result=$(eval $@)
}

# ---------------------------------------------------------------
# 获取上传凭证
# ---------------------------------------------------------------

logTitle "获取凭证"

command="curl -s"
[ -n "$api_key" ]                && command="${command} --form-string '_api_key=${api_key}'";
[ -n "$buildType" ]              && command="${command} --form-string 'buildType=${buildType}'";
[ -n "$buildInstallType" ]       && command="${command} --form-string 'buildInstallType=${buildInstallType}'";
[ -n "$buildPassword" ]          && command="${command} --form-string 'buildPassword=${buildPassword}'";
[ -n "$buildUpdateDescription" ] && command="${command} --form-string $'buildUpdateDescription=${buildUpdateDescription}'";
[ -n "$buildInstallDate" ]       && command="${command} --form-string 'buildInstallDate=${buildInstallDate}'";
[ -n "$buildInstallStartDate" ]  && command="${command} --form-string 'buildInstallStartDate=${buildInstallStartDate}'";
[ -n "$buildInstallEndDate" ]    && command="${command} --form-string 'buildInstallEndDate=${buildInstallEndDate}'";
[ -n "$buildChannelShortcut" ]   && command="${command} --form-string 'buildChannelShortcut=${buildChannelShortcut}'";
command="${command} http://www.pgyer.com/apiv2/app/getCOSToken";
execCommand $command

[[ "${result}" =~ \"endpoint\":\"([\:\_\.\/\\A-Za-z0-9\-]+)\" ]] && endpoint=`echo ${BASH_REMATCH[1]} | sed 's!\\\/!/!g'`
[[ "${result}" =~ \"key\":\"([\.a-z0-9]+)\" ]] && key=`echo ${BASH_REMATCH[1]}`
[[ "${result}" =~ \"signature\":\"([\=\&\_\;A-Za-z0-9\-]+)\" ]] && signature=`echo ${BASH_REMATCH[1]}`
[[ "${result}" =~ \"x-cos-security-token\":\"([\_A-Za-z0-9\-]+)\" ]] && x_cos_security_token=`echo ${BASH_REMATCH[1]}`

if [ -z "$key" ] || [ -z "$signature" ] || [ -z "$x_cos_security_token" ] || [ -z "$endpoint" ]; then
    log "get upload token failed"
    exit 1
fi

# ---------------------------------------------------------------
# 上传文件
# ---------------------------------------------------------------

logTitle "上传文件"

file_name=${file##*/}

execCommand "curl -s -o /dev/null -w '%{http_code}' \
--form-string 'key=${key}' \
--form-string 'signature=${signature}' \
--form-string 'x-cos-security-token=${x_cos_security_token}' \
--form-string 'x-cos-meta-file-name=${file_name}' \
-F 'file=@${file}' ${endpoint}"
if [ $result -ne 204 ]; then # if http code != 204, upload failed
    log "Upload failed"
    exit 1
fi

# ---------------------------------------------------------------
# 检查结果
# ---------------------------------------------------------------

logTitle "检查结果"

for i in {1..60}; do
    execCommand "curl -s http://www.pgyer.com/apiv2/app/buildInfo?_api_key=${api_key}\&buildKey=${key}"
    [[ "${result}" =~ \"code\":([0-9]+) ]] && code=`echo ${BASH_REMATCH[1]}`
    if [ $code -eq 0 ]; then
        echo $result
        break
    else
        sleep 1
    fi
done
