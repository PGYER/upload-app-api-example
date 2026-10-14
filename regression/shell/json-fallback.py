#!/usr/bin/env python3
"""Check the real JSON data-field extractor with only sed available on PATH."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[2]
bash = shutil.which("bash")
sed = shutil.which("sed")
if not bash or not sed:
    raise SystemExit("These regressions require Bash and sed.")

cases = [
    ("escaped-endpoint", "endpoint",
     r'{"code":0,"data":{"endpoint":"https:\/\/uploads.example.invalid\/path"}}',
     "https://uploads.example.invalid/path"),
    ("plain-endpoint", "endpoint",
     '{"code":0,"data":{"endpoint":"https://uploads.example.invalid/path"}}',
     "https://uploads.example.invalid/path"),
    ("ordinary-string", "buildVersion",
     '{"code":0,"data":{"buildVersion":"1.2.3"}}', "1.2.3"),
    ("escaped-slash-in-name", "buildName",
     r'{"code":0,"data":{"buildName":"Demo\/App"}}', "Demo/App"),
    ("missing-field", "endpoint", '{"code":0,"data":{}}', ""),
    ("empty-field", "endpoint", '{"code":0,"data":{"endpoint":""}}', ""),
]
command = r"""
source "$REPO/shell-demo/pgyer_upload.sh"
if command -v python3 >/dev/null 2>&1 || command -v jq >/dev/null 2>&1; then
    printf '%s\n' 'Expected python3 and jq to be unavailable.' >&2
    exit 1
fi
extractJsonDataField "$1"
"""
with tempfile.TemporaryDirectory(prefix="pgyer-json-fallback-") as folder:
    # Use the installed sed; hide JSON parsers without changing the host system.
    Path(folder, "sed").symlink_to(sed)
    env = dict(os.environ, REPO=str(repo), PATH=folder, LC_ALL="C")
    for name, field, payload, expected in cases:
        result = subprocess.run(
            [bash, "--noprofile", "--norc", "-c", command, "json-fallback", field],
            input=payload, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            universal_newlines=True, timeout=10,
        )
        # Production callers use command substitutions, stripping trailing newlines.
        value = result.stdout.rstrip("\n")
        if result.returncode != 0 or value != expected or result.stderr:
            raise AssertionError((name, result.returncode, result.stdout, result.stderr))
        print("PASS Shell JSON fallback " + name)
