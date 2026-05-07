const target = new URL(Bun.env.TARGET_URL ?? "http://127.0.0.1:1234");
const hostname = Bun.env.HOST ?? "0.0.0.0";
const port = Number(Bun.env.PORT ?? "8443");
const idleTimeout = Number(Bun.env.IDLE_TIMEOUT ?? "0");
const certFile = Bun.env.TLS_CERT ?? "./certs/local-proxy.crt";
const keyFile = Bun.env.TLS_KEY ?? "./certs/local-proxy.key";

const hopByHopHeaders = new Set([
  "connection",
  "keep-alive",
  "proxy-authenticate",
  "proxy-authorization",
  "te",
  "trailer",
  "transfer-encoding",
  "upgrade"
]);

function copyProxyHeaders(headers) {
  const next = new Headers();

  for (const [name, value] of headers) {
    if (!hopByHopHeaders.has(name.toLowerCase())) {
      next.set(name, value);
    }
  }

  return next;
}

function targetUrlFor(request) {
  const incoming = new URL(request.url);
  const next = new URL(target);

  next.pathname = joinPaths(target.pathname, incoming.pathname);
  next.search = incoming.search;

  return next;
}

function joinPaths(basePath, requestPath) {
  const base = basePath.endsWith("/") ? basePath.slice(0, -1) : basePath;
  const request = requestPath.startsWith("/") ? requestPath : `/${requestPath}`;

  if (!base || base === "/") {
    return request;
  }

  return `${base}${request}`;
}

const server = Bun.serve({
  hostname,
  port,
  tls: {
    cert: Bun.file(certFile),
    key: Bun.file(keyFile)
  },
  async fetch(request, server) {
    server.timeout(request, idleTimeout);

    const destination = targetUrlFor(request);
    const headers = copyProxyHeaders(request.headers);
    const abortController = new AbortController();

    if (request.signal.aborted) {
      abortController.abort(request.signal.reason);
    } else {
      request.signal.addEventListener(
        "abort",
        () => abortController.abort(request.signal.reason),
        { once: true }
      );
    }

    headers.set("host", target.host);
    headers.set("x-forwarded-host", request.headers.get("host") ?? "");
    headers.set("x-forwarded-proto", "https");
    headers.set("x-forwarded-for", server.requestIP(request)?.address ?? "");

    try {
      const response = await fetch(destination, {
        method: request.method,
        headers,
        body: request.method === "GET" || request.method === "HEAD" ? undefined : request.body,
        redirect: "manual",
        signal: abortController.signal
      });

      return new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers: copyProxyHeaders(response.headers)
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : "Unknown proxy error";

      return new Response(`Proxy error: ${message}\n`, {
        status: 502,
        headers: {
          "content-type": "text/plain; charset=utf-8"
        }
      });
    }
  }
});

console.log(`HTTPS reverse proxy listening on https://${hostname}:${server.port}`);
console.log(`Forwarding requests to ${target.href}`);
