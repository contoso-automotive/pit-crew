import { describe, expect, it } from "vitest";
import { cardLines } from "./card.js";

describe("bay board card", () => {
  it("states the status in words", () => {
    const lines = cardLines({ id: "RO-1042", vin: "5NWEC0042RA000042", status: "in-bay", technician: "Terry Adams" });
    expect(lines).toEqual(["RO-1042", "5NWEC0042RA000042", "Status: in-bay", "Tech: Terry Adams"]);
  });
});
