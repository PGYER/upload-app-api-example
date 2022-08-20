#!/bin/bash
#
# 通过shell脚本来实现将本地app文件通过API上传到蒲公英
# https://www.pgyer.com/doc/view/api#fastUploadApp
#
# 本程序依赖: jq (https://stedolan.github.io/jq/)
#
# 参数说明：
# $1: 蒲公英api_key
# $2: 要上传的文件路径
# $3: 安装包文件类型
#

# get the first argument
readonly api_key=$1
readonly file=$2
readonly app_type=$3

printHelp() {
    echo "Usage: $0 api_key file app_type"
    echo "Example: $0 <your_api_key> <your_file_path> <app_type>[ios|android]"
}

# check api_key exists
if [ -z "$api_key" ]; then
    echo "api_key is empty"
    printHelp
    exit 1
fi

# check file exists
if [ ! -f "$file" ]; then
    echo "file not exists"
    printHelp
    exit 1
fi

# check app_type if is [ios, android]
if [ -z "$app_type" ]; then
    echo "app_type is empty"
    printHelp
    exit 1
elif [ "$app_type" != "ios" ] && [ "$app_type" != "android" ]; then
    echo "app_type is not [ios, android]"
    printHelp
    exit 1
fi

# check if jq exists
if ! which jq > /dev/null; then
    echo "jq not found, please install it first"
    exit 1
fi

# ---------------------------------------------------------------
# functions
# ---------------------------------------------------------------

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

logTitle() {
    log "--------------------------------"
    log "$*"
    log "--------------------------------"
}

execCommand() {
    log "$@"
    result=$(eval $@)
}

# ---------------------------------------------------------------
# 获取上传凭证
# ---------------------------------------------------------------

logTitle "获取上传凭证"

execCommand "curl -s -F '_api_key=${api_key}' -F 'buildType=${app_type}' http://www.pgyer.com/apiv2/app/getCOSToken"
endpoint=`echo $result | jq -r '.data.endpoint'`
key=`echo $result | jq -r '.data.params.key'`
signature=`echo $result | jq -r '.data.params.signature'`
x_cos_security_token=`echo $result | jq -r '.data.params["x-cos-security-token"]'`

# ---------------------------------------------------------------
# 上传文件
# ---------------------------------------------------------------

logTitle "上传文件"

execCommand "curl -s -o /dev/null -w '%{http_code}' --form-string 'key=${key}' --form-string 'signature=${signature}' --form-string 'x-cos-security-token=${x_cos_security_token}' -F 'file=@${file}' ${endpoint}"
if [ $result -ne 204 ]; then
    log "Upload failed"
    exit 1
fi

# ---------------------------------------------------------------
# 检查结果
# ---------------------------------------------------------------

logTitle "检查结果"

for i in {1..20}; do
    execCommand "curl -s http://www.pgyer.com/apiv2/app/buildInfo?_api_key=${api_key}\&buildKey=${key}"
    code=`echo $result | jq -r '.code'`
    if [ $code == '0' ]; then
        log $result
        break
    else
        sleep 1
    fi
done
