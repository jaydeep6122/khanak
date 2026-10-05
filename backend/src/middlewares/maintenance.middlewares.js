// Read on every request so maintenance is switched by changing the
// environment, without a new release of the API.
export const underMaintenance = () => process.env.MAINTENANCE_MODE === "true";

/**
 * Refuses every request while maintenance is on. The app recognises the
 * `code` and shows its maintenance screen, wherever the person was.
 */
export const maintenanceGate = (req, res, next) => {
  if (!underMaintenance()) return next();
  res.status(503).json({
    success: false,
    statusCode: 503,
    code: "maintenance",
    message: "Khanak is under maintenance. Please try again shortly.",
  });
};
