function errorHandler(error, req, res, _next) {
  console.error(error);

  res.status(500).json({
    error: "Internal server error",
  });
}

module.exports = errorHandler;