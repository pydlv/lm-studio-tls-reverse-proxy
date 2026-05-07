const domain = Bun.env.DOMAIN;

if (!domain) {
  console.error("Missing DOMAIN. Example:");
  console.error("  $env:DOMAIN = 'proxy.example.com'    # PowerShell");
  console.error("  export DOMAIN=proxy.example.com      # bash/zsh");
  process.exit(1);
}

Bun.env.TLS_CERT ??= `certs/public/${domain}.fullchain.pem`;
Bun.env.TLS_KEY ??= `certs/public/${domain}.key`;

await import("../src/server.js");
