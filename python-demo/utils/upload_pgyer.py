# -*- coding: utf-8 -*-

import os
import time

import requests
from requests_toolbelt.multipart.encoder import MultipartEncoder, MultipartEncoderMonitor
from tqdm import tqdm

# 官方文档
# https://www.pgyer.com/doc/view/api#fastUploadApp

SUPPORTED_TYPES = ("ipa", "apk", "hap")
SERVICE_HOSTS = ("api.pgyer.com", "api.xcxwo.com", "api.pgyerapp.com")
DNS_SERVICE = "https://dns.alidns.com/resolve"

CONNECT_TIMEOUT = 5
REQUEST_TIMEOUT = 30
UPLOAD_TIMEOUT = 120
BUILD_POLL_INTERVAL = 1
BUILD_MAX_ATTEMPTS = 60
UPLOAD_MAX_RETRIES = 3

host = None
hostname = None


def _call_callback(callback, success, result):
    if callback is not None:
        callback(success, result)


def _request_base():
    if not host or not hostname:
        raise RuntimeError("PGYER API service is not initialized")

    headers = {}
    verify = True

    if host == hostname:
        base_url = f"https://{hostname}"
    else:
        # Fallback mode: use the DoH-resolved IP with the original Host header.
        # Certificate verification cannot be used against the raw IP address.
        base_url = f"https://{host}"
        headers["Host"] = hostname
        verify = False

    return base_url, headers, verify


def _api_get(path, params=None, timeout=REQUEST_TIMEOUT):
    base_url, headers, verify = _request_base()
    return requests.get(
        f"{base_url}{path}",
        params=params,
        headers=headers,
        timeout=timeout,
        verify=verify,
    )


def _api_post(path, data=None, timeout=REQUEST_TIMEOUT):
    base_url, headers, verify = _request_base()
    return requests.post(
        f"{base_url}{path}",
        data=data,
        headers=headers,
        timeout=timeout,
        verify=verify,
    )


def _check_connectivity():
    """
    检查连通性。优先使用正常域名连接；只有直连失败时才通过 DoH 获取 IP 作为兜底。
    """
    global host, hostname

    for service_host in SERVICE_HOSTS:
        try:
            response = requests.get(
                f"https://{service_host}/apiv2",
                timeout=CONNECT_TIMEOUT,
            )
            data = response.json()
            if data and data.get("code") == 1001:
                host = service_host
                hostname = service_host
                return
        except Exception:
            pass

        try:
            response = requests.get(
                f"{DNS_SERVICE}?name={service_host}&type=A",
                timeout=CONNECT_TIMEOUT,
            )
            data = response.json()
            answers = data.get("Answer", [])
            a_records = [item for item in answers if item.get("type") == 1]

            if a_records:
                host = a_records[0]["data"]
                hostname = service_host
                return
        except Exception:
            pass

    raise RuntimeError("❌ 无法连接到蒲公英 API 服务，请检查网络连接")


def _get_build_type(file_path):
    """
    根据文件扩展名获取构建类型。
    """
    if not file_path:
        raise ValueError("❌ 文件路径不能为空")

    if not os.path.isfile(file_path):
        raise FileNotFoundError(f"❌ 文件不存在或不是普通文件: {file_path}")

    file_ext = os.path.splitext(file_path)[1][1:].lower()

    if file_ext not in SUPPORTED_TYPES:
        raise ValueError(
            f"❌ 不支持的文件类型: {file_ext or 'unknown'}，支持的类型: {', '.join(SUPPORTED_TYPES)}"
        )

    if file_ext == "ipa":
        return "ios"
    if file_ext == "apk":
        return "android"
    return "harmony"


def _get_cos_token(
    api_key,
    build_type,
    install_type,
    oversea="",
    password="",
    build_description="",
    update_description="",
    install_date="",
    install_start_date="",
    install_end_date="",
    channel_shortcut="",
):
    payload = {
        "_api_key": api_key,
        "buildType": build_type,
        "buildInstallType": install_type,
        "buildPassword": password,
        "buildDescription": build_description,
        "buildUpdateDescription": update_description,
        "buildInstallDate": install_date,
        "buildInstallStartDate": install_start_date,
        "buildInstallEndDate": install_end_date,
        "buildChannelShortcut": channel_shortcut,
    }
    if oversea:
        payload["oversea"] = oversea

    response = _api_post("/apiv2/app/getCOSToken", data=payload)
    if response.status_code != requests.codes.ok:
        raise RuntimeError(f"获取上传凭证失败，HTTP 状态码: {response.status_code}")

    result = response.json()
    if result.get("code") != 0 or not result.get("data"):
        raise RuntimeError(f"获取上传凭证失败: {result.get('message', result)}")

    data = result["data"]
    if not data.get("endpoint") or not data.get("params"):
        raise RuntimeError("获取上传凭证失败: 响应缺少 endpoint 或 params")

    return result


def _extract_build_key(token_result):
    data = token_result.get("data") or {}
    params = data.get("params") or {}
    build_key = params.get("key") or data.get("key")
    if not build_key:
        raise RuntimeError("获取构建结果失败: 上传凭证响应缺少 buildKey")
    return build_key


