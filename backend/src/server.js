const app = require("./app");
const config = require("./config/config");
const pool = require("./db/pool");

const server = app.listen(config.port, "0.0.0.0", () => {
  console.log(
    `OpsFlow API listening on port ${config.port}`
  );
});

async function shutdown(signal) {
  console.log(`${signal} received. Starting graceful shutdown.`);

  server.close(async () => {
    console.log("HTTP server closed.");

    try {
      await pool.end();

      console.log("Database pool closed.");

      process.exit(0);
    } catch (error) {
      console.error(
        "Error during graceful shutdown:",
        error
      );

      process.exit(1);
    }
  });

  setTimeout(() => {
    console.error(
      "Graceful shutdown timed out. Forcing exit."
    );

    process.exit(1);
  }, 10000).unref();
}

process.on("SIGTERM", () => shutdown("SIGTERM"));

process.on("SIGINT", () => shutdown("SIGINT"));