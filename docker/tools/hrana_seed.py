"""Runs a SQL file against a libSQL server through the Hrana-over-HTTP pipeline API."""
import json
import sys
import urllib.request

url, path = sys.argv[1], sys.argv[2]
source = "\n".join(line for line in open(path).read().splitlines() if not line.lstrip().startswith("--"))
statements = [s.strip() for s in source.split(";\n") if s.strip()]
body = {"requests": [{"type": "execute", "stmt": {"sql": s}} for s in statements] + [{"type": "close"}]}
request = urllib.request.Request(url + "/v2/pipeline", data=json.dumps(body).encode(), headers={"Content-Type": "application/json"})
results = json.load(urllib.request.urlopen(request))["results"]
errors = [r for r in results if r["type"] != "ok"]
print(f"executed {len(statements)} statements, {len(errors)} errors")
for error in errors:
    print(error)
sys.exit(1 if errors else 0)
