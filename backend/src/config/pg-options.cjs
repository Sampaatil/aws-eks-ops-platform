"use strict";
const fs = require("node:fs");
function buildPgOptions(env = process.env) {
  const tls = env.DB_SSL === "true";
  if (env.DB_SSL && !["true", "false"].includes(env.DB_SSL)) {
    throw new Error("DB_SSL must be true or false");
  }
  if (env.DB_HOST && env.DB_HOST.endsWith(".rds.amazonaws.com") && !tls) {
    throw new Error("RDS connections require DB_SSL=true");
  }
  if (tls && !env.DB_SSL_CA_PATH) throw new Error("DB_SSL_CA_PATH is required for verified TLS");
  return {
    host: env.DB_HOST,
    port: Number(env.DB_PORT || 5432),
    database: env.DB_NAME,
    user: env.DB_USER,
    password: env.DB_PASSWORD,
    max: 5,
    connectionTimeoutMillis: 5000,
    idleTimeoutMillis: 30000,
    ssl: tls ? { ca: fs.readFileSync(env.DB_SSL_CA_PATH, "utf8"), rejectUnauthorized: true } : false
  };
}
module.exports = { buildPgOptions };
