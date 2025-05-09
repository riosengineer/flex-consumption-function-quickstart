using 'main.bicep' 

// Naming / Tags 
param rgName = 'rg-flex-function-demo'
param location = 'uksouth'
param env = 'demo'
param entity = 'rios'
param workload = 'flex'
param locationOfEnv = 'uks'
param tags = {
  Demo: 'Flex Consumption Function'
  Networking: 'Private'
  Identity: 'Managed'
  Bicep: 'Completed it mate'
  'hidden-title': 'Demo Flex Function'
}


// Networking
param peSubnetName = 'sn-pe'
param peSubnetPrefix = '10.0.1.0/27'
param integrationSubnetName = 'sn-vnet-integrations'
param integrationSubnetPrefix = '10.0.1.128/25' // Couldn't actually find the recommended CIDR for a Flex Consumption in the docs? Portal suggested this on deployment 
param virtualNetworkName = 'flex-vnet'
param vnetPrefix = '10.0.1.0/24'
param nsgPeName = 'nsg-pe'
param nsgIntName = 'nsg-int'

// Function App
param umiName = 'umi-flex'
param keyVaultName = 'kvflexfuncdemo001' // Gotta be a unique name cause' reasons
param functionStorageAccountName = 'striosengineerflexdemo' // And this one
param functionStorageBlobContainerName = 'flex-container' // The deployment of the runtime is stored in this Blob container 
param functionAppPlanName = 'asp-func'
param functionAppName = 'func-flex-rios'
param applicationInsightsFuncName = 'app-insights-func'
param lawName = 'law-function-demo'
// Flex runtime and scale settings
param scaleAndConcurrency = {
  maximumInstanceCount: 100
  instanceMemoryMB: 2048
    // Specify alwaysReady instances for the flex consumption 
  /* alwaysReady: [
    {
      name: 'blob'
      instanceCount: 1
    }
    {
      name: 'durable'
      instanceCount: 1
    }
    {
      name: 'http'
      instanceCount: 1
    }
  ]
  triggers: {} */
}
param runtime = {
  name: 'python' // See main.bicep for other runtimes
  version: '3.11'
}
