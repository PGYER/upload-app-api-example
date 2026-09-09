# Unified direct uploads

These examples require the server release that supports
`POST /apiv2/app/getUploadToken` with the unified response by default. Deploy and validate that release
before merging/publishing this branch for general use.

Existing users of `getCOSToken` can keep using their released scripts. Updating to
these examples opts into a storage-neutral protocol. The server chooses COS or OSS;
the client submits every field in `data.params` unchanged, then appends `file` last.
Do not hard-code a storage endpoint, field allowlist, or HTTP 204-only success check.

The API key, build type, installation settings, channel and final `buildInfo` result
keep their existing meaning. Original filenames are sent when supported by the example.
No `protocol` parameter is required or sent. The redesigned getUploadToken always
returns the unified response; callers of its earlier flat OSS format must update.
The separate getCOSToken endpoint retains its original COS contract.

After a 2xx response, poll buildInfo until published. OSS 203 CallbackFailed means the
object may already exist. After a timeout, 409 or other uncertain upload response,
these examples query the same build key before another upload attempt. The server can
recover a completed OSS object whose callback failed. They do not automatically
re-upload or switch providers. Codes 1246/1247 are pending; other nonzero buildInfo
codes terminate with failure. The polling window is bounded; if it expires, query
the same key again before intentionally starting a new upload.

Shell requires Python 3 or jq to preserve arbitrary form fields. Shell/PHP/Python/Node
integration tests exercise real multipart HTTP requests on localhost, including COS 204,
OSS 200, 203/503 recovery, unknown form fields, file ordering and terminal failure.

```bash
npm ci --prefix nodejs-demo
python3 -m pip install -r python-demo/requirements.txt
python3 tests/unified_upload_test.py
mvn -f java-demo/pom.xml -DskipTests package
dotnet build csharp-demo/csharp-demo.csproj
```

Use a supported Python version (3.9 or newer recommended). Tests do not call PGYER or
cloud storage. The backend gray release and full package publication/download
acceptance must be validated separately.
