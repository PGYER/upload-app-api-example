#!/bin/bash
#
# Shell script to upload iOS, Android and HarmonyOS app files to PGYER via API
# https://www.pgyer.com/doc/view/api#fastUploadApp
#

# ---------------------------------------------------------------
# Constants
# ---------------------------------------------------------------
readonly API_DOMAIN="api.pgyer.com"
readonly API_BASE_URL="http://${API_DOMAIN}/apiv2"
readonly SUPPORTED_TYPES=("ipa" "apk" "hap")
readonly DOH_SERVICE="https://dns.alidns.com/resolve"

# ---------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------
LOG_ENABLE=1
PROGRESS_ENABLE=1
JSON_OUTPUT=0

# ---------------------------------------------------------------
# Utility Functions
# ---------------------------------------------------------------
log() {
    [ $LOG_ENABLE -eq 1 ] && echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

resolveDomainViaDoH() {
    local domain="$1"
    log "Resolving ${domain} via DoH..."
    
    local response=$(curl -s -H 'Accept: application/dns-json' "${DOH_SERVICE}?name=${domain}&type=A")
    
    # Parse the first IP address from the response
    local ip=$(echo "${response}" | grep -o '"data":"[0-9.]*"' | head -1 | cut -d'"' -f4)
    
    if [ -z "${ip}" ]; then
        log "Warning: DoH resolution failed, falling back to system DNS"
        return 1
    fi
    
    log "Resolved ${domain} to ${ip}"
    echo "${ip}"
    return 0
}

logTitle() {
    log "-------------------------------- $* --------------------------------"
}

execCommand() {
    log "$@"
    result=$(eval $@)
}

# ---------------------------------------------------------------
# Parameter Processing Functions
# ---------------------------------------------------------------
printHelp() {
    cat << EOF
Usage: $0 -k <api_key> [OPTION]... file
Upload iOS, Android or HarmonyOS app package file to PGYER.
Examples: 
  $0 -k xxxxxxxxxxxxxxx /data/app.ipa     # Upload iOS app
  $0 -k xxxxxxxxxxxxxxx /data/app.apk     # Upload Android app  
  $0 -k xxxxxxxxxxxxxxx /data/app.hap     # Upload HarmonyOS app

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
EOF
    exit 1
}

parseArguments() {
    while getopts 'k:t:p:d:s:e:c:qjh' OPT; do
        case $OPT in
            k) api_key="$OPTARG";;
            t) buildInstallType="$OPTARG";;
            p) buildPassword="$OPTARG";;
            d) buildUpdateDescription="$OPTARG";;
            e) buildInstallDate="$OPTARG";;
            s) buildInstallStartDate="$OPTARG";;
            e) buildInstallEndDate="$OPTARG";;
            c) buildChannelShortcut="$OPTARG";;
            q) PROGRESS_ENABLE=0;;
            j) JSON_OUTPUT=1;;
            ?) printHelp;;
        esac
    done

    shift $(($OPTIND - 1))
    readonly file=$1
}

