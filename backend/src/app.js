const express = require("express");
const cors = require("cors");
const helmet = require("helmet");

const config = require("./config/config");

const healthRoutes = require("./routes/health.routes");
const readinessRoutes = require("./routes/readiness.routes");
const incidentRoutes = require("./routes/incidents.routes");

const notFound = require("./middleware/notFound");
const errorHandler = require("./middleware/errorHandler");

const app = express();

app.disable("x-powered-by");

app.use(helmet());

app.use(
  cors({
    origin: config.corsOrigin,
  })
);

app.use(express.json({ limit: "1mb" }));

app.get("/", (req, res) => {
  res.status(200).json({
    service: "OpsFlow API",
    version: "1.0.0",
  });
});

app.use(healthRoutes);

app.use(readinessRoutes);

app.use("/api/incidents", incidentRoutes);

app.use(notFound);

app.use(errorHandler);

module.exports = app;