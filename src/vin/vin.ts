// VIN rules for Pit Crew. A VIN is 17 characters from a restricted alphabet, and
// position 9 is a check digit computed from the other 16 (the North American scheme).
//
// Why this file exists: Pit Crew runs on synthetic data only. Every VIN in data/ must
// FAIL the check digit, so no record can ever describe a real car. vin.test.ts enforces
// that rule on every data file, which keeps a well-meaning edit from adding a real VIN.

/** Letters I, O and Q never appear in a VIN, because they read like 1, 0 and 0. */
const VIN_PATTERN = /^[A-HJ-NPR-Z0-9]{17}$/;

/** Each character's numeric value in the check digit formula. Digits are themselves. */
const TRANSLITERATION: Readonly<Record<string, number>> = {
  A: 1, B: 2, C: 3, D: 4, E: 5, F: 6, G: 7, H: 8,
  J: 1, K: 2, L: 3, M: 4, N: 5, P: 7, R: 9,
  S: 2, T: 3, U: 4, V: 5, W: 6, X: 7, Y: 8, Z: 9,
};

/** Position weights; position 9 (the check digit itself) weighs 0. */
const WEIGHTS = [8, 7, 6, 5, 4, 3, 2, 10, 0, 9, 8, 7, 6, 5, 4, 3, 2] as const;

/** Uppercases and trims, so " 5nwec..." and "5NWEC..." look up the same vehicle. */
export function normalizeVin(input: string): string {
  return input.trim().toUpperCase();
}

/** True when the string has a VIN's shape: 17 characters, no I, O or Q. */
export function isWellFormedVin(vin: string): boolean {
  return VIN_PATTERN.test(vin);
}

/** The check digit a real VIN would carry at position 9: "0" to "9", or "X" for 10. */
export function expectedCheckDigit(vin: string): string {
  if (!isWellFormedVin(vin)) throw new Error(`Not a well-formed VIN: ${vin}`);
  let sum = 0;
  for (let i = 0; i < 17; i++) {
    const ch = vin.charAt(i);
    const value = /\d/.test(ch) ? Number(ch) : (TRANSLITERATION[ch] ?? 0);
    sum += value * (WEIGHTS[i] ?? 0);
  }
  const remainder = sum % 11;
  return remainder === 10 ? "X" : String(remainder);
}

/** True when the VIN is well formed and its check digit is wrong, which is what synthetic data needs. */
export function isSyntheticVin(vin: string): boolean {
  return isWellFormedVin(vin) && vin.charAt(8) !== expectedCheckDigit(vin);
}
