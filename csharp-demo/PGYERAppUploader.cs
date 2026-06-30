using System.Net;
using System.Net.Http.Headers;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

class PGYERAppUploader
{
    private readonly string _apikey;
    private bool _debug;
    private readonly string[] _suffixes = [".ipa", ".apk", ".hap"];
    private string _host = "";
    private string _hostname = "";
    private readonly string _dnsService = "https://dns.alidns.com/resolve";
    private readonly string[] _serviceHosts = ["api.pgyer.com", "api.xcxwo.com", "api.pgyerapp.com"];

    private const int BuildInfoMaxAttempts = 60;
    private const int BuildInfoPollIntervalMs = 1000;

    public PGYERAppUploader(string apikey)
    {
        if (string.IsNullOrWhiteSpace(apikey))
            throw new ArgumentException("API key is required.", nameof(apikey));

        this._apikey = apikey;
        this.CheckConnectivity();
    }

    public void WithDebug()
    {
        _debug = true;
    }

    private void Record(string message)
    {
        if (this._debug)
        {
            Console.WriteLine($"{DateTime.Now:yyyy-MM-dd HH:mm:ss.fff} {RedactSensitiveText(message)}");
        }
    }

    public Response<BuildInfoResponse> Upload(UploadOption option)
    {
        if (option == null)
            throw new ArgumentNullException(nameof(option));

        FileInfo file = new FileInfo(option.FilePath ?? "");
        if (!file.Exists)
            throw new FileNotFoundException($"No such file: {option.FilePath}", option.FilePath);
        if (!this._suffixes.Contains(file.Extension.ToLowerInvariant()))
            throw new Exception("Invalid file extension, only support .ipa, .apk or .hap extension");

        string buildType = GetBuildType(file.Extension);

        this.Record($"Start upload, using service: {this._hostname} ({this._host}) ...");

        CosTokenRequest cosTokenRequest = new CosTokenRequest
        {
            ApiKey = this._apikey,
            BuildType = buildType,
            Oversea = option.Oversea ?? "",
            BuildInstallType = option.BuildInstallType ?? "",
            BuildPassword = option.BuildPassword ?? "",
            BuildDescription = option.BuildDescription ?? "",
            BuildUpdateDescription = option.BuildUpdateDescription ?? "",
            BuildInstallDate = option.BuildInstallDate ?? "",
            BuildInstallStartDate = option.BuildInstallStartDate ?? "",
            BuildInstallEndDate = option.BuildInstallEndDate ?? "",
            BuildChannelShortcut = option.BuildChannelShortcut ?? ""
        };
        Response<CosTokenResponse> cosTokenResponse = this.GetCosToken(cosTokenRequest);

        if (cosTokenResponse.Code != 0 || cosTokenResponse.Data == null || cosTokenResponse.Data.Param == null)
            throw new Exception($"Failed to get upload token: {cosTokenResponse.Message}");

        UploadAppRequest uploadAppRequest = new UploadAppRequest
        {
            Key = cosTokenResponse.Data.Param.Key,
            Signature = cosTokenResponse.Data.Param.Signature,
            SecurityToken = cosTokenResponse.Data.Param.SecurityToken,
            Filename = file.Name,
            Endpoint = cosTokenResponse.Data.Endpoint,
            File = file
        };
        this.UploadApp(uploadAppRequest);
        this.Record("upload app to bucket successful.");

        BuildInfoRequest buildInfoRequest = new BuildInfoRequest
        {
            ApiKey = this._apikey,
            BuildKey = cosTokenResponse.Data.Param.Key
        };
        for (var time = 1; time <= BuildInfoMaxAttempts; time++)
        {
            this.Record($"[{time}] get app build info...");
            Response<BuildInfoResponse> buildInfoResponse = this.BuildInfo(buildInfoRequest);
            if (buildInfoResponse.Code != 0 || buildInfoResponse.Data == null)
            {
                Thread.Sleep(BuildInfoPollIntervalMs);
                continue;
            }
            return buildInfoResponse;
        }

        throw new TimeoutException($"Build processing timed out after {BuildInfoMaxAttempts} seconds.");
    }

