// Check-in bay behavior: the page loads, a known VIN shows its car, and input is escaped.
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

describe("check-in bay", () => {
  it("shows the check-in form", async () => {
    const res = await fetch(`${baseUrl}/`);
    expect(res.status).toBe(200);
    expect(await res.text()).toContain('name="vin"');
  });

  it("shows the car for a known VIN", async () => {
    const res = await fetch(`${baseUrl}/checkin?vin=5NWEC0042SA000118`);
    expect(res.status).toBe(200);
    expect(await res.text()).toContain("2025 Northwind EV Crossover");
  });

  it("escapes what the advisor typed", async () => {
    const res = await fetch(`${baseUrl}/checkin?vin=${encodeURIComponent("<script>")}`);
    expect(res.status).toBe(400);
    const html = await res.text();
    expect(html).not.toContain("<script>");
    expect(html).toContain("&lt;script&gt;");
  });
});
