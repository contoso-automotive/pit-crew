// Starts Pit Crew. PORT defaults to 8080, the port the container exposes.
import { createApp } from "./app.js";

const port = Number(process.env.PORT ?? 8080);
const server = createApp().listen(port, () => {
  console.log(JSON.stringify({ level: "info", message: `Pit Crew listening on port ${port}` }));
});

// Azure Container Apps sends SIGTERM before it stops a replica. Finish in-flight
// requests, then exit, so a scale-in or a new revision never cuts a request off.
for (const signal of ["SIGTERM", "SIGINT"] as const) {
  process.once(signal, () => {
    server.close(() => process.exit(0));
  });
}
