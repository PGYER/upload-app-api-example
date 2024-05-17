

using System.Text.Json.Serialization;

class Response<T>
{
    [JsonPropertyName("code")]
    public int Code { get; set; }
    [JsonPropertyName("message")]
    public string Message { get; set; }
    [JsonPropertyName("data")]
    public T Data { get; set; }
}