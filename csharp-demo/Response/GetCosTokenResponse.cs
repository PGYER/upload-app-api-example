

using System.Text.Json.Serialization;


public class CosTokenParam{
    [JsonPropertyName("signature")]
    public string Signature {get; set;}
    [JsonPropertyName("x-cos-security-token")]
    public string SecurityToken {get; set;}
    [JsonPropertyName("key")]
    public string Key {get; set;}
}

public class CosTokenResponse{

    [JsonPropertyName("key")]
    public string Key {get; set;}

    [JsonPropertyName("endpoint")]
    public string Endpoint{get; set;}

    [JsonPropertyName("params")]
    public CosTokenParam Param {get; set;}
}