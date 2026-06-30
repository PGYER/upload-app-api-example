using System.Text.Json;

/**
 * 此 Demo 演示如何使用 PGYER API 上传 App。
 * 详细文档参照 https://www.pgyer.com/doc/view/api#fastUploadApp
 * 支持上传 iOS (.ipa)、Android (.apk) 和 HarmonyOS (.hap) 应用。
 */
class Demo
{
    public static void Main(string[] args)
    {
        string? apiKey = Environment.GetEnvironmentVariable("PGYER_API_KEY");
        string? appPath = Environment.GetEnvironmentVariable("PGYER_APP_PATH");

        if (string.IsNullOrWhiteSpace(apiKey))
        {
            Console.Error.WriteLine("Please set PGYER_API_KEY.");
            Environment.Exit(1);
        }

        if (string.IsNullOrWhiteSpace(appPath))
        {
            Console.Error.WriteLine("Please set PGYER_APP_PATH.");
            Environment.Exit(1);
        }

        try
        {
            PGYERAppUploader uploader = new PGYERAppUploader(apiKey);

            if (Environment.GetEnvironmentVariable("PGYER_DEBUG") == "1")
            {
                uploader.WithDebug();
            }

            UploadOption option = new UploadOption
            {
                FilePath = appPath,
                Oversea = Environment.GetEnvironmentVariable("PGYER_OVERSEA") ?? "",
                BuildInstallType = Environment.GetEnvironmentVariable("PGYER_INSTALL_TYPE") ?? "1",
                BuildPassword = Environment.GetEnvironmentVariable("PGYER_INSTALL_PASSWORD") ?? "",
                BuildDescription = Environment.GetEnvironmentVariable("PGYER_BUILD_DESCRIPTION") ?? "",
                BuildUpdateDescription = Environment.GetEnvironmentVariable("PGYER_UPDATE_DESCRIPTION") ?? ""
            };

            Response<BuildInfoResponse> response = uploader.Upload(option);
            Console.WriteLine(JsonSerializer.Serialize(response, new JsonSerializerOptions { WriteIndented = true }));

            if (response.Data?.BuildShortcutUrl != null)
            {
                Console.WriteLine($"Download URL: https://www.pgyer.com/{response.Data.BuildShortcutUrl}");
            }
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"Upload failed: {ex.Message}");
            Environment.Exit(1);
        }
    }
}
