'use strict';
const path = require('node:path');
console.log('Database configuration', {
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  tlsRequested: process.env.DB_SSL === 'true',
  caPath: process.env.DB_SSL_CA_PATH,
  passwordPresent: Boolean(process.env.DB_PASSWORD)
});
let pool;
(async () => {
  try {
    pool = require(path.resolve(process.env.OPS_POOL_MODULE || 'src/db/pool.js'));
    const result = await pool.query("SELECT current_database() AS database, current_user AS db_user, (SELECT ssl FROM pg_stat_ssl WHERE pid=pg_backend_pid()) AS tls, to_regclass('public.incidents') IS NOT NULL AS incidents_table");
    console.log('Database verification', result.rows[0]);
    if (!result.rows[0].tls || !result.rows[0].incidents_table) process.exitCode = 1;
  } catch (error) {
    console.error('Database diagnostic failed', {code: error.code || 'DB_DIAGNOSTIC_ERROR', message: error.message});
    process.exitCode = 1;
  } finally {
    if (pool) await pool.end();
  }
})();
