// Everything inside rg-pitcrew-<env>. Each choice below names the Azure Well-Architected
// Framework (WAF) pillar it serves, and each trade-off a lab makes on purpose says so.
param location string
param workload string
param environment string
param instance string
param tags object
param githubOidcSubject string
param webImage string
param feedImage string
param monthlyBudget int
param budgetContactEmails array
param budgetStartDate string
param deployFoundry bool

// Built-in role IDs, read with `az role definition list --name <role>` on 2026-11-15.
var roles = {
  acrPull: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
  acrPush: '8311e382-0749-4cb8-b61a-304f252e45ec'
  containerAppsContributor: '358470bc-b998-42bd-ab17-a7e34c199c0f'
  foundryUser: '53ca6127-db72-4b80-b1b0-d745d6d5456d'
}

var deployWeb = !empty(webImage)
var deployFeed = !empty(feedImage)

// ---------- Observability (Operational Excellence) ----------
resource logs 'Microsoft.OperationalInsights/workspaces@2025-07-01' = {
  name: 'log-${workload}-${environment}'
  location: location
  tags: tags
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30 // The shortest standard retention: enough to troubleshoot a week of lab work (Cost Optimization).
  }
}

// ---------- Identities (Security: no passwords, least privilege) ----------
// A dedicated identity for image pulls only, as the Azure Architecture Center's Container Apps
// reference architecture recommends: never reused for workload operations. Each app's own
// system-assigned identity does the workload's work (for example, calling the Foundry model).
resource registryIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: 'id-${workload}-acrpull-${environment}'
  location: location
  tags: tags
}

// The deploy identity belongs to GitHub Actions' production environment only. The agent never holds it.
resource deployIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: 'id-${workload}-deploy-${environment}'
  location: location
  tags: tags
}

// Workload identity federation: Azure trusts one exact GitHub subject, so no client secret exists anywhere.
resource githubFederation 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2024-11-30' = {
  parent: deployIdentity
  name: 'github-${environment}'
  properties: {
    issuer: 'https://token.actions.githubusercontent.com'
    subject: githubOidcSubject
    audiences: ['api://AzureADTokenExchange']
  }
}

// ---------- Registry (Security: no admin user, no anonymous pull) ----------
resource registry 'Microsoft.ContainerRegistry/registries@2025-04-01' = {
  name: 'cr${workload}${environment}${instance}'
  location: location
  tags: tags
  sku: { name: 'Basic' } // Basic covers a lab's storage and pulls (Cost Optimization). Premium adds private endpoints.
  properties: {
    adminUserEnabled: false
    anonymousPullEnabled: false
  }
}

resource appPullsImages 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(registry.id, registryIdentity.id, roles.acrPull)
  scope: registry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.acrPull)
    principalId: registryIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource deployPushesImages 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(registry.id, deployIdentity.id, roles.acrPush)
  scope: registry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.acrPush)
    principalId: deployIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// ---------- Container Apps environment ----------
// A dedicated environment for this one workload (Azure Architecture Center: don't share one).
// Deliberate deviation: the Architecture Center keeps container apps out of the infrastructure
// pipeline. Here Bicep creates them, so the deploy identity only ever UPDATES an image
// (Container Apps Contributor on two apps) and never needs rights to create resources.
resource containerEnv 'Microsoft.App/managedEnvironments@2025-07-01' = {
  name: 'cae-${workload}-${environment}'
  location: location
  tags: tags
  properties: {
    // azure-monitor sends logs through diagnostic settings, so no workspace shared key is copied anywhere.
    appLogsConfiguration: { destination: 'azure-monitor' }
    workloadProfiles: [
      { name: 'Consumption', workloadProfileType: 'Consumption' }
    ]
    // Trade-off (Reliability vs. Cost): zone redundancy needs a custom virtual network. A lab runs without both.
    zoneRedundant: false
  }
}

resource containerEnvLogs 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'to-${logs.name}'
  scope: containerEnv
  properties: {
    workspaceId: logs.id
    logs: [{ categoryGroup: 'allLogs', enabled: true }]
    metrics: [{ category: 'AllMetrics', enabled: true }]
  }
}

// Probe settings are the WAF Container Apps guide's recommendations (Reliability).
var probes = [
  { type: 'Liveness', httpGet: { path: '/healthz', port: 8080 }, initialDelaySeconds: 10, periodSeconds: 10, timeoutSeconds: 5, failureThreshold: 3, successThreshold: 1 }
  { type: 'Readiness', httpGet: { path: '/readyz', port: 8080 }, initialDelaySeconds: 5, periodSeconds: 1, timeoutSeconds: 1, failureThreshold: 60, successThreshold: 1 }
  { type: 'Startup', httpGet: { path: '/healthz', port: 8080 }, initialDelaySeconds: 0, periodSeconds: 1, timeoutSeconds: 1, failureThreshold: 60, successThreshold: 1 }
]

