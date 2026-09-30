const pool = require("../db/pool");

async function getIncidents(req, res, next) {
  try {
    const result = await pool.query(
      `
      SELECT
        id,
        title,
        description,
        severity,
        status,
        service,
        created_at,
        updated_at
      FROM incidents
      ORDER BY created_at DESC
      `
    );

    res.status(200).json({
      count: result.rowCount,
      incidents: result.rows,
    });
  } catch (error) {
    next(error);
  }
}

async function getIncidentById(req, res, next) {
  try {
    const { id } = req.params;

    const result = await pool.query(
      `
      SELECT *
      FROM incidents
      WHERE id = $1
      `,
      [id]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({
        error: "Incident not found",
      });
    }

    return res.status(200).json(result.rows[0]);
  } catch (error) {
    return next(error);
  }
}

async function createIncident(req, res, next) {
  try {
    const {
      title,
      description = "",
      severity,
      service,
    } = req.body;

    if (!title || !severity || !service) {
      return res.status(400).json({
        error:
          "title, severity and service are required",
      });
    }

    const validSeverities = [
      "low",
      "medium",
      "high",
      "critical",
    ];

    if (!validSeverities.includes(severity)) {
      return res.status(400).json({
        error: "Invalid severity",
      });
    }

    const result = await pool.query(
      `
      INSERT INTO incidents
        (title, description, severity, service)
      VALUES
        ($1, $2, $3, $4)
      RETURNING *
      `,
      [
        title,
        description,
        severity,
        service,
      ]
    );

    return res.status(201).json(result.rows[0]);
  } catch (error) {
    return next(error);
  }
}

async function updateIncidentStatus(req, res, next) {
  try {
    const { id } = req.params;
    const { status } = req.body;

    const validStatuses = [
      "open",
      "investigating",
      "resolved",
    ];

    if (!validStatuses.includes(status)) {
      return res.status(400).json({
        error: "Invalid status",
      });
    }

    const result = await pool.query(
      `
      UPDATE incidents
      SET
        status = $1,
        updated_at = NOW()
      WHERE id = $2
      RETURNING *
      `,
      [status, id]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({
        error: "Incident not found",
      });
    }

    return res.status(200).json(result.rows[0]);
  } catch (error) {
    return next(error);
  }
}

async function deleteIncident(req, res, next) {
  try {
    const { id } = req.params;

    const result = await pool.query(
      `
      DELETE FROM incidents
      WHERE id = $1
      RETURNING id
      `,
      [id]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({
        error: "Incident not found",
      });
    }

    return res.status(204).send();
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  getIncidents,
  getIncidentById,
  createIncident,
  updateIncidentStatus,
  deleteIncident,
};