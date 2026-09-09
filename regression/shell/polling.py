#!/usr/bin/env python3
"""Run the real shell polling function with curl and sleep replaced locally."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

repo = Path(__file__).resolve().parents[2]
cases = json.loads(Path(sys.argv[1]).read_text())
for case in cases:
    with tempfile.TemporaryDirectory(prefix="pgyer-poll-") as folder:
        temp = Path(folder)
        (temp / "calls").write_text("0")
        (temp / "sleeps").write_text("0")
        for index, response in enumerate(case["responses"]):
            (temp / str(index)).write_text(response if isinstance(response, str) else json.dumps(response))
        command = r'''
source "$REPO/shell-demo/pgyer_upload.sh"
LOG_ENABLE=0
JSON_OUTPUT=1
api_key=fixture
build_key=fixture.apk
API_BASE_URL=https://api.invalid/apiv2
curl() {
    local count
    count=$(cat "$FIXTURE/calls")
    printf '%s' "$((count+1))" > "$FIXTURE/calls"
    [ "$TRANSPORT_ERROR" = 1 ] && return 28
    cat "$FIXTURE/$count"
}
sleep() {
    local count
    count=$(cat "$FIXTURE/sleeps")
    printf '%s' "$((count+1))" > "$FIXTURE/sleeps"
}
checkResult
'''
        env = dict(os.environ, REPO=str(repo), FIXTURE=str(temp),
                   TRANSPORT_ERROR="1" if case.get("transportError") else "0")
        result = subprocess.run(["bash", "-c", command], env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True, timeout=10)
        output = result.stdout + result.stderr
        calls = int((temp / "calls").read_text())
        sleeps = int((temp / "sleeps").read_text())
        assert calls == case.get("shellRequests", case["requests"]), (case["name"], calls, output)
        expected_sleeps = sum(isinstance(r, dict) and r.get("code") in (1246, 1247)
                              for r in case["responses"][:calls])
        if case.get("transportError"):
            expected_sleeps = calls - 1
        assert sleeps == expected_sleeps, (case["name"], sleeps, output)
        if "errorContains" in case:
            assert result.returncode != 0, (case["name"], output)
            for text in case["errorContains"]:
                assert text in output, (case["name"], text, output)
            assert "Build completed" not in output
        else:
            assert result.returncode == 0 and "Build completed" in output and '"fixture"' in output, (case["name"], output)
        print("PASS Shell " + case["name"])
