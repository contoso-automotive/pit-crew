// Shared HTML for every Pit Crew page: one dark theme, large type, and text that
// carries meaning on its own. Status is always a word (and often a symbol), never color alone.

/** Escapes text for safe use in HTML, so data can never turn into markup or script. */
export function escapeHtml(value: unknown): string {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

/** Wraps page content in the Pit Crew shell. `title` is escaped; `body` must already be safe HTML. */
export function page(title: string, body: string): string {
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escapeHtml(title)} | Pit Crew</title>
  <link rel="stylesheet" href="/styles.css">
</head>
<body>
  <header>
    <p class="brand">Contoso Automotive <span>Pit Crew</span></p>
    <nav aria-label="Main">
      <a href="/">Check-in bay</a>
      <a href="/bay-board">Bay board</a>
    </nav>
  </header>
  <main>
    <h1>${escapeHtml(title)}</h1>
    ${body}
  </main>
  <footer><p>Synthetic data only. Every VIN fails the real check digit.</p></footer>
</body>
</html>`;
}
