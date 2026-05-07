# Bun HTTPS Reverse Proxy

A small Bun reverse proxy that terminates HTTPS on a LAN-facing address and forwards requests to a local HTTP service.

By default it forwards to:

```text
http://127.0.0.1:1234
```

## Requirements

- [Bun](https://bun.sh/)
- `openssl`, for local development certificates
- Optional: `acme.sh`, for public Let's Encrypt certificates via Cloudflare DNS-01

## Quick Start

Create a local development certificate:

```bash
HOST_IP=192.168.1.10 bun run cert
```

Start the proxy:

```bash
bun run start
```

Open it from another device on the LAN:

```text
https://192.168.1.10:8443
```

The local certificate authority created by `bun run cert` must be trusted by client devices before browsers or apps accept the certificate.

## Configuration

Runtime configuration is provided with environment variables:

```bash
TARGET_URL=http://127.0.0.1:1234
HOST=0.0.0.0
PORT=8443
IDLE_TIMEOUT=0
TLS_CERT=./certs/local-proxy.crt
TLS_KEY=./certs/local-proxy.key
```

Example:

```bash
TARGET_URL=http://127.0.0.1:1234 PORT=9443 bun run start
```

## Public Certificate With Cloudflare

Some Android apps do not trust user-installed certificate authorities. For those clients, use a real hostname and a publicly trusted certificate.

Create a DNS-only `A` record for a hostname you control:

```text
proxy.example.com -> 192.168.1.10
```

In Cloudflare, create an API token scoped to the zone with:

```text
Zone > DNS > Edit
Zone > Zone > Read
```

Export your settings:

```bash
export DOMAIN=proxy.example.com
export ZONE_NAME=example.com
export RECORD_IP=192.168.1.10
export CF_Token='<cloudflare-api-token>'
export CF_Zone_ID='<cloudflare-zone-id>'
```

Create or update the DNS record:

```bash
bun run dns:cloudflare
```

Install `acme.sh` if needed:

```bash
curl https://get.acme.sh | sh -s email=you@example.com
```

Issue the Let's Encrypt certificate:

```bash
bun run cert:public
```

Start the proxy with the public certificate:

```bash
bun run start:public
```

On PowerShell, set the domain first:

```powershell
$env:DOMAIN = "proxy.example.com"
bun run start:public
```

On bash/zsh:

```bash
export DOMAIN=proxy.example.com
bun run start:public
```

Connect clients to the hostname, not the IP address:

```text
https://proxy.example.com:8443
```

## Local CA Details

`bun run cert` creates:

```text
certs/local-proxy.crt
certs/local-proxy.key
certs/local-proxy-ca.crt
certs/local-proxy-ca.key
```

Trust `certs/local-proxy-ca.crt` on client devices. Do not distribute or commit `certs/local-proxy-ca.key`.

## Security Notes

- `certs/`, `.env`, and `.env.*` are ignored by Git.
- Keep Cloudflare API tokens in your shell or secret manager, not in the repository.
- Public certificates validate hostnames, not private LAN IP addresses. Clients must connect to the hostname listed in the certificate.
- If the proxy runs on the same host as the upstream service, use `TARGET_URL=http://127.0.0.1:1234` so the unencrypted backend hop stays on loopback.
- `IDLE_TIMEOUT=0` disables Bun's per-request idle timeout, which is useful for long-lived LLM/SSE streaming responses.
