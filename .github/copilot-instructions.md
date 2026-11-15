# Pit Crew: instructions for Copilot

Pit Crew is Contoso Automotive's service bay app. A service advisor checks a car in by its VIN, Pit Crew flags any open recall, and repair orders move across the bay board. Every name, VIN and recall here is fiction.

## Build and test

- Node.js 24 or later. Install with `npm ci`, never `npm install`, so the lockfile decides versions.
- Before you open a pull request, run `npm run lint`, `npm run typecheck` and `npm test`, and fix what they report.
- The CI check named `test` runs the same three commands on every pull request into `main`.

## Layout

- `src/recalls/`: vehicle and recall lookups (`lookup.ts`) and the `GET /recalls/{vin}` route (`routes.ts`).
- `src/checkin/`: the check-in bay pages.
- `src/bayboard/`: repair orders and bay board cards.
- `src/vin/`: VIN validation and the check digit.
- `src/views/layout.ts`: the page shell and `escapeHtml`.
- `data/`: synthetic JSON only. `data/bulletins/` holds Northwind Electric Cars recall bulletins.
- `infra/`: Bicep for Azure. Don't change it in an application pull request.

## Rules

- Synthetic data only. Every VIN must fail the real check digit; `src/vin/vin.test.ts` enforces it.
- Escape every value you put in HTML with `escapeHtml`.
- Show status as a word, and a symbol where it helps. Never use color alone to carry meaning.
- Put tests next to the code they cover, named `*.test.ts`, and use Vitest.
- Add no new dependency unless the issue asks for one.
- Keep a change to the paths the issue names.
