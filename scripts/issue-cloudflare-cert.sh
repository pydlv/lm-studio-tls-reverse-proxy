#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${DOMAIN:-}"
CERT_DIR="${CERT_DIR:-certs/public}"
ACME_SH="${ACME_SH:-$HOME/.acme.sh/acme.sh}"
ACME_EMAIL="${ACME_EMAIL:-}"

if [[ -z "$DOMAIN" ]]; then
  echo "Missing DOMAIN. Example: export DOMAIN=proxy.example.com" >&2
  exit 1
fi

if [[ ! -x "$ACME_SH" ]]; then
  echo "acme.sh was not found at $ACME_SH" >&2
  echo "Install it first: curl https://get.acme.sh | sh -s email=you@example.com" >&2
  exit 1
fi

if [[ -z "${CF_Token:-}" ]]; then
  echo "Missing CF_Token. Export your Cloudflare API token before running this." >&2
  exit 1
fi

if [[ -z "${CF_Zone_ID:-}" && -z "${CF_Account_ID:-}" ]]; then
  echo "Missing CF_Zone_ID or CF_Account_ID. Export at least one before running this." >&2
  exit 1
fi

mkdir -p "$CERT_DIR"

if [[ -n "$ACME_EMAIL" ]]; then
  "$ACME_SH" --register-account -m "$ACME_EMAIL" --server letsencrypt
fi

"$ACME_SH" --set-default-ca --server letsencrypt
"$ACME_SH" --issue --dns dns_cf -d "$DOMAIN" --server letsencrypt "$@"
"$ACME_SH" --install-cert -d "$DOMAIN" \
  --key-file "$CERT_DIR/$DOMAIN.key" \
  --fullchain-file "$CERT_DIR/$DOMAIN.fullchain.pem"

echo "Installed certificate:"
echo "  TLS_CERT=$CERT_DIR/$DOMAIN.fullchain.pem"
echo "  TLS_KEY=$CERT_DIR/$DOMAIN.key"
