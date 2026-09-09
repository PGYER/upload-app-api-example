


class CosTokenRequest
{

    [FormProperty("_api_key", true)]
    public string ApiKey { get; set; }

    [FormProperty("buildType", true)]
    public string BuildType { get; set; }

    [FormProperty("oversea", false)]
    public string Oversea { get; set; }
    [FormProperty("buildInstallType", false)]
    public string BuildInstallType { get; set; }
    [FormProperty("buildPassword", false)]
    public string BuildPassword { get; set; }
    [FormProperty("buildDescription", false)]
    public string BuildDescription { get; set; }
    [FormProperty("buildUpdateDescription", false)]
    public string BuildUpdateDescription { get; set; }

    [FormProperty("buildInstallDate", false)]
    public string BuildInstallDate { get; set; }
    [FormProperty("buildInstallStartDate", false)]
    public string BuildInstallStartDate { get; set; }
    [FormProperty("buildInstallEndDate", false)]
    public string BuildInstallEndDate { get; set; }
    [FormProperty("buildChannelShortcut", false)]
    public string BuildChannelShortcut { get; set; }

}