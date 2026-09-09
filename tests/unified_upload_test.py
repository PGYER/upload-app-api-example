"""Run actual multipart requests against a local fixture; never calls PGYER/cloud services."""
import cgi
import io
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs

ROOT = pathlib.Path(__file__).resolve().parents[1]
class FixtureHandler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass
    def do_GET(self):
        self.respond()
    def do_POST(self):
        self.respond()
    def respond(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        if self.path.startswith("/upload"):
            form = cgi.FieldStorage(fp=io.BytesIO(body), headers=self.headers,
                environ={"REQUEST_METHOD": "POST", "CONTENT_TYPE": self.headers["Content-Type"]})
            self.server.uploads.append([(field.name, field.value) for field in form.list])
            self.send_response(self.server.upload_status)
            self.end_headers()
            self.wfile.write(b"<Error><Code>CallbackFailed</Code></Error>" if self.server.upload_status == 203 else b"")
            return
        if "getUploadToken" in self.path:
            if self.headers.get("Content-Type", "").startswith("multipart/"):
                form = cgi.FieldStorage(fp=io.BytesIO(body), headers=self.headers,
                    environ={"REQUEST_METHOD": "POST", "CONTENT_TYPE": self.headers["Content-Type"]})
                protocol = form.getvalue("protocol")
            else:
                protocol = parse_qs(body.decode()).get("protocol", [""])[0]
            self.server.protocols.append(protocol)
            payload = {"code": 0, "data": {"key": "fixture.hap", "endpoint": self.server.base + "/upload",
                "params": self.server.fields, "method": "POST", "fileField": "file"}}
        elif "buildInfo" in self.path:
            self.server.polls += 1
            payload = {"code": self.server.build_code, "message": "fixture", "data": {"buildKey": "fixture", "buildName": "Fixture"}}
        else:
            payload = {"code": 1001, "Answer": []}
        data = json.dumps(payload).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

class UnifiedUploadTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = HTTPServer(("127.0.0.1", 0), FixtureHandler)
        cls.server.base = "http://127.0.0.1:{}".format(cls.server.server_port)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.tmp = tempfile.TemporaryDirectory()
        cls.file = pathlib.Path(cls.tmp.name) / "fixture.hap"
        cls.file.write_bytes(b"sample-file-content")
    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.tmp.cleanup()
    def setUp(self):
        self.server.fields = {"key": "fixture.hap", "policy": "opaque+/==",
            "OSSAccessKeyId": "fixture-id", "Signature": "case-sensitive-signature",
            "callback": "callback+/==", "future-field": "@literal;unchanged"}
        self.server.upload_status = 200
        self.server.build_code = 0
        self.server.uploads, self.server.protocols, self.server.polls = [], [], 0
    def run_client(self, language):
        if language == "shell":
            command = ["bash", "-c",
                'source "$1"; file="$2"; api_key=fixture; buildType=hap; API_BASE_URL="$3/apiv2"; WEB_DOMAIN=example.invalid; LOG_ENABLE=0; getUploadToken; uploadFile; checkResult',
                "--", str(ROOT / "shell-demo/pgyer_upload.sh"), str(self.file), self.server.base]
        else:
            executable = {"php": "php", "node": "node", "python": sys.executable}[language]
            suffix = {"php": "php", "node": "js", "python": "py"}[language]
            command = [executable, str(ROOT / ("tests/run_" + language + "." + suffix)), self.server.base, str(self.file)]
        return subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=20)
    def assert_upload(self):
        self.assertEqual(["2"], self.server.protocols)
        self.assertEqual(1, len(self.server.uploads))
        fields = self.server.uploads[0]
        self.assertEqual("file", fields[-1][0])
        self.assertEqual(b"sample-file-content", fields[-1][1])
        self.assertEqual(self.server.fields, dict(fields[:-1]))
        self.assertGreater(self.server.polls, 0)
    def test_all_clients_oss_form(self):
        for language in ("shell", "php", "python", "node"):
            with self.subTest(language=language):
                self.setUp()
                result = self.run_client(language)
                self.assertEqual(0, result.returncode, result.stderr.decode())
                self.assert_upload()
    def test_cos_204_and_lost_callback(self):
        for language in ("shell", "php", "python", "node"):
            for status in (204, 203, 503):
                with self.subTest(language=language, status=status):
                    self.setUp()
                    self.server.upload_status = status
                    if status == 204:
                        self.server.fields = {"key": "fixture.hap", "signature": "cos", "x-cos-security-token": "cos-token"}
                    result = self.run_client(language)
                    self.assertEqual(0, result.returncode, result.stderr.decode())
                    self.assert_upload()
    def test_terminal_failure_is_not_reported_as_success(self):
        for language in ("shell", "php", "python", "node"):
            with self.subTest(language=language):
                self.setUp()
                self.server.build_code = 1216
                result = self.run_client(language)
                self.assertNotEqual(0, result.returncode)
                self.assertEqual(1, self.server.polls)

if __name__ == "__main__":
    unittest.main()
