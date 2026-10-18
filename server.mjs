import { createReadStream, statSync } from "node:fs";
import { createServer } from "node:http";
import { extname, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";
import handler from "./api/index.mjs";

const projectRoot = resolve(fileURLToPath(new URL(".", import.meta.url)));
const root = resolve(projectRoot, process.env.SITE_DIR || ".");
const port = Number(process.env.PORT || 4174);
const types = {
  ".css": "text/css; charset=utf-8",
  ".html": "text/html; charset=utf-8",
  ".ico": "image/x-icon",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml",
  ".txt": "text/plain; charset=utf-8",
  ".xml": "application/xml; charset=utf-8"
};

createServer(async (request, response) => {
  let route;
  try { route = new URL(request.url || "/", "http://localhost").pathname; }
  catch { response.writeHead(400).end("Bad request"); return; }
  if (route.startsWith("/api/") || /^\/(admin|portal|login|invite|reset)(\/|$)/.test(route)) {
    try { await handler(request, response); }
    catch { if (!response.headersSent) response.writeHead(500, { "Content-Type": "text/plain; charset=utf-8" }); response.end("Request could not be completed"); }
    return;
  }
  if (!["GET", "HEAD"].includes(request.method || "GET")) {
    response.writeHead(405, { Allow: "GET, HEAD" }).end("Method not allowed");
    return;
  }

  let pathname;
  try {
    pathname = decodeURIComponent(new URL(request.url || "/", "http://localhost").pathname);
  } catch {
    response.writeHead(400).end("Bad request");
    return;
  }
  if (pathname === "/favicon.ico") pathname = "/favicon.svg";

  const requested = resolve(root, `.${pathname === "/" ? "/index.html" : pathname}`);
  if (requested !== root && !requested.startsWith(root + sep)) {
    response.writeHead(403).end("Forbidden");
    return;
  }

  try {
    if (!statSync(requested).isFile()) throw new Error("Not a file");
  } catch {
    response.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" }).end("Not found");
    return;
  }

  response.writeHead(200, {
    "Content-Type": types[extname(requested).toLowerCase()] || "application/octet-stream",
    "X-Content-Type-Options": "nosniff",
    "Cache-Control": "no-cache"
  });
  if (request.method === "HEAD") response.end();
  else createReadStream(requested).pipe(response);
}).listen(port, "127.0.0.1", () => {
  console.log(`ForceAim is running at http://127.0.0.1:${port}`);
});
