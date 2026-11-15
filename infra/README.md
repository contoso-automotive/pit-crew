# Pit Crew infrastructure

`main.bicep` deploys Pit Crew to one Azure resource group. Every name follows the Cloud Adoption Framework's [naming convention](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming) and [abbreviations](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations), and every resource carries the same tags.

| Resource | Name | Why it's here |
| --- | --- | --- |
| Resource group | `rg-pitcrew-prod` | One lifecycle boundary for the whole workload |
| Log Analytics workspace | `log-pitcrew-prod` | Console and system logs from Container Apps, 30-day retention |
| Container registry | `crpitcrewprod001` | Images, with the admin user and anonymous pull turned off |
| Managed identity | `id-pitcrew-app-prod` | The app's runtime identity: pulls images, nothing else |
| Managed identity | `id-pitcrew-deploy-prod` | GitHub Actions' production environment, federated by OpenID Connect |
| Container Apps environment | `cae-pitcrew-prod` | Consumption workload profile, logs through Azure Monitor |
| Container app | `ca-pitcrew-web-prod` | The Pit Crew web app |
| Container app | `ca-pitcrew-feed-prod` | The recall bulletin feed (only when a feed image is supplied) |
| Budget | `budget-pitcrew-prod` | Alerts at 50 and 80 percent of actual spend and 100 percent of forecast |
| Foundry account and project | `aif-pitcrew-prod-001`, `proj-pitcrew-prod` | The service writer's model (only when `deployFoundry` is true) |

## The choices, by Well-Architected pillar

These follow the [Azure Well-Architected Framework guide for Azure Container Apps](https://learn.microsoft.com/azure/well-architected/service-guides/azure-container-apps).

- **Security:** managed identities for image pulls and for the model, so no registry password or API key exists. The deploy identity trusts exactly one GitHub subject (the repository's `production` environment) and holds Container Apps Contributor on the two apps and AcrPush on the registry, nothing wider. HTTPS only.
- **Reliability:** liveness, readiness and startup probes with the guide's recommended settings, and graceful shutdown on `SIGTERM`.
- **Cost Optimization:** scale to zero, a Basic registry, 30-day log retention and a budget with alerts.
- **Operational Excellence:** everything is Bicep in Git, deployed by a reviewed workflow; logs reach Log Analytics without a shared key.

## Trade-offs a lab makes on purpose

- **Scale to zero instead of three replicas.** The guide wants at least three replicas for production traffic. A lab that sits idle between uses scales to zero and accepts a cold start.
- **No zone redundancy and no private network.** Both need a custom virtual network, which adds cost and setup that no lesson uses. Production would add them.
- **A public registry endpoint.** Private endpoints need the Premium tier.

## Deploy

You need the Azure CLI signed in to the target subscription, the GitHub CLI signed in, and the repository created. Run the what-if first:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\infra\Deploy-PitCrewAzure.ps1 -Location eastus2 -BudgetEmail <your alert address> -WhatIfOnly
```

Then run it again without `-WhatIfOnly`. It stops until you type `DEPLOY PIT CREW`, deploys, builds the web image in Azure Container Registry, and reads the resource group back from Azure Resource Graph. The read-back uses the `resource-graph` Azure CLI extension.
