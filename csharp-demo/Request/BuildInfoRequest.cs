

class BuildInfoRequest
{

    [FormProperty("_api_key", true)]
    public string ApiKey { get; set; }
    [FormProperty("buildKey", true)]
    public string BuildKey { get; set; }
}