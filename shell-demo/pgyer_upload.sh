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
WEB_DOMAIN=""

# ---------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------
LOG_ENABLE=1
PROGRESS_ENABLE=0
JSON_OUTPUT=0
VERBOSE_MODE=0
UPLOAD_MAX_RETRIES=3

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

log_verbose_command() {
    if [ $VERBOSE_MODE -eq 1 ] && [ $LOG_ENABLE -eq 1 ]; then
        local arg
        local safe_arg

        printf "  ${COLOR_YELLOW}→${COLOR_RESET} " >&2
        for arg in "$@"; do
            safe_arg="$arg"
            case "$safe_arg" in
                _api_key=*|key=*|signature=*|x-cos-security-token=*|buildPassword=*|buildKey=*)
                    safe_arg="${safe_arg%%=*}=***"
                    ;;
            esac
            printf "%q " "$safe_arg" >&2
        done
        printf "\n" >&2
    fi
}

testDomainConnectivity() {
    local domain="$1"
    local test_url="https://${domain}/apiv2/app/getCOSToken"
    
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
            API_BASE_URL="https://${API_DOMAIN}/apiv2"
            # Extract web domain by removing 'api.' prefix
            WEB_DOMAIN="${domain#api.}"
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

extractJsonDataField() {
    local field="$1"

    if command -v python3 >/dev/null 2>&1; then
        python3 -c 'import json, sys
field = sys.argv[1]
try:
    payload = json.load(sys.stdin)
except Exception:
    print("")
    sys.exit(0)
value = payload.get("data", {}).get(field, "")
print("" if value is None else value)' "$field"
    elif command -v jq >/dev/null 2>&1; then
        jq -r --arg field "$field" '.data[$field] // empty'
    else
        sed -n "s/.*\"${field}\":\"\([^\"]*\)\".*/\1/p"
    fi
}

extractJsonParamField() {
    local field="$1"

    if command -v python3 >/dev/null 2>&1; then
        python3 -c 'import json, sys
field = sys.argv[1]
try:
    payload = json.load(sys.stdin)
except Exception:
    print("")
    sys.exit(0)
value = payload.get("data", {}).get("params", {}).get(field, "")
print("" if value is None else value)' "$field"
    elif command -v jq >/dev/null 2>&1; then
        jq -r --arg field "$field" '.data.params[$field] // empty'
    else
        sed -n "s/.*\"${field}\":\"\([^\"]*\)\".*/\1/p"
    fi
}

extractJsonCode() {
    if command -v python3 >/dev/null 2>&1; then
        python3 -c 'import json, sys
try:
    payload = json.load(sys.stdin)
except Exception:
    print("")
    sys.exit(0)
value = payload.get("code", "")
print("" if value is None else value)'
    elif command -v jq >/dev/null 2>&1; then
        jq -r '.code // empty'
    else
        sed -n 's/.*"code":\([0-9][0-9]*\).*/\1/p'
    fi
}

shouldRetryUpload() {
    local curl_exit="$1"
    local http_code="$2"

    if [ "$curl_exit" -ne 0 ]; then
        case "$curl_exit" in
            5|6|7|18|28|35|52|55|56|92) return 0;;
            *) return 1;;
        esac
    fi

    case "$http_code" in
        408|429|500|502|503|504) return 0;;
        *) return 1;;
    esac
}

# ---------------------------------------------------------------
# Parameter Processing Functions
# ---------------------------------------------------------------
printHelp() {
    cat << EOF
Usage: $0 -k <api_key> [OPTION]... file
Upload iOS, Android or HarmonyOS app package file to PGYER.

Examples: 
  $0 -k xxxxxxxxxxxxxxx /path/to/app.ipa     # Upload iOS app
  $0 -k xxxxxxxxxxxxxxx /path/to/app.apk     # Upload Android app  
  $0 -k xxxxxxxxxxxxxxx /path/to/app.hap     # Upload HarmonyOS app

Options:
  -k <api_key>       (required) API key from PGYER
  -t <type>          Build install type: 1=public, 2=password, 3=invite
  -p <password>      Build password (required if type=2)
  -d <desc>          Build update description
  -e <date_type>     Build install date type: 1=interval, 2=forever
  -s <start_date>    Build install start date (yyyy-MM-dd)
  -E <end_date>      Build install end date (yyyy-MM-dd)
  -c <shortcut>      Build channel shortcut
  -P                 Show progress bar during upload
  -j                 Output full JSON response after completion
  -v                 Verbose mode, show detailed curl commands
  -h                 Show this help

Report bugs to: <https://github.com/PGYER/upload-app-api-example/issues>
Project home page: <https://github.com/PGYER/upload-app-api-example>
EOF
    exit 1
}

