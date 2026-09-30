const express = require("express");
const pool = require("../db/pool");

const router = express.Router();

router.get("/ready", async (req, res) => {
  try {
    await pool.query("SELECT 1");

    res.status(200).json({
      status: "ready",
      database: "connected",
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    res.status(503).json({
      status: "not_ready",
      database: "unavailable",
      timestamp: new Date().toISOString(),
    });
  }
});

module.exports = router;