targetScope = 'resourceGroup'
@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string = 'eastus'


param appServicePlanName string = ''
param webServiceName string = ''
// serviceName is used as value for the tag (azd-service-name) azd uses to identify
param serviceName string = 'web'

// Load the abbreviations.json file to use in resource names
var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

// Create an App Service Plan to group applications under the same payment plan and SKU
module appServicePlan './core/host/appserviceplan.bicep' = {
  name: 'appserviceplan'
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
      AZURE_OPENAI_API_KEY:'YOUR_OPENAI_KEY' //#Replace with the OpenAI Key
      AZURE_OPENAI_ENDPOINT:'YOUR_OPENAI_ENDPOINT' //#Replace with the OpenAI Endpoint
      AZURE_OPENAI_EMB_DEPLOYMENT:'YOUR_EMBEDDING_MODEL' //#Replace with name of your embedding model deployment
      AZURE_OPENAI_CHAT_DEPLOYMENT:'YOUR_GPT4_MODEL' //#Replace with name of your Open AI Chat Deployment
      USE_AZCS:'False' //#if false, it will use the Faiss library for search
      AZURE_SEARCH_SERVICE_ENDPOINT:'YOUR_SEARCH_SERVICE_ENDPOINT' //#Replace with Search Service Endpoint
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