parseArguments() {
    while getopts 'k:t:p:d:s:e:E:c:Pjvh' OPT; do
        case $OPT in
            k) api_key="$OPTARG";;
            t) buildInstallType="$OPTARG";;
            p) buildPassword="$OPTARG";;
            d) buildUpdateDescription="$OPTARG";;
            e) buildInstallDate="$OPTARG";;
            s) buildInstallStartDate="$OPTARG";;
            E) buildInstallEndDate="$OPTARG";;
            c) buildChannelShortcut="$OPTARG";;
            P) PROGRESS_ENABLE=1;;
            j) JSON_OUTPUT=1;;
            v) VERBOSE_MODE=1;;
            ?) printHelp;;
        esac
    done

    shift $(($OPTIND - 1))
    readonly file=$1
}

validateInputs() {
    if ! command -v curl >/dev/null 2>&1; then
        log_error "curl is required but was not found."
        exit 1
    fi

    # Check API key
    if [ -z "$api_key" ]; then
        log_error "API key is required. Use -k option to specify your API key."
        log_info "Run '$0 -h' to see usage information"
        exit 1
    fi

    # Check if file exists
    if [ ! -f "$file" ]; then
        log_error "File not found: ${file}"
        log_info "Run '$0 -h' to see usage information"
        exit 1
    fi

    # Check if file type is supported
    buildType=$(printf '%s' "${file##*.}" | tr '[:upper:]' '[:lower:]')
    if [[ ! " ${SUPPORTED_TYPES[@]} " =~ " ${buildType} " ]]; then
        log_error "Unsupported file type '${buildType}'. Supported types: ${SUPPORTED_TYPES[*]}"
        log_info "Run '$0 -h' to see usage information"
        exit 1
    fi

    if [ "$buildInstallType" = "2" ] && [ -z "$buildPassword" ]; then
        log_error "Build password is required when build install type is 2."
        log_info "Use -p option to specify the build password."
        exit 1
    fi
}

# ---------------------------------------------------------------
# Business Logic Functions
# ---------------------------------------------------------------
getUploadToken() {
    log_step "Step 1/3: Getting upload token"

    local curl_args=(curl -sS)
    [ -n "${RESOLVED_IP}" ] && curl_args+=(--resolve "${API_DOMAIN}:443:${RESOLVED_IP}")
    [ -n "$api_key" ]                && curl_args+=(--form-string "_api_key=${api_key}")
    [ -n "$buildType" ]              && curl_args+=(--form-string "buildType=${buildType}")
    [ -n "$buildInstallType" ]       && curl_args+=(--form-string "buildInstallType=${buildInstallType}")
    [ -n "$buildPassword" ]          && curl_args+=(--form-string "buildPassword=${buildPassword}")
    [ -n "$buildUpdateDescription" ] && curl_args+=(--form-string "buildUpdateDescription=${buildUpdateDescription}")
    [ -n "$buildInstallDate" ]       && curl_args+=(--form-string "buildInstallDate=${buildInstallDate}")
    [ -n "$buildInstallStartDate" ]  && curl_args+=(--form-string "buildInstallStartDate=${buildInstallStartDate}")
    [ -n "$buildInstallEndDate" ]    && curl_args+=(--form-string "buildInstallEndDate=${buildInstallEndDate}")
    [ -n "$buildChannelShortcut" ]   && curl_args+=(--form-string "buildChannelShortcut=${buildChannelShortcut}")
    curl_args+=("${API_BASE_URL}/app/getCOSToken")

    log_verbose_command "${curl_args[@]}"
    result=$("${curl_args[@]}")
    local curl_exit=$?

    if [ "$curl_exit" -ne 0 ]; then
        log_error "Failed to get upload token (curl exit: ${curl_exit})"
        exit 1
    fi

    endpoint=$(printf '%s' "${result}" | extractJsonDataField "endpoint")
    build_key=$(printf '%s' "${result}" | extractJsonDataField "key")
    upload_key=$(printf '%s' "${result}" | extractJsonParamField "key")
    signature=$(printf '%s' "${result}" | extractJsonParamField "signature")
    x_cos_security_token=$(printf '%s' "${result}" | extractJsonParamField "x-cos-security-token")

    if [ -z "$build_key" ] || [ -z "$upload_key" ] || [ -z "$signature" ] || [ -z "$x_cos_security_token" ] || [ -z "$endpoint" ]; then
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
    [ $PROGRESS_ENABLE -eq 0 ] && progress_option="-sS"

    local curl_args=(
        curl
        -o /dev/null
        -w '%{http_code}'
        ${progress_option}
        --connect-timeout 30
        --max-time 1800
        --form-string "key=${upload_key}"
        --form-string "signature=${signature}"
        --form-string "x-cos-security-token=${x_cos_security_token}"
        --form-string "x-cos-meta-file-name=${file_name}"
        -F "file=@${file}"
        "${endpoint}"
    )
    
    local attempt=1
    local http_code=""
    local curl_exit=0
    local curl_error_file=$(mktemp "${TMPDIR:-/tmp}/pgyer-upload.XXXXXX")

    while [ $attempt -le $UPLOAD_MAX_RETRIES ]; do
        [ $UPLOAD_MAX_RETRIES -gt 1 ] && log_info "Upload attempt ${attempt}/${UPLOAD_MAX_RETRIES}"

        : > "${curl_error_file}"
        log_verbose_command "${curl_args[@]}"
        if [ $PROGRESS_ENABLE -eq 1 ]; then
            http_code=$("${curl_args[@]}" 2> >(tee "${curl_error_file}" >&2))
        else
            http_code=$("${curl_args[@]}" 2>"${curl_error_file}")
        fi
        curl_exit=$?
        [ -z "$http_code" ] && http_code="000"

        if [ "$curl_exit" -eq 0 ] && [ "$http_code" = "204" ]; then
            rm -f "${curl_error_file}"
            log_success "File uploaded successfully"
            return 0
        fi

        log_error "Upload attempt ${attempt} failed (curl exit: ${curl_exit}, HTTP status: ${http_code})"

        if [ $PROGRESS_ENABLE -eq 0 ] && [ -s "${curl_error_file}" ]; then
            sed 's/^/  /' "${curl_error_file}" >&2
        fi

        if [ $attempt -lt $UPLOAD_MAX_RETRIES ] && shouldRetryUpload "$curl_exit" "$http_code"; then
            local delay=$((attempt * 2))
            log_warning "Retrying upload in ${delay}s..."
            sleep "$delay"
        else
            rm -f "${curl_error_file}"
            log_error "Upload failed after ${attempt} attempt(s)"
            log_error "Please check your network connection, proxy settings and file permissions"
            exit 1
        fi

        attempt=$((attempt + 1))
    done
}

