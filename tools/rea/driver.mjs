#!/usr/bin/env node
// Minimal long-lived REA MCP driver. Spawns `rea --mcp` once, keeps the Ghidra session
// open, and proxies tool calls over local HTTP so shell scripts can query without
// re-importing the binary each time.
//   node tools/rea/driver.mjs [port]
//   curl -s localhost:7331/tools
//   curl -s localhost:7331/call -d '{"name":"open_binary","arguments":{...}}'
import { spawn } from "node:child_process";
import http from "node:http";
import { createWriteStream } from "node:fs";

const port = Number(process.argv[2] ?? 7331);
const log = createWriteStream(process.env.REA_DRIVER_LOG ?? "rea-mcp.stderr.log", { flags: "a" });
const rea = spawn("rea", ["--mcp"], { stdio: ["pipe", "pipe", "pipe"], env: process.env });
rea.stderr.pipe(log);
rea.on("exit", (code) => { console.error(`rea --mcp exited ${code}`); process.exit(1); });

let nextId = 1;
const pending = new Map();
let buf = "";
rea.stdout.on("data", (chunk) => {
  buf += chunk.toString();
  let nl;
  while ((nl = buf.indexOf("\n")) >= 0) {
    const line = buf.slice(0, nl).trim(); buf = buf.slice(nl + 1);
    if (!line.startsWith("{")) continue;
    let msg; try { msg = JSON.parse(line); } catch { continue; }
    if (msg.id !== undefined && pending.has(msg.id)) { pending.get(msg.id)(msg); pending.delete(msg.id); }
  }
});
function send(method, params, timeoutMs) {
  const id = nextId++;
  return new Promise((resolve, reject) => {
    const t = setTimeout(() => { pending.delete(id); reject(new Error(`timeout after ${timeoutMs}ms`)); }, timeoutMs);
    pending.set(id, (m) => { clearTimeout(t); resolve(m); });
    rea.stdin.write(JSON.stringify({ jsonrpc: "2.0", id, method, params }) + "\n");
  });
}
function notify(method, params) { rea.stdin.write(JSON.stringify({ jsonrpc: "2.0", method, params }) + "\n"); }

const init = await send("initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "stoa-rea-driver", version: "0.1" } }, 60_000);
notify("notifications/initialized", {});
const tools = (await send("tools/list", {}, 60_000)).result.tools;
console.error(`rea ready: ${init.result?.serverInfo?.name ?? "?"} ${init.result?.serverInfo?.version ?? ""}, ${tools.length} tools`);

http.createServer(async (req, res) => {
  const body = await new Promise((r) => { let b = ""; req.on("data", (c) => (b += c)); req.on("end", () => r(b)); });
  res.setHeader("content-type", "application/json");
  try {
    if (req.method === "GET" && req.url === "/tools") return res.end(JSON.stringify(tools));
    if (req.method === "GET" && req.url?.startsWith("/tool/")) {
      const t = tools.find((x) => x.name === decodeURIComponent(req.url.slice(6)));
      return res.end(JSON.stringify(t ?? { error: "no such tool" }));
    }
    if (req.method === "POST" && req.url === "/call") {
      const { name, arguments: args = {}, timeoutMs = 7_200_000 } = JSON.parse(body || "{}");
      const m = await send("tools/call", { name, arguments: args }, timeoutMs);
      return res.end(JSON.stringify(m.error ? { error: m.error } : m.result));
    }
    res.statusCode = 404; res.end(JSON.stringify({ error: "use GET /tools, GET /tool/<name>, POST /call" }));
  } catch (e) { res.statusCode = 500; res.end(JSON.stringify({ error: String(e) })); }
}).listen(port, "127.0.0.1", () => console.error(`driver listening on http://127.0.0.1:${port}`));
