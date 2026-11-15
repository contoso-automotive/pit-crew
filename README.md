# Pit Crew

Pit Crew is the service bay app for **Contoso Automotive**, a fictional chain of auto service centers. A service advisor checks a car in by its VIN, Pit Crew flags any open recall, and each repair order moves across the bay board until the car goes home.

Contoso Automotive, Northwind Electric Cars, every recall and every VIN in this repository are fiction. The data is synthetic: every VIN fails the real check digit, so none can match a car on the road.

## Run it

You need Node.js 24 or later.

```bash
npm ci
npm run dev
```

Open http://localhost:8080 and check in VIN `5NWEC0042RA000042`.

## Check it

```bash
npm run lint
npm run typecheck
npm test
```

The `pit-crew-ci` workflow runs the same commands on every pull request into `main`.

## What's where

| Path | What it holds |
| --- | --- |
| `src/recalls/` | Vehicle and recall lookups, and the `GET /recalls/{vin}` API |
| `src/checkin/` | The check-in bay pages |
| `src/bayboard/` | Repair orders and bay board cards |
| `src/vin/` | VIN validation and the check digit |
| `data/` | Synthetic vehicles, recalls, repair orders and Northwind bulletins |
| `infra/` | Bicep for Azure Container Apps, deployed through GitHub Actions with OpenID Connect |
| `.github/` | CI, Copilot setup steps, Dependabot and the repository instructions for Copilot |

## The API

`GET /recalls/{vin}` returns the recalls on file for one vehicle:

```json
{ "vin": "5NWEC0042RA000042", "recalls": [{ "id": "NWEC-RC-0042", "component": "Battery coolant valve", "status": "open" }] }
```

A malformed VIN returns 400.

## Azure

`infra/` deploys Pit Crew to Azure Container Apps in one resource group, named to the Cloud Adoption Framework's conventions and tagged for cost tracking. Images live in Azure Container Registry, pulled by a managed identity with no registry password. GitHub Actions deploys through OpenID Connect, so no Azure secret lives in the repository. See `infra/README.md`.

## License

MIT. See `LICENSE`.
