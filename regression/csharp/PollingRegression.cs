using System.Text.Json;

class PollingRegression
{
    static void Main(string[] args)
    {
        using var cases = JsonDocument.Parse(File.ReadAllText(args[0]));
        foreach (var test in cases.RootElement.EnumerateArray())
        {
            var responses = test.GetProperty("responses");
            int calls = 0;
            Exception error = null;
            Response<BuildInfoResponse> result = null;
            try
            {
                result = PGYERAppUploader.PollBuildInfo(() =>
                {
                    int index = calls++;
                    if (test.TryGetProperty("transportError", out _)) throw new IOException("mock transport failure");
                    if (index >= responses.GetArrayLength()) throw new Exception("Unexpected extra poll");
                    var response = responses[index];
                    var json = response.ValueKind == JsonValueKind.String ? response.GetString() : response.GetRawText();
                    return JsonSerializer.Deserialize<Response<BuildInfoResponse>>(json);
                }, message => {});
            }
            catch (Exception ex) { error = ex; }

            string name = test.GetProperty("name").GetString();
            if (calls != test.GetProperty("requests").GetInt32()) throw new Exception($"{name}: request count {calls}");
            if (test.TryGetProperty("errorContains", out var parts))
            {
                if (error == null) throw new Exception($"{name}: expected failure");
                foreach (var part in parts.EnumerateArray())
                    if (!error.Message.Contains(part.GetString())) throw new Exception($"{name}: lost original error: {error}");
            }
            else if (error != null || result?.Data?.BuildKey != "fixture")
                throw new Exception($"{name}: expected build info", error);
            Console.WriteLine($"PASS C# {name}");
        }
    }
}
