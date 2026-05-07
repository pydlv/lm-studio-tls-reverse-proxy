#!/usr/bin/env bash
set -euo pipefail

CERT_DIR="${CERT_DIR:-certs}"
CERT_NAME="${CERT_NAME:-local-proxy}"
CA_NAME="${CA_NAME:-local-proxy-ca}"
HOST_IP="${HOST_IP:-}"
HOST_DNS="${HOST_DNS:-localhost}"
SAN_LIST="DNS:$HOST_DNS,IP:127.0.0.1"

if [[ -n "$HOST_IP" ]]; then
  SAN_LIST="$SAN_LIST,IP:$HOST_IP"
fi

mkdir -p "$CERT_DIR"

if [[ ! -f "$CERT_DIR/$CA_NAME.key" || ! -f "$CERT_DIR/$CA_NAME.crt" ]]; then
  openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
    -keyout "$CERT_DIR/$CA_NAME.key" \
    -out "$CERT_DIR/$CA_NAME.crt" \
    -subj "/CN=Local Proxy Development CA" \
    -addext "basicConstraints=critical,CA:TRUE,pathlen:0" \
    -addext "keyUsage=critical,keyCertSign,cRLSign" \
    -addext "subjectKeyIdentifier=hash"
fi

openssl req -newkey rsa:2048 -nodes \
  -keyout "$CERT_DIR/$CERT_NAME.key" \
  -out "$CERT_DIR/$CERT_NAME.csr" \
  -subj "/CN=$HOST_DNS" \
  -addext "subjectAltName=$SAN_LIST"

openssl x509 -req -sha256 -days 825 \
  -in "$CERT_DIR/$CERT_NAME.csr" \
  -CA "$CERT_DIR/$CA_NAME.crt" \
  -CAkey "$CERT_DIR/$CA_NAME.key" \
  -CAcreateserial \
  -out "$CERT_DIR/$CERT_NAME.crt" \
  -copy_extensions copy

rm -f "$CERT_DIR/$CERT_NAME.csr"

echo "Created $CERT_DIR/$CERT_NAME.crt and $CERT_DIR/$CERT_NAME.key"
echo "Trust $CERT_DIR/$CA_NAME.crt on client devices, not the server cert."
