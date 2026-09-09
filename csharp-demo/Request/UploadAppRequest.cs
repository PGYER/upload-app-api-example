class UploadAppRequest {
    public Dictionary<string, string> FormFields { get; set; }
    public required string Endpoint { get; set; }
    public required FileInfo File { get; set; }
}