    public Response<CosTokenResponse> GetCosToken(CosTokenRequest request)
    {
        if (!request.Validate())
            throw new Exception("CosTokenRequest invalid");

        Dictionary<string, string> parameters = request.Serialize();
        using FormUrlEncodedContent content = new FormUrlEncodedContent(parameters);

        this.Record($"get upload token with params: {FormatParameters(parameters)}");

        HttpResult response = this.Post("/apiv2/app/getCOSToken", content);

        if (!response.IsSuccessStatusCode)
            throw new Exception($"POST /apiv2/app/getCOSToken {response.StatusCode} failed: {response.Body}");

        this.Record($"get upload token with response: {response.Body}");

        return DeserializeResponse<CosTokenResponse>(response.Body);
    }

    public void UploadApp(UploadAppRequest request)
    {
        if (!request.Validate())
            throw new Exception("UploadAppRequest invalid");
        if (string.IsNullOrWhiteSpace(request.Endpoint))
            throw new Exception("Upload endpoint is required.");
        if (request.File == null || !request.File.Exists)
            throw new FileNotFoundException("Upload file does not exist.", request.File?.FullName);

        Dictionary<string, string> parameters = request.Serialize();
        string boundary = string.Format("---------------------{0}", DateTime.Now.Ticks.ToString("x"));

        using MultipartFormDataContent multipart = new MultipartFormDataContent(boundary);
        multipart.Headers.ContentType = MediaTypeHeaderValue.Parse($"multipart/form-data; boundary={boundary}");

        foreach (var param in parameters)
        {
            var content = new ByteArrayContent(Encoding.UTF8.GetBytes(param.Value));
            content.Headers.TryAddWithoutValidation("Content-Disposition", $"form-data; name=\"{param.Key}\"");
            multipart.Add(content);
        }

        using FileStream fileStream = request.File.OpenRead();
        var fileContent = new StreamContent(fileStream);
        fileContent.Headers.ContentType = MediaTypeHeaderValue.Parse("application/octet-stream");
        fileContent.Headers.TryAddWithoutValidation("Content-Disposition", $"form-data; name=\"file\"; filename=\"{request.File.Name}\"");
        multipart.Add(fileContent);

        this.Record($"upload app to bucket with params: {FormatParameters(parameters)}&file={request.File.FullName}");

        HttpResult response = this.Post(request.Endpoint, multipart, timeout: 120);
        if (response.StatusCode != HttpStatusCode.NoContent)
            throw new Exception($"Failed upload app to bucket: HTTP {(int)response.StatusCode}, {response.Body}");
    }

    public Response<BuildInfoResponse> BuildInfo(BuildInfoRequest request)
    {
        if (!request.Validate())
            throw new Exception("BuildInfoRequest invalid");

        Dictionary<string, string> parameters = request.Serialize();
        string query = BuildQueryString(parameters);

        this.Record($"get build info from: https://{this._hostname}/apiv2/app/buildInfo?{query}");

        HttpResult response = this.Get($"/apiv2/app/buildInfo?{query}");

        if (!response.IsSuccessStatusCode)
            throw new Exception($"GET /apiv2/app/buildInfo {response.StatusCode} failed: {response.Body}");

        return DeserializeResponse<BuildInfoResponse>(response.Body);
    }

    private HttpResult Post(string url, HttpContent content, Dictionary<string, string>? headers = null, int timeout = 30)
    {
        return SendRequest(url, content, headers, timeout, HttpMethod.Post);
    }

    private HttpResult Get(string url, Dictionary<string, string>? headers = null, int timeout = 30)
    {
        return SendRequest(url, null, headers, timeout, HttpMethod.Get);
    }

    private HttpResult SendRequest(string url, HttpContent? content, Dictionary<string, string>? headers, int timeout, HttpMethod method)
    {
        using var handler = new SocketsHttpHandler();
        Uri uri;
        bool useResolvedHost = url.StartsWith("/");

        if (useResolvedHost)
        {
            uri = new Uri($"https://{this._hostname}{url}");
            handler.ConnectCallback = async (context, cancellationToken) =>
            {
                var socket = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);
                try
                {
                    await socket.ConnectAsync(this._host, 443, cancellationToken);
                    return new NetworkStream(socket, ownsSocket: true);
                }
                catch
                {
                    socket.Dispose();
                    throw;
                }
            };
        }
        else
        {
            uri = new Uri(url);
        }

        using var client = new HttpClient(handler)
        {
            Timeout = TimeSpan.FromSeconds(timeout)
        };

        using var request = new HttpRequestMessage(method, uri);
        if (content != null)
            request.Content = content;

        if (useResolvedHost)
            request.Headers.Host = this._hostname;

        if (headers != null)
        {
            foreach (var header in headers)
                request.Headers.TryAddWithoutValidation(header.Key, header.Value);
        }

