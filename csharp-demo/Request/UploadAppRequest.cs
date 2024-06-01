
class UploadAppRequest
{

    [FormProperty("key", true)]
    public string Key { get; set; }
    [FormProperty("signature", true)]
    public string Signature { get; set; }
    [FormProperty("x-cos-security-token", true)]
    public string SecurityToken { get; set; }
    [FormProperty("x-cos-meta-file-name", false)]
    public string Filename { get; set; }
    public required string Endpoint { get; set; }
    public required FileInfo File {get; set;}
}