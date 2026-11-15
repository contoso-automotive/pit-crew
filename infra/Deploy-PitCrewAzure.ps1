<#
.SYNOPSIS
    Deploys Pit Crew's Azure platform and web app from infra/main.bicep.

.DESCRIPTION
    Changes Azure state, so it reads first and asks before it writes:
      1. Shows where you are: the Azure subscription, your GitHub account and the repository IDs.
      2. Builds the OpenID Connect subject GitHub sends for the production environment.
      3. Runs a what-if, so you see every resource it would create or change.
      4. Stops until you type DEPLOY PIT CREW.
      5. Deploys the platform, builds the web image in Azure Container Registry, then deploys the app.
      6. Reads the resource group back from Azure Resource Graph, by name and type.
    Re-running it is safe: Bicep deployments are idempotent, and role assignments use stable names.

.PARAMETER Location
    Azure region, for example eastus2. Pick one that offers Azure Container Apps.

.PARAMETER BudgetEmail
    Who gets the resource group's budget alerts. Passed at run time and never written to a file.

.PARAMETER Repository
    The GitHub repository that deploys here, as OWNER/NAME.

.PARAMETER WhatIfOnly
    Stop after the what-if. Nothing changes.

.EXAMPLE
    pwsh -NoProfile -ExecutionPolicy Bypass -File .\infra\Deploy-PitCrewAzure.ps1 -Location eastus2 -BudgetEmail ops@contoso.com -WhatIfOnly
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
    Justification = 'Interactive operator script: every line is for the person at the console.')]
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [ValidatePattern('^[a-z0-9]+$')] [string] $Location,
    [Parameter(Mandatory)] [ValidatePattern('^[^@\s]+@[^@\s]+$')] [string] $BudgetEmail,
    [ValidatePattern('^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$')] [string] $Repository = 'contoso-automotive/pit-crew',
    [string] $Owner = 'pitcrew-team',
    [switch] $WhatIfOnly
)
$ErrorActionPreference = 'Stop'
$infra = $PSScriptRoot
$template = Join-Path $infra 'main.bicep'
$params = Join-Path $infra 'main.bicepparam'
$deploymentName = "pitcrew-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

function Invoke-Checked([string] $What, [scriptblock] $Command) {
    # Native commands don't throw on failure in PowerShell; check the exit code every time.
    $result = & $Command
    if ($LASTEXITCODE -ne 0) { throw "$What failed (exit $LASTEXITCODE)." }
    return $result
}

Write-Host '== Where am I (read only)'
$account = Invoke-Checked 'az account show' { az account show --query '{name:name, id:id, user:user.name}' -o json } | ConvertFrom-Json
$ghUser = Invoke-Checked 'gh api user' { gh api user --jq .login }
Write-Host "Azure subscription: $($account.name) ($($account.id)), signed in as $($account.user)"
Write-Host "GitHub account:     $ghUser"

# Repositories created after July 15, 2026 send an immutable subject: owner and repo IDs, not just names.
$ids = Invoke-Checked "gh api repos/$Repository" { gh api "repos/$Repository" --jq '[.owner.login, .owner.id, .name, .id] | @tsv' }
$ownerLogin, $ownerId, $repoName, $repoId = $ids -split "`t"
# Braces matter: "$repoId:environment" would parse as a drive-qualified variable, like $env:PATH.
$subject = "repo:${ownerLogin}@${ownerId}/${repoName}@${repoId}:environment:production"
Write-Host "Repository:         $Repository (owner ID $ownerId, repo ID $repoId)"
Write-Host "OIDC subject:       $subject"
Write-Host '   If the repo opted out of immutable subjects, compare with: gh api repos/OWNER/REPO/actions/oidc/customization/sub'

$env:PITCREW_LOCATION = $Location
$env:PITCREW_OWNER = $Owner
$env:PITCREW_OIDC_SUBJECT = $subject
$env:PITCREW_BUDGET_EMAILS = $BudgetEmail
$env:PITCREW_WEB_IMAGE = ''
$env:PITCREW_FEED_IMAGE = ''

Write-Host "`n== What-if: what this deployment would change (read only)"
Invoke-Checked 'what-if' { az deployment sub what-if --name $deploymentName --location $Location --template-file $template --parameters $params }
if ($WhatIfOnly) { Write-Host 'WhatIfOnly: stopped. Nothing changed.'; exit 0 }

$phrase = 'DEPLOY PIT CREW'
$typed = Read-Host "Type '$phrase' to create or update these resources"
if ($typed -cne $phrase) { Write-Host 'Stopped. Nothing changed.'; exit 1 }

Write-Host "`n== 1 of 3: platform (registry, identities, logs, Container Apps environment, budget)"
$out = Invoke-Checked 'platform deployment' { az deployment sub create --name "$deploymentName-platform" --location $Location --template-file $template --parameters $params --query properties.outputs -o json } | ConvertFrom-Json
$registry = $out.registryLoginServer.value
$rg = $out.resourceGroupName.value

Write-Host "`n== 2 of 3: build the web image in $registry (ACR Tasks builds in Azure; no local Docker needed)"
$sha = Invoke-Checked 'git rev-parse' { git -C (Split-Path $infra -Parent) rev-parse --short=12 HEAD }
$image = "$registry/pit-crew-web:$sha"
Invoke-Checked 'az acr build' { az acr build --registry ($registry -split '\.')[0] --image "pit-crew-web:$sha" (Split-Path $infra -Parent) }

Write-Host "`n== 3 of 3: the web app, running $image"
$env:PITCREW_WEB_IMAGE = $image
$out = Invoke-Checked 'app deployment' { az deployment sub create --name "$deploymentName-app" --location $Location --template-file $template --parameters $params --query properties.outputs -o json } | ConvertFrom-Json

Write-Host "`n== Read back from Azure Resource Graph (the authoritative inventory)"
Invoke-Checked 'resource graph' { az graph query -q "resources | where resourceGroup =~ '$rg' | project name, type, location | order by type asc" --query data -o table }

Write-Host "`n== For the GitHub production environment (environment secrets, not repository secrets)"
Write-Host "AZURE_CLIENT_ID       = $($out.deployIdentityClientId.value)"
Write-Host "AZURE_TENANT_ID       = $($out.tenantId.value)"
Write-Host "AZURE_SUBSCRIPTION_ID = $($out.subscriptionId.value)"
Write-Host "Web app:  https://$($out.webAppFqdn.value)"
