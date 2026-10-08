const { Pool } = require("pg");
const { buildPgOptions } = require("../config/pg-options.cjs");

const pool = new Pool(buildPgOptions(process.env));

pool.on("error", (error) => {
  console.error("Unexpected PostgreSQL pool error:", error);
});

module.exports = pool;