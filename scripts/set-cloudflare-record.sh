#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${DOMAIN:-}"
ZONE_NAME="${ZONE_NAME:-}"
RECORD_IP="${RECORD_IP:-}"
CF_TOKEN="${CF_Token:-${CLOUDFLARE_API_TOKEN:-}}"
CF_API="https://api.cloudflare.com/client/v4"

if [[ -z "$DOMAIN" ]]; then
  echo "Missing DOMAIN. Example: export DOMAIN=proxy.example.com" >&2
  exit 1
fi

if [[ -z "$ZONE_NAME" ]]; then
  echo "Missing ZONE_NAME. Example: export ZONE_NAME=example.com" >&2
  exit 1
fi

if [[ -z "$RECORD_IP" ]]; then
  echo "Missing RECORD_IP. Example: export RECORD_IP=192.168.1.10" >&2
  exit 1
fi

if [[ -z "$CF_TOKEN" ]]; then
  echo "Missing CF_Token or CLOUDFLARE_API_TOKEN." >&2
  exit 1
fi

python3 - "$CF_API" "$CF_TOKEN" "$ZONE_NAME" "$DOMAIN" "$RECORD_IP" <<'PY'
import json
import sys
import urllib.error
import urllib.parse
import urllib.request

api, token, zone_name, domain, record_ip = sys.argv[1:]
headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json",
}

def request(method, path, body=None):
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(f"{api}{path}", data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as response:
            payload = json.loads(response.read().decode())
    except urllib.error.HTTPError as error:
        details = error.read().decode()
        raise SystemExit(f"Cloudflare API error {error.code}: {details}") from error

    if not payload.get("success"):
        raise SystemExit(f"Cloudflare API error: {json.dumps(payload, indent=2)}")

    return payload["result"]

zone_query = urllib.parse.urlencode({"name": zone_name})
zones = request("GET", f"/zones?{zone_query}")
if not zones:
    raise SystemExit(f"Zone not found: {zone_name}")

zone_id = zones[0]["id"]
record_query = urllib.parse.urlencode({"type": "A", "name": domain})
records = request("GET", f"/zones/{zone_id}/dns_records?{record_query}")

body = {
    "type": "A",
    "name": domain,
    "content": record_ip,
    "ttl": 300,
    "proxied": False,
}

if records:
    record_id = records[0]["id"]
    result = request("PUT", f"/zones/{zone_id}/dns_records/{record_id}", body)
    action = "Updated"
else:
    result = request("POST", f"/zones/{zone_id}/dns_records", body)
    action = "Created"

print(f"{action} DNS record: {result['name']} A {result['content']} DNS-only")
PY
