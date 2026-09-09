using System.Text.Json.Serialization;

// The legacy class name is retained for callers; parameters are storage-neutral.
public class CosTokenResponse {
    [JsonPropertyName("key")]
    public string Key { get; set; }
    [JsonPropertyName("endpoint")]
    public string Endpoint { get; set; }
    [JsonPropertyName("params")]
    public Dictionary<string, string> Param { get; set; }
}
