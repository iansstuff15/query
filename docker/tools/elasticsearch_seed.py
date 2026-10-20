"""Creates indices, roles/users and bulk-loads documents into Elasticsearch."""
import base64
import json
import sys
import urllib.request

url, user, password, folder = sys.argv[1:5]
auth = "Basic " + base64.b64encode(f"{user}:{password}".encode()).decode()


def call(method, path, body=None, content_type="application/json"):
    data = body if isinstance(body, bytes) or body is None else json.dumps(body).encode()
    request = urllib.request.Request(url + path, data=data, method=method,
                                     headers={"Authorization": auth, "Content-Type": content_type})
    return json.load(urllib.request.urlopen(request))


for index, mapping in json.load(open(f"{folder}/mappings.json")).items():
    call("PUT", f"/{index}", {"mappings": mapping})
security = json.load(open(f"{folder}/security.json"))
call("PUT", "/_security/role/query_read", security["role"])
write_role = {"indices": [{"names": ["customers", "products", "orders"], "privileges": ["write", "create_index"]}]}
call("PUT", "/_security/role/query_write", write_role)
for name, spec in security["users"].items():
    call("PUT", f"/_security/user/{name}", spec)
bulk = open(f"{folder}/seed.ndjson", "rb").read() + b"\n"
result = call("POST", "/_bulk?refresh=true", bulk, "application/x-ndjson")
print("bulk errors:", result["errors"], "items:", len(result["items"]))
sys.exit(1 if result["errors"] else 0)
