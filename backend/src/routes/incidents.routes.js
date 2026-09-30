const express = require("express");

const {
  getIncidents,
  getIncidentById,
  createIncident,
  updateIncidentStatus,
  deleteIncident,
} = require("../controllers/incidents.controller");

const router = express.Router();

router.get("/", getIncidents);

router.get("/:id", getIncidentById);

router.post("/", createIncident);

router.patch("/:id/status", updateIncidentStatus);

router.delete("/:id", deleteIncident);

module.exports = router;