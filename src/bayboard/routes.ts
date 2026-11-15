// The bay board: every open repair order as a card, in check-in order.
import { readFile } from "node:fs/promises";
import { Router } from "express";
import { escapeHtml, page } from "../views/layout.js";
import { cardLines } from "./card.js";
import type { RepairOrder } from "./repairOrder.js";

// Loaded once at startup, like the vehicle and recall data, so handlers never read files.
const { repairOrders } = JSON.parse(
  await readFile(new URL("../../data/repair-orders.synthetic.json", import.meta.url), "utf8"),
) as { repairOrders: RepairOrder[] };

export const bayboardRouter = Router();

bayboardRouter.get("/", (_req, res) => {
  const cards = repairOrders
    .map((order) => `<li class="card">${cardLines(order).map((line) => `<p>${escapeHtml(line)}</p>`).join("")}</li>`)
    .join("\n");
  res.send(page("Bay board", `<ul class="board" aria-label="Repair orders">${cards}</ul>`));
});
