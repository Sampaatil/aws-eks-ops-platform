const http = require("node:http");
const request = require("supertest");
const { createIncidentLab } = require("../src/observability/incidentLab");

function fixture() {
  let time = Date.now();
  const messages = [];
  const lab = createIncidentLab({ now: () => time, log: (line) => messages.push(JSON.parse(line)) });
  return { lab, api: request(http.createServer(lab.handler)), messages,
    advance: () => { time += 120001; } };
}
test("defaults disabled and exports zero counter", async () => {
  const { api, lab } = fixture();
  await api.get("/error").expect(404);
  expect(lab.exposition()).toContain("opsflow_incident_lab_errors_total 0\n");
});
test("five synthetic errors, safe correlation, then automatic disarm", async () => {
  const { api, lab, messages } = fixture();
  await api.post("/arm").set("Origin", "https://untrusted.example").expect(403);
  const arm = await api.post("/arm").expect(200);
  expect(arm.body.pod).toBe(process.env.HOSTNAME || "local");
  await api.get("/error").set("X-OpsFlow-Lab-Run", "wrong").expect(404);
  await api.post("/arm").expect(409);
  for (let i = 0; i < 5; i++) {
    const error = await api.get("/error").set("X-OpsFlow-Lab-Run", arm.body.runId).expect(500);
    expect(error.body.requestId).toBe(messages[i].requestId);
    expect(messages[i].runId).toBe(arm.body.runId);
    expect(messages[i].synthetic).toBe(true);
  }
  await api.get("/error").set("X-OpsFlow-Lab-Run", arm.body.runId).expect(404);
  expect(messages).toHaveLength(5);
  expect(lab.exposition()).toContain("opsflow_incident_lab_errors_total 5\n");
  expect(lab.exposition()).toContain('source="production",status="500"} 0');
});
test("expired activation and explicit disarm reject errors", async () => {
  const { api, advance } = fixture();
  const arm = await api.post("/arm").expect(200);
  advance();
  await api.get("/error").set("X-OpsFlow-Lab-Run", arm.body.runId).expect(404);
  const second = await api.post("/arm").expect(200);
  await api.post("/disarm").expect(200);
  await api.get("/error").set("X-OpsFlow-Lab-Run", second.body.runId).expect(404);
});
test("lab endpoint is absent from public application routes; metrics are valid text", async () => {
  const app = require("../src/app");
  await request(app).get("/error").expect(404);
  await request(app).post("/arm").expect(404);
  const result = await request(app).get("/metrics").expect(200);
  expect(result.headers["content-type"]).toContain("text/plain");
  expect(result.text).toContain("# TYPE opsflow_incident_lab_errors_total counter");
});
test("lab listener binds only Pod loopback", async () => {
  const { lab } = fixture();
  const server = lab.listen();
  try {
    await new Promise((resolve, reject) => { server.once("listening", resolve); server.once("error", reject); });
    expect(server.address().address).toBe("127.0.0.1");
    expect(server.address().port).toBe(3001);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});
