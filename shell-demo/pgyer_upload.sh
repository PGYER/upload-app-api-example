#!/bin/bash
#
# Shell script to upload iOS, Android and HarmonyOS app files to PGYER via API
# https://www.pgyer.com/doc/view/api#fastUploadApp
#

# ---------------------------------------------------------------
# Constants
# ---------------------------------------------------------------
readonly API_DOMAINS=("api.pgyer.com" "api.xcxwo.com" "api.pgyeraapp.com")
readonly SUPPORTED_TYPES=("ipa" "apk" "hap")
readonly DOH_SERVICE="https://dns.alidns.com/resolve"

# These will be set after domain selection
API_DOMAIN=""
API_BASE_URL=""

# ---------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------
LOG_ENABLE=1
PROGRESS_ENABLE=1
JSON_OUTPUT=0
VERBOSE_MODE=0

# Colors
if [ -t 1 ]; then
    COLOR_RESET='\033[0m'
    COLOR_GREEN='\033[0;32m'
    COLOR_BLUE='\033[0;34m'
    COLOR_YELLOW='\033[0;33m'
    COLOR_RED='\033[0;31m'
    COLOR_CYAN='\033[0;36m'
    COLOR_BOLD='\033[1m'
else
    COLOR_RESET=''
    COLOR_GREEN=''
    COLOR_BLUE=''
    COLOR_YELLOW=''
    COLOR_RED=''
    COLOR_CYAN=''
    COLOR_BOLD=''
fi

# ---------------------------------------------------------------
# Utility Functions
# ---------------------------------------------------------------
log() {
    [ $LOG_ENABLE -eq 1 ] && echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

log_success() {
    [ $LOG_ENABLE -eq 1 ] && echo -e "${COLOR_GREEN}✓${COLOR_RESET} $*" >&2
}

log_info() {
    [ $LOG_ENABLE -eq 1 ] && echo -e "${COLOR_BLUE}ℹ${COLOR_RESET} $*" >&2
}

log_warning() {
    [ $LOG_ENABLE -eq 1 ] && echo -e "${COLOR_YELLOW}⚠${COLOR_RESET} $*" >&2
}

log_error() {
    echo -e "${COLOR_RED}✗${COLOR_RESET} $*" >&2
}

log_step() {
    [ $LOG_ENABLE -eq 1 ] && echo -e "\n${COLOR_CYAN}${COLOR_BOLD}▶ $*${COLOR_RESET}\n" >&2
}

log_verbose() {
    [ $VERBOSE_MODE -eq 1 ] && [ $LOG_ENABLE -eq 1 ] && echo -e "  ${COLOR_YELLOW}→${COLOR_RESET} $*" >&2
}

testDomainConnectivity() {
    local domain="$1"
    local test_url="http://${domain}/apiv2/app/getCOSToken"
    
    log_verbose "Testing connectivity to ${domain}..."
    
    # Try to connect with a short timeout
    local http_code=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 10 "${test_url}" 2>/dev/null)
    
    if [ "${http_code}" = "000" ] || [ -z "${http_code}" ]; then
        log_verbose "${domain} is not reachable"
        return 1
    fi
    
    log_verbose "${domain} is reachable (HTTP ${http_code})"
    return 0
}

selectAvailableDomain() {
    log_step "Selecting available API domain"
    
    for domain in "${API_DOMAINS[@]}"; do
        if testDomainConnectivity "${domain}"; then
            API_DOMAIN="${domain}"
            API_BASE_URL="http://${API_DOMAIN}/apiv2"
            log_success "Using domain: ${API_DOMAIN}"
            
            # Try to resolve via DoH
            RESOLVED_IP=$(resolveDomainViaDoH "${API_DOMAIN}")
            return 0
        fi
    done
    
    log_error "All API domains are unreachable"
    log_error "Tried domains: ${API_DOMAINS[*]}"
    exit 1
}

resolveDomainViaDoH() {
    local domain="$1"
    log_info "Resolving ${domain}..."
    
    local response=$(curl -s -H 'Accept: application/dns-json' "${DOH_SERVICE}?name=${domain}&type=A")
    
    # Parse the first IP address from the response
    local ip=$(echo "${response}" | grep -o '"data":"[0-9.]*"' | head -1 | cut -d'"' -f4)
    
    if [ -z "${ip}" ]; then
        log_warning "DoH resolution failed, falling back to system DNS"
        return 1
    fi
    
    log_verbose "Resolved to ${ip}"
    echo "${ip}"
    return 0
}

