using System.Text.Json.Serialization;

public class BuildInfoResponse
{
    [JsonPropertyName("buildKey")]
    public string BuildKey { get; set; }
    [JsonPropertyName("buildType")]
    public string BuildType { get; set; }
    [JsonPropertyName("buildIsFirst")]
    public string BuildIsFirst { get; set; }
    [JsonPropertyName("buildIsLastest")]
    public string BuildIsLastest { get; set; }
    [JsonPropertyName("buildFileSize")]
    public string BuildFileSize { get; set; }
    [JsonPropertyName("buildName")]
    public string BuildName { get; set; }
    [JsonPropertyName("buildVersion")]
    public string BuildVersion { get; set; }
    [JsonPropertyName("buildVersionNo")]
    public string BuildVersionNo { get; set; }
    [JsonPropertyName("buildBuildVersion")]
    public string BuildBuildVersion { get; set; }
    [JsonPropertyName("buildIdentifier")]
    public string BuildIdentifier { get; set; }
    [JsonPropertyName("buildIcon")]
    public string BuildIcon { get; set; }
    [JsonPropertyName("buildDescription")]
    public string BuildDescription { get; set; }
    [JsonPropertyName("buildUpdateDescription")]
    public string BuildUpdateDescription { get; set; }
    [JsonPropertyName("buildScreenShots")]
    public string BuildScreenShots { get; set; }
    [JsonPropertyName("buildShortcutUrl")]
    public string BuildShortcutUrl { get; set; }
    [JsonPropertyName("buildQRCodeURL")]
    public string BuildQRCodeURL { get; set; }
    [JsonPropertyName("buildCreated")]
    public string BuildCreated { get; set; }
    [JsonPropertyName("buildUpdated")]
    public string BuildUpdated { get; set; }
}