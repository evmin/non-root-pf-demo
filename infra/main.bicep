targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources (filtered on available regions for Azure Open AI Service).')
@allowed([
  'westeurope'
  'southcentralus'
  'australiaeast'
  'canadaeast'
  'eastus'
  'eastus2'
  'francecentral'
  'japaneast'
  'northcentralus'
  'swedencentral'
  'switzerlandnorth'
  'uksouth'
])
param location string

param appExists bool

@description('Name of the resource group. Leave blank to use default naming conventions.')
param resourceGroupName string = ''

@description('Tags to be applied to resources.')
param tags object = { 'azd-env-name': environmentName }

@description('Id of the user or app to assign application roles')
param principalId string

// Load abbreviations from JSON file
var abbrs = loadJsonContent('./abbreviations.json')
// Generate a unique token for resources
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

// Organize resources in a resource group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// ------------------------
// [ Array of OpenAI Model deployments ]
param aoaiGpt4ModelName string= 'gpt-4o-mini'
param aoaiGpt4ModelVersion string = '2024-07-18'

param deployments array = [
  {
    name:  '${aoaiGpt4ModelName}' // MUST MATCH the model defined in PF dag
    model: {
      format: 'OpenAI'
      name: aoaiGpt4ModelName
      version: aoaiGpt4ModelVersion
    }
    sku: {
      name: 'Standard'
      capacity: 30
    }
  }
]

module aiServices 'modules/ai/cognitiveservices.bicep' = {
  name: 'aiServices'
  scope: resourceGroup
  params: {
    resourceToken: resourceToken
    tags: tags
    deployments: deployments
  }
}

var logAnalyticsName = '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
module monitoring 'modules/monitoring/monitor.bicep' = {
  name: 'monitor'
  scope: resourceGroup
  params: {
    logAnalyticsName: logAnalyticsName
    resourceToken: resourceToken
    tags: tags
  }
}

module keyVault 'modules/keyvault/keyvault.bicep' = {
  name: 'keyvault'
  params: {
    location: location
    tags: tags
    name: '${abbrs.keyVaultVaults}${resourceToken}'
    principalId: principalId
  }
  scope: resourceGroup
}

module registry 'modules/app/registry.bicep' = {
  name: 'registry'
  params: {
    location: location
    tags: tags
    name: '${abbrs.containerRegistryRegistries}${resourceToken}'
  }
  scope: resourceGroup
}

module app 'modules/app/containerapp.bicep' = {
  name: 'app'
  scope: resourceGroup
  params: {
    name: '${abbrs.appContainerApps}app-${resourceToken}'
    tags: tags
    logAnalyticsWorkspaceName: logAnalyticsName
    applicationInsightsName: monitoring.outputs.appInsightsName
    azureOpenAIName: aiServices.outputs.aoaiName  
    azureModelDeploymentName: deployments[0].name
    identityName: '${abbrs.managedIdentityUserAssignedIdentities}app-${resourceToken}'
    containerRegistryName: registry.outputs.name
    exists: appExists
  }
}

output AZURE_OPENAI_ENDPOINT string = aiServices.outputs.aoaiEndpoint
output AZURE_OPENAI_ACCOUNT_NAME string = aiServices.outputs.aoaiName
output AZURE_OPENAI_DEPLOYMENT_NAME string = deployments[0].name

// mandatory output fopr container deployments
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = registry.outputs.loginServer
output AZURE_KEY_VAULT_NAME string = keyVault.outputs.name
output AZURE_KEY_VAULT_ENDPOINT string = keyVault.outputs.endpoint
