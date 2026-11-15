// Pit Crew on Azure: one resource group, named and tagged to the Cloud Adoption Framework (CAF).
// Deployed at subscription scope so the resource group itself is code, not a click.
// Run it through Deploy-PitCrewAzure.ps1, which reads what it will change and asks first.
targetScope = 'subscription'

@description('Azure region for every resource. Pick a region that offers Azure Container Apps.')
param location string

@description('Workload name used in every resource name, per the CAF naming convention.')
@maxLength(10)
param workload string = 'pitcrew'

@description('Environment component of each name: the deploy environment the GitHub workflow targets.')
@allowed(['prod', 'dev', 'test'])
param environment string = 'prod'

@description('Instance number for names that must be globally unique, such as the container registry.')
param instance string = '001'

@description('The owning team or alias for the owner tag. Never a personal email: tags are plain text.')
param owner string

@description('Repository URL for the repo tag.')
param repositoryUrl string = 'https://github.com/contoso-automotive/pit-crew'

@description('OIDC subject GitHub sends for the production environment, for example repo:ORG@ORG-ID/REPO@REPO-ID:environment:production.')
param githubOidcSubject string

@description('Web app image, for example crpitcrewprod001.azurecr.io/pit-crew-web:<git sha>. Empty deploys the platform only.')
param webImage string = ''

@description('Recall feed image. Empty skips the feed app.')
param feedImage string = ''

@description('Monthly budget for the resource group, in the billing currency.')
@minValue(1)
param monthlyBudget int = 25

@description('Who gets budget alerts. Supplied at deploy time and never committed.')
param budgetContactEmails array

@description('First day of the budget period (yyyy-MM-01).')
param budgetStartDate string = utcNow('yyyy-MM-01')

@description('Deploy the Microsoft Foundry account and project for the service writer. Off until a lesson needs it.')
param deployFoundry bool = false

// CAF tagging: functional (workload, env), classification (criticality, dataClassification),
// accounting (costCenter) and ownership (owner), plus the repo that deploys it.
var tags = {
  workload: workload
  env: environment
  owner: owner
  criticality: 'low'
  dataClassification: 'public'
  costCenter: 'gh600-lab'
  repo: repositoryUrl
}

resource rg 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: 'rg-${workload}-${environment}'
  location: location
  tags: tags
}

module platform 'modules/workload.bicep' = {
  name: 'pitcrew-workload'
  scope: rg
  params: {
    location: location
    workload: workload
    environment: environment
    instance: instance
    tags: tags
    githubOidcSubject: githubOidcSubject
    webImage: webImage
    feedImage: feedImage
    monthlyBudget: monthlyBudget
    budgetContactEmails: budgetContactEmails
    budgetStartDate: budgetStartDate
    deployFoundry: deployFoundry
  }
}

output resourceGroupName string = rg.name
output registryLoginServer string = platform.outputs.registryLoginServer
output containerAppsEnvironmentName string = platform.outputs.containerAppsEnvironmentName
output webAppName string = platform.outputs.webAppName
output webAppFqdn string = platform.outputs.webAppFqdn
output feedAppName string = platform.outputs.feedAppName
output feedAppFqdn string = platform.outputs.feedAppFqdn
output deployIdentityClientId string = platform.outputs.deployIdentityClientId
output tenantId string = tenant().tenantId
output subscriptionId string = subscription().subscriptionId
