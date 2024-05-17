using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

class PGYERAppUploader
{
    private readonly string _apikey;
    private readonly string _baseurl;
    private bool _debug;
    private readonly string[] _suffixs = [".ipa", ".apk"];
    public PGYERAppUploader(string apikey, string baseurl = "https://www.pgyer.com")
    {
        this._apikey = apikey;
        this._baseurl = baseurl;
    }

    public void WithDebug()
    {
        _debug = true;
    }

    private void Record(string message)
    {
        if (this._debug)
        {
            Console.WriteLine(string.Format("{0: yyyy-MM-dd HH:mm:ss.3f} {1}", DateTime.Now, message));
        }
    }

    public Response<BuildInfoResponse> Upload(UploadOption option)
    {
        FileInfo file = new FileInfo(@$"{option.FilePath}");
        if (!file.Exists)
            throw new Exception($"no such {option.FilePath} file.");
        if (!this._suffixs.Contains(file.Extension.ToLower()))
            throw new Exception("invalid file extension, only support .ipa or .apk extension");
        // step 1
        // get costoken
        CosTokenRequest cosTokenRequest = new CosTokenRequest
        {
            ApiKey = this._apikey,
            BuildType = file.Extension.TrimStart('.'),
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
        // step 2 
        // upload app to bucket
        UploadAppRequest uploadAppRequest = new UploadAppRequest
        {
            Key = cosTokenResponse.Data.Param.Key,
            Signature = cosTokenResponse.Data.Param.Signature,
            SecurityToken = cosTokenResponse.Data.Param.SecurityToken,
            Filename = file.Name,
            Endpoint = cosTokenResponse.Data.Endpoint,
            File = file
        };
        HttpResponseMessage uploadAppResponse = this.UploadApp(uploadAppRequest);
        if (!uploadAppResponse.StatusCode.Equals(HttpStatusCode.NoContent))
            throw new Exception($"Failed upload app to bucket: {uploadAppResponse.Content.ReadAsStringAsync().Result}");
        this.Record("upload app to bucket successful.");
        // step 3 
        // BuildInfo
        BuildInfoRequest buildInfoRequest = new BuildInfoRequest
        {
            ApiKey = this._apikey,
            BuildKey = cosTokenResponse.Data.Param.Key
        };
        for (var time = 1; time <= 60; time++)
        {
            this.Record($"[{time}] get app build info...");
            Response<BuildInfoResponse> buildInfoResponse = this.BuildInfo(buildInfoRequest);
            if (buildInfoResponse.Code != 0 || buildInfoResponse.Data == null)
            {
                System.Threading.Thread.Sleep(1000);
                continue;
            }
            return buildInfoResponse;
        }
        return null;
    }

    public Response<CosTokenResponse> GetCosToken(CosTokenRequest request)
    {

        if (!request.Validate())
        {
            throw new Exception("CosTokenRequest invalid");
        }

        FormUrlEncodedContent content = new FormUrlEncodedContent(request.Serialize());

        this.Record($"get upload token with params: {content.ReadAsStringAsync().Result}");

        HttpResponseMessage response = this.post("/apiv2/app/getCOSToken", content);

        if (!response.IsSuccessStatusCode)
            throw new Exception($"POST /apiv2/app/getCOSToken {response.StatusCode} failed");

        this.Record($"get upload token with response: {response.Content.ReadAsStringAsync().Result}");

        return JsonSerializer.Deserialize<Response<CosTokenResponse>>(response.Content.ReadAsStringAsync().Result);
    }

    public HttpResponseMessage UploadApp(UploadAppRequest request)
    {
        if (!request.Validate())
            throw new Exception("UploadAppRequest invalid");
        string record = "";
        string boundary = string.Format("---------------------{0}", DateTime.Now.Ticks.ToString("x"));
        using (MultipartFormDataContent multipart = new MultipartFormDataContent(boundary))
        {
            multipart.Headers.ContentType = MediaTypeHeaderValue.Parse($"multipart/form-data; boundary={boundary}");
            // data field 
            foreach (var param in request.Serialize())
            {
                var content = new ByteArrayContent(Encoding.UTF8.GetBytes(param.Value));
                content.Headers.TryAddWithoutValidation("Content-Disposition", $"form-data; name=\"{param.Key}\"");
                multipart.Add(content);
                record += $"{param.Key}={param.Value}&";
            }
            // file field
            var fileContent = new ByteArrayContent(File.ReadAllBytes(@$"{request.File.FullName}"));
            fileContent.Headers.TryAddWithoutValidation("Content-Disposition", $"form-data; name=\"file\"; filename=\"{request.File.Name}\"");
            multipart.Add(fileContent);
            this.Record($"upload app to bucket with params: {record}file={request.File.FullName}");
            return this.post(request.Endpoint, multipart);
        }
    }

    public Response<BuildInfoResponse> BuildInfo(BuildInfoRequest request)
    {
        if (!request.Validate())
            throw new Exception("BuildInfoRequest invalid");

        FormUrlEncodedContent content = new FormUrlEncodedContent(request.Serialize());

        this.Record($"get build info from: {this._baseurl}/apiv2/app/buildInfo?{content.ReadAsStringAsync().Result}");

        HttpResponseMessage response = this.get($"/apiv2/app/buildInfo?{content.ReadAsStringAsync().Result}");

        if (!response.IsSuccessStatusCode)
            throw new Exception($"GET /apiv2/app/buildInfo {response.StatusCode} failed.");

        return JsonSerializer.Deserialize<Response<BuildInfoResponse>>(response.Content.ReadAsStringAsync().Result);
    }

    private HttpResponseMessage post(string url, HttpContent content, Dictionary<string, string> headers = null, int timeout = 30)
    {
        using (var client = new HttpClient())
        {
            client.BaseAddress = new Uri(this._baseurl);
            client.Timeout = new TimeSpan(0, 0, timeout);

            if (headers != null)
            {
                foreach (var header in headers)
                    client.DefaultRequestHeaders.Add(header.Key, header.Value);
            }
            return client.PostAsync(url, content).Result;
        }
    }

    private HttpResponseMessage get(string url, Dictionary<string, string> headers = null, int timeout = 30)
    {
        using (var client = new HttpClient())
        {
            client.Timeout = new TimeSpan(0, 0, timeout);
            client.BaseAddress = new Uri(this._baseurl);
            if (headers != null)
            {
                foreach (var header in headers)
                    client.DefaultRequestHeaders.Add(header.Key, header.Value);
            }
            return client.GetAsync(url).Result;
        }

    }
}