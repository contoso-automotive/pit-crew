// A repair order on the Pit Crew bay board. Synthetic data only.
export type BayStatus = "checked-in" | "in-bay" | "waiting-parts" | "done";

export interface RepairOrder {
  id: string; // for example RO-1042
  vin: string; // synthetic VIN that fails the real check digit
  status: BayStatus;
  technician: string;
}
