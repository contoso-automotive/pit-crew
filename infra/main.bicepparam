// Parameters for main.bicep. Every value comes from an environment variable that
// Deploy-PitCrewAzure.ps1 sets, so no email address, ID or region choice is committed.
using './main.bicep'

param location = readEnvironmentVariable('PITCREW_LOCATION', 'eastus2')
param owner = readEnvironmentVariable('PITCREW_OWNER', 'pitcrew-team')
param githubOidcSubject = readEnvironmentVariable('PITCREW_OIDC_SUBJECT')
param budgetContactEmails = split(readEnvironmentVariable('PITCREW_BUDGET_EMAILS'), ',')
param webImage = readEnvironmentVariable('PITCREW_WEB_IMAGE', '')
param feedImage = readEnvironmentVariable('PITCREW_FEED_IMAGE', '')
