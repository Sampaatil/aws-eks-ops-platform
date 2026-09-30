require("dotenv").config();

const config = {
  env: process.env.NODE_ENV || "development",

  port: Number(process.env.PORT) || 3000,

  corsOrigin:
    process.env.CORS_ORIGIN || "http://localhost:5173",

  database: {
    host: process.env.DB_HOST || "localhost",
    port: Number(process.env.DB_PORT) || 5432,
    database: process.env.DB_NAME || "opsflow",
    user: process.env.DB_USER || "opsflow",
    password: process.env.DB_PASSWORD || "",
  },
};

module.exports = config;