        using HttpResponseMessage response = client.Send(request);
        string body = response.Content == null ? "" : response.Content.ReadAsStringAsync().GetAwaiter().GetResult();

        return new HttpResult
        {
            StatusCode = response.StatusCode,
            Body = body
        };
    }

    private void CheckConnectivity()
    {
        foreach (var serviceHost in this._serviceHosts)
        {
            try
            {
                using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(5) };
                using var response = client.GetAsync($"https://{serviceHost}/apiv2").Result;

                if (response.IsSuccessStatusCode)
                {
                    var content = response.Content.ReadAsStringAsync().Result;
                    using JsonDocument doc = JsonDocument.Parse(content);
                    if (doc.RootElement.TryGetProperty("code", out var codeElement) && codeElement.GetInt32() == 1001)
                    {
                        this._host = serviceHost;
                        this._hostname = serviceHost;
                        return;
                    }
                }
            }
            catch
            {
            }

            try
            {
                using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(5) };
                var dnsUrl = $"{this._dnsService}?name={serviceHost}&type=A";
                using var response = client.GetAsync(dnsUrl).Result;

                if (response.IsSuccessStatusCode)
                {
                    var content = response.Content.ReadAsStringAsync().Result;
                    using JsonDocument doc = JsonDocument.Parse(content);
                    if (doc.RootElement.TryGetProperty("Answer", out var answerArray))
                    {
                        foreach (var item in answerArray.EnumerateArray())
                        {
                            if (item.TryGetProperty("type", out var typeElement) && typeElement.GetInt32() == 1 &&
                                item.TryGetProperty("data", out var dataElement))
                            {
                                this._host = dataElement.GetString() ?? "";
                                this._hostname = serviceHost;
                                return;
                            }
                        }
                    }
                }
            }
            catch
            {
            }
        }

        throw new Exception("Cannot connect to PGYER API service.");
    }

    private static string GetBuildType(string extension)
    {
        switch (extension.ToLowerInvariant())
        {
            case ".ipa":
                return "ios";
            case ".apk":
                return "android";
            case ".hap":
                return "harmony";
            default:
                throw new Exception($"Unsupported file type: {extension}. Supported types: .ipa, .apk, .hap");
        }
    }

    private static Response<T> DeserializeResponse<T>(string body)
    {
        var result = JsonSerializer.Deserialize<Response<T>>(body);
        if (result == null)
            throw new Exception("Failed to parse PGYER API response.");
        return result;
    }

    private static string BuildQueryString(Dictionary<string, string> parameters)
    {
        return string.Join("&", parameters.Select(item =>
            $"{Uri.EscapeDataString(item.Key)}={Uri.EscapeDataString(item.Value)}"));
    }

    private static string FormatParameters(Dictionary<string, string> parameters)
    {
        return string.Join("&", parameters.Select(item =>
            $"{item.Key}={RedactSensitiveValue(item.Key, item.Value)}"));
    }

    private static string RedactSensitiveValue(string key, string value)
    {
        return IsSensitiveKey(key) ? "***" : value;
    }

    private static bool IsSensitiveKey(string key)
    {
        return key.Equals("_api_key", StringComparison.OrdinalIgnoreCase)
            || key.Equals("key", StringComparison.OrdinalIgnoreCase)
            || key.Equals("signature", StringComparison.OrdinalIgnoreCase)
            || key.Equals("x-cos-security-token", StringComparison.OrdinalIgnoreCase)
            || key.Equals("buildPassword", StringComparison.OrdinalIgnoreCase)
            || key.Equals("buildKey", StringComparison.OrdinalIgnoreCase);
    }

    private static string RedactSensitiveText(string text)
    {
        string redacted = Regex.Replace(
            text,
            "((?:_api_key|key|signature|x-cos-security-token|buildPassword|buildKey)=)([^&\\s]+)",
            "$1***",
            RegexOptions.IgnoreCase);

        return Regex.Replace(
            redacted,
            "(\"(?:_api_key|key|signature|x-cos-security-token|buildPassword|buildKey)\"\\s*:\\s*\")([^\"]+)(\")",
            "$1***$3",
            RegexOptions.IgnoreCase);
    }

    private class HttpResult
    {
        public HttpStatusCode StatusCode { get; set; }
        public string Body { get; set; } = "";
        public bool IsSuccessStatusCode => (int)StatusCode >= 200 && (int)StatusCode <= 299;
    }
}
