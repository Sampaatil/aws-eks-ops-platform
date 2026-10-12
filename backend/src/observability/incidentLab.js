// Narrow, bounded text-format counters; no per-request/user/path-derived labels.
const http = require("node:http");
const { randomUUID } = require("node:crypto");

function createIncidentLab({ now = Date.now, log = console.log } = {}) {
  const responses = new Map();
  let errors = 0;
  let run = null;
  const pod = process.env.HOSTNAME || "local";
  function count(source, status) {
    const code = Number.isInteger(status) && status >= 100 && status <= 599 ? status : 500;
    const key = `${source}:${code}`;
    responses.set(key, (responses.get(key) || 0) + 1);
  }
  responses.set("incident_lab:500", 0);
  responses.set("production:500", 0);
  function active() {
    if (run && (now() >= run.expiresAt || run.remaining === 0)) run = null;
    return run;
  }
  function status() {
    const current = active();
    return current ? { pod, armed: true, runId: current.id, remaining: current.remaining,
      expiresAt: new Date(current.expiresAt).toISOString() } : { pod, armed: false };
  }
  function handler(req, res) {
    res.setHeader("Content-Type", "application/json");
    res.setHeader("Cache-Control", "no-store");
    const reply = (code, body) => { res.writeHead(code); res.end(JSON.stringify(body)); };
    if (req.headers.origin) return reply(403, { error: "Browser-origin control requests are not accepted" });
    if (req.url === "/status" && req.method === "GET") return reply(200, status());
    if (req.url === "/arm" && req.method === "POST") {
      if (active()) return reply(409, { error: "Already armed; finish or disarm this run" });
      run = { id: randomUUID(), expiresAt: now() + 120000, remaining: 5 };
      return reply(200, status());
    }
    if (req.url === "/disarm" && req.method === "POST") {
      run = null;
      return reply(200, { armed: false });
    }
    if (req.url === "/error" && req.method === "GET") {
      const current = active();
      if (!current || req.headers["x-opsflow-lab-run"] !== current.id) {
        return reply(404, { error: "Lab disabled or run identifier mismatch" });
      }
      const requestId = randomUUID();
      current.remaining -= 1;
      errors += 1;
      count("incident_lab", 500);
      log(JSON.stringify({ timestamp: new Date(now()).toISOString(), level: "ERROR",
        event: "opsflow_incident_lab_error", synthetic: true, runId: current.id,
        requestId, status: 500, pod,
        message: "Controlled Phase 13 synthetic HTTP error; no database operation" }));
      return reply(500, { error: "Synthetic incident lab error", synthetic: true,
        runId: current.id, requestId });
    }
    return reply(404, { error: "Not found" });
  }
  function exposition() {
    const lines = ["# HELP opsflow_incident_lab_errors_total Controlled synthetic errors since process start.",
      "# TYPE opsflow_incident_lab_errors_total counter", `opsflow_incident_lab_errors_total ${errors}`,
      "# HELP opsflow_http_responses_total Completed responses, separated from synthetic lab errors.",
      "# TYPE opsflow_http_responses_total counter"];
    for (const [key, value] of responses) {
      const [source, code] = key.split(":");
      lines.push(`opsflow_http_responses_total{source="${source}",status="${code}"} ${value}`);
    }
    return lines.join("\n") + "\n";
  }
  function middleware(req, res, next) {
    if (req.path !== "/metrics") res.once("finish", () => count("production", res.statusCode));
    next();
  }
  function metrics(_req, res) {
    res.setHeader("Content-Type", "text/plain; version=0.0.4; charset=utf-8");
    res.setHeader("Cache-Control", "no-store");
    res.status(200).send(exposition());
  }
  function listen() {
    const server = http.createServer(handler);
    server.requestTimeout = 5000;
    server.headersTimeout = 5000;
    server.keepAliveTimeout = 1000;
    server.maxHeadersCount = 32;
    server.on("error", () => {
      // Lab failure must not crash the real API or print potentially sensitive error text.
      log(JSON.stringify({ level: "WARN", event: "opsflow_incident_lab_listener_unavailable" }));
    });
    server.listen(3001, "127.0.0.1");
    return server;
  }
  return { middleware, metrics, handler, exposition, listen };
}
const incidentLab = createIncidentLab();
module.exports = { createIncidentLab, incidentLab };