logTitle() {
    log "$*"
}

execCommand() {
    log_verbose "$@"
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
  -v                               verbose mode, show detailed curl commands
  -h help                          show this help

Report bugs to: <https://github.com/PGYER/pgyer_api_example/issues>
Project home page: <https://github.com/PGYER/pgyer_api_example>
EOF
    exit 1
}

parseArguments() {
    while getopts 'k:t:p:d:s:e:c:qjvh' OPT; do
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
            v) VERBOSE_MODE=1;;
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
    log_step "Step 1/3: Getting upload token"

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
        log_error "Failed to get upload token"
        exit 1
    fi
    
    log_success "Token obtained successfully"
}

uploadFile() {
    log_step "Step 2/3: Uploading file"

    local file_name=${file##*/}
    local file_size=$(ls -lh "${file}" | awk '{print $5}')
    log_info "File: ${file_name} (${file_size})"
    
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
        log_error "Upload failed with HTTP status code: ${result}"
        log_error "Please check your network connection and file permissions"
        exit 1
    fi
    
    log_success "File uploaded successfully"
}

checkResult() {
    log_step "Step 3/3: Processing build"

    local max_retries=60
    local final_result=""
    local resolve_param=""
    [ -n "${RESOLVED_IP}" ] && resolve_param="--resolve ${API_DOMAIN}:80:${RESOLVED_IP}"

    log_info "Waiting for build processing..."
    
    for i in $(seq 1 $max_retries); do
        execCommand "curl -s ${resolve_param} ${API_BASE_URL}/app/buildInfo?_api_key=${api_key}\&buildKey=${key}"
        final_result="${result}"
        
        # Parse the result
        [[ "${result}" =~ \"code\":([0-9]+) ]] && code=`echo ${BASH_REMATCH[1]}`
        
        if [ $code -eq 0 ]; then
            # Extract app information
            [[ "${result}" =~ \"buildShortcutUrl\":\"([^\"]+)\" ]] && shortcut_url=`echo ${BASH_REMATCH[1]}`
            [[ "${result}" =~ \"buildVersion\":\"([^\"]+)\" ]] && version=`echo ${BASH_REMATCH[1]}`
            [[ "${result}" =~ \"buildVersionNo\":\"([^\"]+)\" ]] && version_code=`echo ${BASH_REMATCH[1]}`
            [[ "${result}" =~ \"buildName\":\"([^\"]+)\" ]] && app_name=`echo ${BASH_REMATCH[1]}`
            
            echo ""
            log_success "Build completed!"
            echo ""
            [ -n "$app_name" ] && echo -e "  ${COLOR_BOLD}App:${COLOR_RESET}     ${app_name}"
            [ -n "$version" ] && echo -e "  ${COLOR_BOLD}Version:${COLOR_RESET} ${version} (${version_code})"
            if [ -n "$shortcut_url" ]; then
                echo -e "  ${COLOR_BOLD}URL:${COLOR_RESET}     ${COLOR_GREEN}https://www.xcxwo.com/${shortcut_url}${COLOR_RESET}"
            fi
            echo ""
            break
        else
            # Show progress with spinner
            local spinner=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
            local idx=$((i % 10))
            printf "\r  ${spinner[$idx]} Processing... (${i}s)" >&2
            sleep 1
        fi
    done
    
    # Clear progress line
    printf "\r\033[K" >&2

    if [ $code -ne 0 ]; then
        log_error "Build check failed after ${max_retries} attempts"
        exit 1
    fi

    # Output full JSON response if requested
    if [ $JSON_OUTPUT -eq 1 ]; then
        echo ""
        echo "${COLOR_BOLD}Full JSON Response:${COLOR_RESET}"
        echo "${final_result}"
    fi
}

# ---------------------------------------------------------------
# Main Function
# ---------------------------------------------------------------
main() {
    parseArguments "$@"
    validateInputs
    
    # Select an available API domain
    selectAvailableDomain
    
    getUploadToken
    uploadFile
    checkResult
}

# Execute main function
main "$@"
