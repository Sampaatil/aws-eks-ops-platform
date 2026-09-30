const { Pool } = require("pg");
const config = require("../config/config");

const pool = new Pool({
  host: config.database.host,
  port: config.database.port,
  database: config.database.database,
  user: config.database.user,
  password: config.database.password,

  max: 10,

  idleTimeoutMillis: 30000,

  connectionTimeoutMillis: 5000,
});

pool.on("error", (error) => {
  console.error("Unexpected PostgreSQL pool error:", error);
});

module.exports = pool;