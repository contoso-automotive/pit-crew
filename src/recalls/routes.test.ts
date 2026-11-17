// Contract tests for GET /recalls/{vin}, run against a real HTTP server on a free port.
import type { Server } from "node:http";
import type { AddressInfo } from "node:net";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { createApp } from "../app.js";

let server: Server;
let baseUrl: string;

beforeAll(async () => {
  server = createApp().listen(0);
  await new Promise<void>((resolve) => server.once("listening", () => resolve()));
  baseUrl = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
});

afterAll(() => new Promise<void>((resolve) => server.close(() => resolve())));

describe("GET /recalls/{vin}", () => {
  it("returns the open NWEC-RC-0042 recall for a recalled VIN", async () => {
    const res = await fetch(`${baseUrl}/recalls/5NWEC0042RA000042`);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { vin: string; recalls: { id: string; status: string }[] };
    expect(body.vin).toBe("5NWEC0042RA000042");
    expect(body.recalls).toContainEqual(expect.objectContaining({ id: "NWEC-RC-0042", status: "open" }));
  });

  it("accepts a lowercase VIN with spaces around it", async () => {
    const res = await fetch(`${baseUrl}/recalls/%205nwec0042ra000042%20`);
    expect(res.status).toBe(200);
  });

  it("returns 400 for a malformed VIN", async () => {
    const res = await fetch(`${baseUrl}/recalls/NOT-A-VIN`);
    expect(res.status).toBe(400);
  });

  it("returns 404 for a well-formed VIN that is not on file", async () => {
    const res = await fetch(`${baseUrl}/recalls/5NWEC0042RA000043`);
    expect(res.status).toBe(404);
    expect(await res.json()).toEqual({ error: "No vehicle found for this VIN." });
  });
});
