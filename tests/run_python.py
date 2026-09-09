import pathlib
import sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "python-demo"))
from utils import upload_pgyer as client
import requests
base, filename = sys.argv[1:3]
client._check_connectivity = lambda: None
client._api_post = lambda path, data=None, timeout=30: requests.post(base + path, data=data, timeout=timeout)
client._api_get = lambda path, params=None, timeout=30: requests.get(base + path, params=params, timeout=timeout)
result = client.upload_to_pgyer(filename, "fixture")
sys.exit(0 if result else 1)
