// Builds the text a bay board card shows. Status is always a word, never color alone.
import type { RepairOrder } from "./repairOrder.js";

export function cardLines(order: RepairOrder): string[] {
  return [order.id, order.vin, `Status: ${order.status}`, `Tech: ${order.technician}`];
}
