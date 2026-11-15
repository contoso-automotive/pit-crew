// Builds the Pit Crew web app. server.ts starts it; tests start it on a free port.
import { fileURLToPath } from "node:url";
import express, { type ErrorRequestHandler, type RequestHandler } from "express";
import { bayboardRouter } from "./bayboard/routes.js";
import { checkinRouter } from "./checkin/routes.js";
import { isDataLoaded } from "./recalls/lookup.js";
import { recallsRouter } from "./recalls/routes.js";
import { escapeHtml, page } from "./views/layout.js";

/**
 * Security headers on every response. They follow the OWASP secure headers guidance
 * without adding a dependency: no framing, no MIME sniffing, and only same-origin
 * scripts, styles and images.
 */
const securityHeaders: RequestHandler = (_req, res, next) => {
  res.set({
    "Content-Security-Policy": "default-src 'self'; img-src 'self' data:; style-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'",
    "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
    "Cross-Origin-Opener-Policy": "same-origin",
    "Permissions-Policy": "camera=(), microphone=(), geolocation=()",
  });
  next();
};

/** Anything unhandled becomes a 500 with no internals leaked; the details go to the log. */
const errorHandler: ErrorRequestHandler = (err, req, res, _next) => {
  console.error(JSON.stringify({ level: "error", path: req.path, message: err instanceof Error ? err.message : String(err) }));
  if (req.accepts(["html", "json"]) === "html") {
    res.status(500).send(page("Something went wrong", `<p class="status status-warn">Pit Crew couldn't finish that request. Try again, or ask the crew chief.</p>`));
    return;
  }
  res.status(500).json({ error: "Internal server error" });
};

export function createApp() {
  const app = express();
  app.disable("x-powered-by"); // Don't advertise the framework to scanners.
  app.use(securityHeaders);
  // fileURLToPath, not URL.pathname: on Windows, pathname keeps a slash before the drive letter, which breaks the static path.
  app.use(express.static(fileURLToPath(new URL("../public/", import.meta.url)), { index: false }));

  // Probes for Azure Container Apps: liveness says the process answers; readiness says it can serve.
  app.get("/healthz", (_req, res) => {
    res.json({ status: "ok" });
  });
  app.get("/readyz", (_req, res) => {
    res.status(isDataLoaded() ? 200 : 503).json({ status: isDataLoaded() ? "ready" : "loading" });
  });

  app.use("/recalls", recallsRouter);
  app.use("/bay-board", bayboardRouter);
  app.use("/", checkinRouter);

  app.use((req, res) => {
    res.status(404).send(page("Not found", `<p>No page at ${escapeHtml(req.path)}.</p>`));
  });
  app.use(errorHandler);
  return app;
}
