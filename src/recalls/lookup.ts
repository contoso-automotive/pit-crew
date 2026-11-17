// Pit Crew's data access for vehicles and recalls. Synthetic data only.
// The data loads once, when this module is first imported, so request handlers
// only read memory and never touch the file system.
import { readdir, readFile } from "node:fs/promises";

export interface Vehicle {
  vin: string;
  maker: string;
  model: string;
  modelYear: number;
}

export interface RecallRecord {
  id: string; // for example NWEC-RC-0042
  maker: string;
  component: string;
  partNumber: string;
  remedy: string;
  status: "open" | "closed";
  vins: string[];
}

interface RecallBulletin {
  recallId: string;
  vinPrefixes: string[];
}

async function readJson<T>(relativePath: string): Promise<T> {
  // Paths resolve from this file, so src/ (tsx, tests) and dist/ (the container) find the same data/.
  const url = new URL(`../../data/${relativePath}`, import.meta.url);
  return JSON.parse(await readFile(url, "utf8")) as T;
}

const { vehicles } = await readJson<{ vehicles: Vehicle[] }>("vehicles.synthetic.json");
const { recalls } = await readJson<{ recalls: RecallRecord[] }>("recalls.synthetic.json");
const bulletinFiles = (await readdir(new URL("../../data/bulletins/", import.meta.url))).filter((file) => file.endsWith(".json"));
const bulletins = await Promise.all(bulletinFiles.map((file) => readJson<RecallBulletin>(`bulletins/${file}`)));
const vinPrefixesByRecallId = new Map(bulletins.map((bulletin) => [bulletin.recallId, bulletin.vinPrefixes]));
const vehiclesByVin = new Map(vehicles.map((v) => [v.vin, v]));

/** The vehicle with this VIN, if it is in the synthetic vehicle inventory. */
export function findVehicle(vin: string): Vehicle | undefined {
  return vehiclesByVin.get(vin);
}

/** The vehicle with this VIN. */
export function getVehicle(vin: string): Vehicle {
  const vehicle = findVehicle(vin);
  if (!vehicle) throw new Error(`No vehicle with VIN ${vin}`);
  return vehicle;
}

/** Every recall, open or closed, that lists or covers this VIN by bulletin prefix. */
export function recallsForVin(vin: string): RecallRecord[] {
  return recalls.filter((recall) =>
    recall.vins.includes(vin) || (vinPrefixesByRecallId.get(recall.id) ?? []).some((prefix) => vin.startsWith(prefix)),
  );
}

/** Only the recalls that still need work on this VIN. */
export function openRecallsForVin(vin: string): RecallRecord[] {
  return recallsForVin(vin).filter((r) => r.status === "open");
}

/** True once the data above has loaded; the readiness probe reports it. */
export function isDataLoaded(): boolean {
  return vehiclesByVin.size > 0 && recalls.length > 0;
}