def _upload_file(upload_url, token_result, file_path):
    token_data = token_result["data"]
    file_name = os.path.basename(file_path)
    last_error = None

    for attempt in range(1, UPLOAD_MAX_RETRIES + 1):
        try:
            with open(file_path, "rb") as file_obj:
                payload = dict(token_data["params"])
                payload["file"] = (file_name, file_obj, "application/octet-stream")

                encoder = MultipartEncoder(fields=payload)
                print("\n📤 开始上传文件...")

                with tqdm(
                    total=encoder.len,
                    unit="B",
                    unit_scale=True,
                    unit_divisor=1024,
                    desc="上传进度",
                    ncols=80,
                ) as pbar:

                    def progress_callback(monitor):
                        pbar.update(monitor.bytes_read - pbar.n)

                    monitor = MultipartEncoderMonitor(encoder, progress_callback)
                    headers = {"Content-Type": monitor.content_type}

                    response = requests.post(
                        upload_url,
                        data=monitor,
                        headers=headers,
                        timeout=UPLOAD_TIMEOUT,
                    )

            if response.status_code == 204:
                print("\n✅ 文件上传成功")
                return

            last_error = f"上传失败，HTTP 状态码: {response.status_code}, 响应: {response.text}"
            if response.status_code < 500:
                break
        except Exception as exc:
            last_error = f"上传异常: {exc}"

        if attempt < UPLOAD_MAX_RETRIES:
            print(f"\n⚠️ {last_error}，准备重试 ({attempt}/{UPLOAD_MAX_RETRIES})...")
            time.sleep(1)

    raise RuntimeError(last_error or "上传失败")


def _get_build_info(api_key, token_result):
    print("🔄 检查应用处理状态...")

    build_key = _extract_build_key(token_result)
    params = {
        "_api_key": api_key,
        "buildKey": build_key,
    }

    for attempt in range(1, BUILD_MAX_ATTEMPTS + 1):
        response = _api_get("/apiv2/app/buildInfo", params=params)
        if response.status_code != requests.codes.ok:
            raise RuntimeError(f"获取构建信息失败，HTTP 状态码: {response.status_code}")

        result = response.json()
        code = result.get("code")

        if code == 0 and result.get("data"):
            return result

        if code in (1246, 1247):
            status_msg = "正在解析应用包..." if code == 1246 else "正在发布应用..."
            print(f"⏳ {status_msg} ({attempt}/{BUILD_MAX_ATTEMPTS})")
            time.sleep(BUILD_POLL_INTERVAL)
            continue

        raise RuntimeError(f"获取构建信息失败: {result.get('message', result)}")

    raise TimeoutError(f"获取构建信息超时，已等待 {BUILD_MAX_ATTEMPTS * BUILD_POLL_INTERVAL} 秒")


def upload_to_pgyer(
    path,
    api_key,
    install_type=1,
    oversea="",
    password="",
    build_description="",
    update_description="",
    install_date="",
    install_start_date="",
    install_end_date="",
    channel_shortcut="",
    callback=None,
):
    """
    上传到蒲公英。
    :param path: 文件路径 (支持 .ipa/.apk/.hap 文件)
    :param api_key: API Key
    :param install_type: 应用安装方式，值为(1,2,3)。1：公开，2：密码安装，3：邀请安装。默认为 1 公开安装
    :param oversea: 是否使用海外加速上传，1 为海外，2 为国内；留空时根据 IP 自动判断
    :param password: App 安装密码
    :param build_description: 应用介绍
    :param update_description: 版本更新描述
    :param install_date: 安装有效期类型，1 为设置时间，2 为长期有效
    :param install_start_date: 安装有效期开始时间，格式：2018-01-01
    :param install_end_date: 安装有效期结束时间，格式：2018-12-31
    :param channel_shortcut: 指定渠道短链接
    :param callback: 上传完成回调函数
    :return: 上传成功时返回 PGYER API 响应；失败时返回 None
    """
    print("\n" + "=" * 60)
    print("🚀 开始上传应用到蒲公英")
    print("=" * 60)

    try:
        if not api_key:
            raise ValueError("❌ API Key 不能为空")

        print("🔍 检查网络连通性...")
        _check_connectivity()
        print(f"✅ 连接成功: {hostname} ({host})")

        print(f"📂 检查文件: {os.path.basename(path or '')}")
        build_type = _get_build_type(path)
        file_size = os.path.getsize(path)
        print(f"✅ 文件类型: {build_type.upper()}, 大小: {file_size / (1024 * 1024):.2f} MB")

        print("\n📤 正在获取上传凭证...")
        token_result = _get_cos_token(
            api_key=api_key,
            build_type=build_type,
            install_type=install_type,
            oversea=oversea,
            password=password,
            build_description=build_description,
            update_description=update_description,
            install_date=install_date,
            install_start_date=install_start_date,
            install_end_date=install_end_date,
            channel_shortcut=channel_shortcut,
        )

        _upload_file(token_result["data"]["endpoint"], token_result, path)

        print("⏳ 正在处理应用包，请稍等...")
        result = _get_build_info(api_key=api_key, token_result=token_result)
        _call_callback(callback, True, result)
        return result
    except Exception as exc:
        print(f"❌ 上传失败: {exc}")
        _call_callback(callback, False, None)
        return None