validateInputs() {
    # Check API key
    if [ -z "$api_key" ]; then
        echo "Error: api_key is empty"
        printHelp
    fi

    # Check if file exists
    if [ ! -f "$file" ]; then
        echo "Error: file not exists"
        printHelp
    fi

    # Check if file type is supported
    buildType=${file##*.}
    if [[ ! " ${SUPPORTED_TYPES[@]} " =~ " ${buildType} " ]]; then
        echo "Error: file extension '${buildType}' is not supported"
        printHelp
    fi
}

# ---------------------------------------------------------------
# Business Logic Functions
# ---------------------------------------------------------------
getUploadToken() {
    logTitle "Step 1: Get Token"

    local command="curl -s"
    [ -n "${RESOLVED_IP}" ] && command="${command} --resolve ${API_DOMAIN}:80:${RESOLVED_IP}"
    [ -n "$api_key" ]                && command="${command} --form-string '_api_key=${api_key}'"
    [ -n "$buildType" ]              && command="${command} --form-string 'buildType=${buildType}'"
    [ -n "$buildInstallType" ]       && command="${command} --form-string 'buildInstallType=${buildInstallType}'"
    [ -n "$buildPassword" ]          && command="${command} --form-string 'buildPassword=${buildPassword}'"
    [ -n "$buildUpdateDescription" ] && command="${command} --form-string $'buildUpdateDescription=${buildUpdateDescription}'"
    [ -n "$buildInstallDate" ]       && command="${command} --form-string 'buildInstallDate=${buildInstallDate}'"
    [ -n "$buildInstallStartDate" ]  && command="${command} --form-string 'buildInstallStartDate=${buildInstallStartDate}'"
    [ -n "$buildInstallEndDate" ]    && command="${command} --form-string 'buildInstallEndDate=${buildInstallEndDate}'"
    [ -n "$buildChannelShortcut" ]   && command="${command} --form-string 'buildChannelShortcut=${buildChannelShortcut}'"
    command="${command} ${API_BASE_URL}/app/getCOSToken"
    
    execCommand "$command"

    # Parse response
    [[ "${result}" =~ \"endpoint\":\"([\:\_\.\/\\A-Za-z0-9\-]+)\" ]] && endpoint=`echo ${BASH_REMATCH[1]} | sed 's!\\\/!/!g'`
    [[ "${result}" =~ \"key\":\"([\.a-z0-9]+)\" ]] && key=`echo ${BASH_REMATCH[1]}`
    [[ "${result}" =~ \"signature\":\"([\=\&\_\;A-Za-z0-9\-]+)\" ]] && signature=`echo ${BASH_REMATCH[1]}`
    [[ "${result}" =~ \"x-cos-security-token\":\"([\_A-Za-z0-9\-]+)\" ]] && x_cos_security_token=`echo ${BASH_REMATCH[1]}`

    if [ -z "$key" ] || [ -z "$signature" ] || [ -z "$x_cos_security_token" ] || [ -z "$endpoint" ]; then
        log "Error: Failed to get upload token"
        exit 1
    fi
}

uploadFile() {
    logTitle "Step 2: Upload File"

    local file_name=${file##*/}
    local progress_option="--progress-bar"
    [ $PROGRESS_ENABLE -eq 0 ] && progress_option="-s"

    # Upload with timeout and better error handling
    local command="curl -o /dev/null -w '%{http_code}' \
        ${progress_option} \
        --connect-timeout 30 \
        --max-time 1800 \
        --form-string 'key=${key}' \
        --form-string 'signature=${signature}' \
        --form-string 'x-cos-security-token=${x_cos_security_token}' \
        --form-string 'x-cos-meta-file-name=${file_name}' \
        -F 'file=@\"${file}\"' \
        '${endpoint}'"
    
    execCommand "$command"

    if [ $result -ne 204 ]; then
        log "Error: Upload failed with HTTP status code: ${result}"
        log "Please check your network connection and file permissions"
        exit 1
    fi
    
    log "File uploaded successfully"
}

checkResult() {
    logTitle "Step 3: Check Result"

    local max_retries=60
    local url_printed=0
    local final_result=""
    local resolve_param=""
    [ -n "${RESOLVED_IP}" ] && resolve_param="--resolve ${API_DOMAIN}:80:${RESOLVED_IP}"

    for i in $(seq 1 $max_retries); do
        execCommand "curl -s ${resolve_param} ${API_BASE_URL}/app/buildInfo?_api_key=${api_key}\&buildKey=${key}"
        final_result="${result}"
        
        # Parse the result
        [[ "${result}" =~ \"code\":([0-9]+) ]] && code=`echo ${BASH_REMATCH[1]}`
        
        if [ $code -eq 0 ]; then
            # Extract and print URL only once
            if [ $url_printed -eq 0 ]; then
                [[ "${result}" =~ \"buildShortcutUrl\":\"([^\"]+)\" ]] && shortcut_url=`echo ${BASH_REMATCH[1]}`
                if [ -n "$shortcut_url" ]; then
                    log "Upload successful! App URL: https://www.xcxwo.com/${shortcut_url}"
                fi
                url_printed=1
            fi
            break
        else
            log "Checking build status... (Attempt ${i}/${max_retries})"
            sleep 1
        fi
    done

    if [ $code -ne 0 ]; then
        log "Error: Build check failed after ${max_retries} attempts"
        exit 1
    fi

    # Output full JSON response if requested
    if [ $JSON_OUTPUT -eq 1 ]; then
        log "Full response JSON:"
        echo "${final_result}"
    fi
}

# ---------------------------------------------------------------
# Main Function
# ---------------------------------------------------------------
main() {
    parseArguments "$@"
    validateInputs
    
    # Resolve API domain via DoH to avoid DNS pollution
    RESOLVED_IP=$(resolveDomainViaDoH "${API_DOMAIN}")
    
    getUploadToken
    uploadFile
    checkResult
}

# Execute main function
main "$@"
