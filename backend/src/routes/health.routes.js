const express = require("express");

const router = express.Router();

router.get("/health", (req, res) => {
  res.status(200).json({
    status: "healthy",
    service: "opsflow-api",
    version: "1.1.1",
    timestamp: new Date().toISOString(),
  });
});

module.exports = router;