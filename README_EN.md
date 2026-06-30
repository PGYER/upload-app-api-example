# PGYER API Upload App Code Examples

## Languages

- [English](README_EN.md)
- [简体中文](README.md)

## Introduction

[PGYER](https://www.pgyer.com) is a beta app hosting and distribution platform for mobile app packages. It supports:

- iOS packages: `.ipa`
- Android packages: `.apk`
- HarmonyOS packages: `.hap`

This repository demonstrates how to upload iOS, Android, and HarmonyOS app packages with the PGYER new upload API, then retrieve the build result and download URL.

The new upload API uses a three-step flow: get an upload credential, upload the app package, and query the build result. It is faster than the legacy v1 and v2 upload APIs. The legacy APIs are still available, but new integrations should use the new upload API.

## Quick Start

If you only need to upload from the command line or a CI workflow, start with the Shell demo:

```bash
cd shell-demo
chmod +x ./pgyer_upload.sh
./pgyer_upload.sh -k <your-pgyer-api-key> <your-ipa-or-apk-or-hap-file-path>
```

After a successful upload, the script prints the app name, version, and download page URL. To print the full JSON response, add `-j`:

```bash
./pgyer_upload.sh -k <your-pgyer-api-key> -j <your-app-file-path>
```

## Examples

Each language directory includes a runnable demo, parameter reference, and response example:

| Language | Directory | Notes |
| --- | --- | --- |
| Shell | [shell-demo](shell-demo) | Best for command-line usage, CI/CD, and one-line uploads |
| Java | [java-demo](java-demo) | Maven project example |
| Node.js | [nodejs-demo](nodejs-demo) | Supports both Promise and Callback styles |
| PHP | [php-demo](php-demo) | PHP 7.4+ example |
| Python | [python-demo](python-demo) | Python 3 script example |
| C# | [csharp-demo](csharp-demo) | .NET example |

## API Flow

The new upload API follows this flow:

1. Request an upload credential from PGYER.
2. Upload the `.ipa`, `.apk`, or `.hap` file with the credential.
3. Poll the build result to retrieve the app name, version, shortcut URL, QR code, and related build metadata.

The examples in this repository wrap these steps for you. In most cases, you only need to provide your API Key, app package path, and optional release parameters.

## Common Parameters

| Parameter | Required | Description |
| --- | --- | --- |
| API Key | Yes | Available in your PGYER account settings |
| File path | Yes | Path to the `.ipa`, `.apk`, or `.hap` package |
| Install type | No | `1` public, `2` password protected, `3` invitation only |
| Install password | No | Used when the install type is password protected |
| Update description | No | Release notes for this upload |
| Channel shortcut | No | Shortcut of the channel to update |

For the full parameter list, see the README in each language directory or the [PGYER API upload documentation](https://www.pgyer.com/doc/view/api#fastUploadApp).

## Resources

- [Upload app with a single Shell command](shell-demo)
- [Postman API call template](https://www.postman.com/pgyerdevs/workspace/pgyer-api)
- [GitHub Actions workflow](https://github.com/PGYER/pgyer-upload-app-action)
- [Fastlane plugin](https://github.com/shishirui/fastlane-plugin-pgyer)
- [MCP server](https://github.com/PGYER/pgyer-mcp-server)
- [Agent Skill](https://github.com/PGYER/pgyer-skill)

## Links

- [PGYER official website](https://www.pgyer.com)
- [Get your PGYER API Key](https://www.pgyer.com/account/api)
- [PGYER API upload documentation](https://www.pgyer.com/doc/view/api#fastUploadApp)

## Contributing

Contributions for new language examples, fixes, and documentation improvements are welcome. When adding a new language example, please include:

- A runnable demo
- Dependency installation instructions
- API parameter reference
- Successful response example
- Common error handling notes