// Shared app shape: HTTPS only, image pulled with the managed identity, scale to zero when idle.
// Trade-off (Reliability vs. Cost): the WAF guide wants three or more replicas for production traffic.
// A lab that sits idle between recordings scales to zero instead, and accepts a cold start.
var appConfiguration = {
  activeRevisionsMode: 'Single'
  ingress: {
    external: true
    targetPort: 8080
    transport: 'auto'
    allowInsecure: false
  }
  registries: [{ server: registry.properties.loginServer, identity: registryIdentity.id }]
}
var scale = {
  minReplicas: 0
  maxReplicas: 3
  rules: [{ name: 'http', http: { metadata: { concurrentRequests: '50' } } }]
}

resource webApp 'Microsoft.App/containerApps@2025-07-01' = if (deployWeb) {
  name: 'ca-${workload}-web-${environment}'
  location: location
  tags: tags
  identity: { type: 'SystemAssigned,UserAssigned', userAssignedIdentities: { '${registryIdentity.id}': {} } }
  properties: {
    environmentId: containerEnv.id
    workloadProfileName: 'Consumption'
    configuration: appConfiguration
    template: {
      containers: [{
        name: 'pit-crew-web'
        image: webImage
        resources: { cpu: json('0.25'), memory: '0.5Gi' }
        env: [{ name: 'PORT', value: '8080' }]
        probes: probes
      }]
      scale: scale
    }
  }
  dependsOn: [appPullsImages]
}

resource feedApp 'Microsoft.App/containerApps@2025-07-01' = if (deployFeed) {
  name: 'ca-${workload}-feed-${environment}'
  location: location
  tags: tags
  identity: { type: 'SystemAssigned,UserAssigned', userAssignedIdentities: { '${registryIdentity.id}': {} } }
  properties: {
    environmentId: containerEnv.id
    workloadProfileName: 'Consumption'
    configuration: appConfiguration
    template: {
      containers: [{
        name: 'pit-crew-feed'
        image: feedImage
        resources: { cpu: json('0.25'), memory: '0.5Gi' }
        env: [{ name: 'PORT', value: '8080' }]
        probes: probes
      }]
      scale: scale
    }
  }
  dependsOn: [appPullsImages]
}

// The deploy identity may update these two apps and nothing else in the subscription.
resource deployUpdatesWeb 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployWeb) {
  name: guid(resourceGroup().id, 'web', deployIdentity.id, roles.containerAppsContributor)
  scope: webApp
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.containerAppsContributor)
    principalId: deployIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource deployUpdatesFeed 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployFeed) {
  name: guid(resourceGroup().id, 'feed', deployIdentity.id, roles.containerAppsContributor)
  scope: feedApp
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.containerAppsContributor)
    principalId: deployIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// ---------- Microsoft Foundry (optional; the service writer's model) ----------
resource foundry 'Microsoft.CognitiveServices/accounts@2025-06-01' = if (deployFoundry) {
  name: 'aif-${workload}-${environment}-${instance}'
  location: location
  tags: tags
  kind: 'AIServices'
  sku: { name: 'S0' }
  identity: { type: 'SystemAssigned' }
  properties: {
    customSubDomainName: 'aif-${workload}-${environment}-${instance}'
    allowProjectManagement: true
    disableLocalAuth: true // Microsoft Entra ID only: no API keys to leak (Security).
    publicNetworkAccess: 'Enabled'
  }
}

resource foundryProject 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' = if (deployFoundry) {
  parent: foundry
  name: 'proj-${workload}-${environment}'
  location: location
  tags: tags
  identity: { type: 'SystemAssigned' }
  properties: {}
}

// The web app's system-assigned identity, not the registry identity, may call the model.
resource webUsesFoundry 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployFoundry && deployWeb) {
  name: guid(resourceGroup().id, 'foundry', 'web', roles.foundryUser)
  scope: foundry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.foundryUser)
    principalId: webApp!.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// ---------- Budget (Cost Optimization) ----------
resource budget 'Microsoft.Consumption/budgets@2024-08-01' = {
  name: 'budget-${workload}-${environment}'
  properties: {
    category: 'Cost'
    amount: monthlyBudget
    timeGrain: 'Monthly'
    timePeriod: { startDate: budgetStartDate }
    notifications: {
      actual50: { enabled: true, operator: 'GreaterThan', threshold: 50, thresholdType: 'Actual', contactEmails: budgetContactEmails }
      actual80: { enabled: true, operator: 'GreaterThan', threshold: 80, thresholdType: 'Actual', contactEmails: budgetContactEmails }
      forecast100: { enabled: true, operator: 'GreaterThan', threshold: 100, thresholdType: 'Forecasted', contactEmails: budgetContactEmails }
    }
  }
}

output registryLoginServer string = registry.properties.loginServer
output containerAppsEnvironmentName string = containerEnv.name
output webAppName string = deployWeb ? webApp.name : ''
output webAppFqdn string = deployWeb ? webApp!.properties.configuration.ingress.fqdn : ''
output feedAppName string = deployFeed ? feedApp.name : ''
output feedAppFqdn string = deployFeed ? feedApp!.properties.configuration.ingress.fqdn : ''
output deployIdentityClientId string = deployIdentity.properties.clientId
