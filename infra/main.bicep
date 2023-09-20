
@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string = 'eastus'


param appServicePlanName string = ''
param resourceGroupName string = ''
param webServiceName string = ''
// serviceName is used as value for the tag (azd-service-name) azd uses to identify
param serviceName string = 'web'

// Load the abbreviations.json file to use in resource names
var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}
// Create an App Service Plan to group applications under the same payment plan and SKU
module appServicePlan './core/host/appserviceplan.bicep' = {
  name: 'appserviceplan'
  scope: rg
  params: {
    name: !empty(appServicePlanName) ? appServicePlanName : '${abbrs.webServerFarms}${resourceToken}'
    location: location
    tags: tags
    sku: {
      name: 'P2V3'
    }
    kind: 'linux'
    reserved: true
  }
}

// The application frontend
module web './core/host/appservice.bicep' = {
  name: serviceName
  scope: rg
  params: {
    name: !empty(webServiceName) ? webServiceName : '${abbrs.webSitesAppService}web-${resourceToken}'
    location: location
    tags: union(tags, { 'azd-service-name': serviceName })
    appServicePlanId: appServicePlan.outputs.id
    runtimeName: 'python'
    runtimeVersion: '3.10'
    scmDoBuildDuringDeployment: true
    appCommandLine: 'python -m streamlit run hr_copilot.py --server.port 8000 --server.address 0.0.0.0'
    appSettings: {
      AZURE_OPENAI_API_KEY:'92720cf19b6742c8baf32638dfb2436d'
      AZURE_OPENAI_ENDPOINT:'https://sumitprd.openai.azure.com/'
      AZURE_OPENAI_EMB_DEPLOYMENT:'gptchat' //#name of your embedding model deployment
      AZURE_OPENAI_CHAT_DEPLOYMENT:'gpt' //#name of your Open AI Chat Deployment
      USE_AZCS:'False' //#if false, it will use the Faiss library for search
      AZURE_SEARCH_SERVICE_ENDPOINT:'https://YOUR_SEARCH_SERVICE.search.windows.net'
      AZURE_SEARCH_INDEX_NAME: 'YOUR_SEARCH_INDEX_NAME'
      CACHE_INDEX_NAME:'YOUR_SEARCH_INDEX_NAME' //#optional, required when USE_SEMANTIC_CACHE='True'
      AZURE_SEARCH_ADMIN_KEY:'' //YOUR_SEARCH_INDEX_NAME_KEY
      AZURE_OPENAI_API_VERSION:'2023-07-01-preview'
      USE_SEMANTIC_CACHE:'False' //#set to True if use semantic Cache.
      SEMANTIC_HIT_THRESHOLD:'0.9' //#Threshold in similarity score to determine if sematic cached will be used
    }  
  }
}

// App outputs
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output REACT_APP_WEB_BASE_URL string = web.outputs.uri
