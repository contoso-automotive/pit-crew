// GET /recalls/{vin}: the recalls on file for one vehicle.
import { Router } from "express";
import { isWellFormedVin, normalizeVin } from "../vin/vin.js";
import { findVehicle, recallsForVin } from "./lookup.js";

export const recallsRouter = Router();

recallsRouter.get("/:vin", (req, res) => {
  const vin = normalizeVin(req.params.vin);
  if (!isWellFormedVin(vin)) {
    res.status(400).json({ error: "A VIN is 17 letters and digits, without I, O or Q." });
    return;
  }

  const vehicle = findVehicle(vin);
  const recalls = recallsForVin(vin);
  if (!vehicle && recalls.length === 0) {
    res.status(404).json({ error: "No vehicle or recall information for this VIN." });
    return;
  }

  res.json({
    vin: vehicle?.vin ?? vin,
    recalls: recalls.map((r) => ({ id: r.id, component: r.component, status: r.status })),
  });
});
