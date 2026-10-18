import { Readable } from "node:stream";
import apiHandler from "../../api/index.mjs";

/**
 * Netlify's web Request handler adapter for the existing Node-style API.
 * API request bodies are small JSON only; video bytes go directly from the
 * browser to Supabase Storage using a time-limited signed upload URL.
 */
export default async function forceaimApi(request) {
  const bytes = Buffer.from(await request.arrayBuffer());
  const nodeRequest = Readable.from(bytes.length ? [bytes] : []);
  const requestUrl = new URL(request.url);
  const functionPrefix = "/.netlify/functions/forceaim-api";
  const routePath = requestUrl.pathname.startsWith(functionPrefix)
    ? requestUrl.pathname.slice(functionPrefix.length) || "/"
    : requestUrl.pathname;
  nodeRequest.method = request.method;
  nodeRequest.url = `${routePath}${requestUrl.search}`;
  nodeRequest.headers = Object.fromEntries(request.headers.entries());

  let statusCode = 200;
  let responseHeaders = {};
  const responseChunks = [];
  let headersSent = false;
  const nodeResponse = {
    get headersSent() { return headersSent; },
    writeHead(status, headers = {}) {
      statusCode = status;
      responseHeaders = headers;
      headersSent = true;
      return this;
    },
    end(chunk) {
      if (chunk !== undefined && chunk !== null) {
        responseChunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(String(chunk)));
      }
      return this;
    },
  };

  try {
    await apiHandler(nodeRequest, nodeResponse);
  } catch {
    if (!headersSent) {
      statusCode = 500;
      responseHeaders = { "content-type": "text/plain; charset=utf-8" };
    }
    responseChunks.length = 0;
    responseChunks.push(Buffer.from("Request could not be completed"));
  }

  return new Response(Buffer.concat(responseChunks), {
    status: statusCode,
    headers: responseHeaders,
  });
}