checkResult() {
    log_step "Step 3/3: Processing build"

    local max_retries=60
    local final_result=""
    local code=""
    local showed_progress=0

    log_info "Waiting for build processing..."
    
    for i in $(seq 1 $max_retries); do
        local curl_args=(curl -sS --get)
        [ -n "${RESOLVED_IP}" ] && curl_args+=(--resolve "${API_DOMAIN}:443:${RESOLVED_IP}")
        curl_args+=(--data-urlencode "_api_key=${api_key}")
        curl_args+=(--data-urlencode "buildKey=${build_key}")
        curl_args+=("${API_BASE_URL}/app/buildInfo")

        if [ $showed_progress -eq 1 ] && [ $VERBOSE_MODE -eq 1 ]; then
            printf "\r\033[K" >&2
            showed_progress=0
        fi

        log_verbose_command "${curl_args[@]}"
        result=$("${curl_args[@]}")
        local curl_exit=$?
        final_result="${result}"

        if [ "$curl_exit" -ne 0 ]; then
            code=""
        else
            code=$(printf '%s' "${result}" | extractJsonCode)
        fi
        
        if [ "$code" = "0" ]; then
            # Extract app information
            shortcut_url=$(printf '%s' "${result}" | extractJsonDataField "buildShortcutUrl")
            version=$(printf '%s' "${result}" | extractJsonDataField "buildVersion")
            version_code=$(printf '%s' "${result}" | extractJsonDataField "buildVersionNo")
            app_name=$(printf '%s' "${result}" | extractJsonDataField "buildName")

            if [ $showed_progress -eq 1 ]; then
                printf "\r\033[K" >&2
                showed_progress=0
            fi
            
            echo ""
            echo -e "${COLOR_GREEN}✓${COLOR_RESET} Build completed!"
            echo ""
            [ -n "$app_name" ] && echo -e "  ${COLOR_BOLD}App:${COLOR_RESET}     ${app_name}"
            [ -n "$version" ] && echo -e "  ${COLOR_BOLD}Version:${COLOR_RESET} ${version} (${version_code})"
            if [ -n "$shortcut_url" ]; then
                echo -e "  ${COLOR_BOLD}URL:${COLOR_RESET}     ${COLOR_GREEN}https://${WEB_DOMAIN}/${shortcut_url}${COLOR_RESET}"
            fi
            echo ""
            break
        else
            if [ $VERBOSE_MODE -eq 1 ]; then
                log_info "Processing... (${i}s)"
            else
                # Show progress with spinner
                local spinner=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
                local idx=$((i % 10))
                showed_progress=1
                printf "\r  ${spinner[$idx]} Processing... (${i}s)" >&2
            fi
            sleep 1
        fi
    done
    
    # Clear progress line
    [ $showed_progress -eq 1 ] && printf "\r\033[K" >&2

    if [ "$code" != "0" ]; then
        log_error "Build check failed after ${max_retries} attempts"
        exit 1
    fi

    # Output full JSON response if requested
    if [ $JSON_OUTPUT -eq 1 ]; then
        echo ""
        echo -e "${COLOR_BOLD}Full JSON Response:${COLOR_RESET}"
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
