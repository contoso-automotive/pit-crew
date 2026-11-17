// The check-in bay: a service advisor enters a VIN and Pit Crew shows the car.
import { Router } from "express";
import { escapeHtml, page } from "../views/layout.js";
import { isWellFormedVin, normalizeVin } from "../vin/vin.js";
import { getVehicle } from "../recalls/lookup.js";

export const checkinRouter = Router();

const form = (value = "") => `
<form action="/checkin" method="get" class="checkin">
  <label for="vin">VIN</label>
  <input id="vin" name="vin" value="${escapeHtml(value)}" maxlength="17" autocomplete="off" required>
  <button type="submit">Check in</button>
</form>`;

checkinRouter.get("/", (_req, res) => {
  res.send(page("Check-in bay", form()));
});

checkinRouter.get("/checkin", (req, res) => {
  const raw = typeof req.query.vin === "string" ? req.query.vin : "";
  const vin = normalizeVin(raw);
  if (!isWellFormedVin(vin)) {
    res.status(400).send(page("Check-in bay", `<p class="status status-warn">Check the VIN: 17 letters and digits, without I, O or Q.</p>${form(raw)}`));
    return;
  }

  const vehicle = getVehicle(vin);
  if (!vehicle) {
    res.status(404).send(page("Vehicle not found", `<p class="status status-warn">No vehicle found for this VIN.</p>${form(vin)}`));
    return;
  }

  res.send(page("Check-in bay", `
${form(vin)}
<section class="card" aria-label="Vehicle">
  <p class="label">Vehicle</p>
  <p class="value">${escapeHtml(vehicle.modelYear)} ${escapeHtml(vehicle.model)}</p>
  <p>VIN ${escapeHtml(vehicle.vin)}</p>
  <p>Maker: ${escapeHtml(vehicle.maker)}</p>
</section>`));
});
