// Guards the synthetic-data rule: every VIN in data/ fails the real check digit.
import { readFileSync, readdirSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { expectedCheckDigit, isSyntheticVin, isWellFormedVin, normalizeVin } from "./vin.js";

const dataDir = new URL("../../data/", import.meta.url);

/** Every 17-character VIN-shaped string anywhere in the data files. */
function vinsInData(): string[] {
  const files = readdirSync(dataDir, { recursive: true, encoding: "utf8" }).filter((f) => f.endsWith(".json"));
  const vins = files.flatMap((f) => readFileSync(new URL(f, dataDir), "utf8").match(/\b5NW[A-Z0-9]{14}\b/g) ?? []);
  return [...new Set(vins)];
}

describe("VIN rules", () => {
  it("normalizes case and whitespace", () => {
    expect(normalizeVin(" 5nwec0042ra000042 ")).toBe("5NWEC0042RA000042");
  });

  it("rejects the letters I, O and Q and wrong lengths", () => {
    expect(isWellFormedVin("5NWEC0042RA00004O")).toBe(false);
    expect(isWellFormedVin("5NWEC0042RA00004")).toBe(false);
    expect(isWellFormedVin("5NWEC0042RA000042")).toBe(true);
  });

  it("computes the check digit a real VIN would carry", () => {
    // 1M8GDM9AXKP042788 is the textbook example of a valid check digit (X).
    expect(expectedCheckDigit("1M8GDM9AXKP042788")).toBe("X");
  });

  it("finds VINs in the data files", () => {
    expect(vinsInData().length).toBeGreaterThan(0);
  });

  it.each(vinsInData())("data VIN %s fails the real check digit, so it can't match a real car", (vin) => {
    expect(isSyntheticVin(vin)).toBe(true);
  });
});
