targetScope = 'subscription'

metadata name = 'Flex Consumption Function App'
metadata description = 'Quickstart Flex Consumption Function App with private networking'
metadata owner = 'Dan @ https://rios.engineer'

@description('The name of the resource group to deploy resources into.')
param rgName string

@description('The Azure region where resources will be deployed.')
param location string

@description('The name of the private endpoint subnet.')
param peSubnetName string

@description('The address prefix for the private endpoint subnet.')
param peSubnetPrefix string

@description('The name of the integration subnet.')
param integrationSubnetName string

@description('The address prefix for the integration subnet.')
param integrationSubnetPrefix string

@description('The name of the virtual network.')
param virtualNetworkName string

@description('The address prefix for the virtual network.')
param vnetPrefix string

@description('The name of the network security group for the private endpoint subnet.')
param nsgPeName string

@description('The name of the network security group for the integration subnet.')
param nsgIntName string

@description('The name of the user-assigned managed identity.')
param umiName string

@description('The name of the Azure Key Vault.')
param keyVaultName string

@description('The name of the storage account for the function app.')
param functionStorageAccountName string

@description('The name of the blob container in the function app storage account.')
param functionStorageBlobContainerName string

@description('The name of the function app plan (App Service Plan).')
param functionAppPlanName string

@description('The name of the Azure Function App.')
param functionAppName string

@description('The name of the Application Insights resource for the function app.')
param applicationInsightsFuncName string

@description('The environment name (e.g., dev, test, prod).')
param env string

@description('The entity or business unit name.')
param entity string

@description('The workload or application name.')
param workload string

@description('The location short code for the environment (e.g., uks).')
param locationOfEnv string

@description('The scale and concurrency configuration for the function app.')
param scaleAndConcurrency object = {
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

@description('The runtime configuration for the function app. dotnet-isolated, python, java, node, powerShell')
@allowed([
  {
    name: 'python'
    version: '3.11'
  }
  {
    name: 'dotnet-isolated'
    version: '8.0'
  }
  {
    name: 'node'
    version: '20'
  }
  {
    name: 'java'
    version: '17'
  }
  {
    name: 'powerShell'
    version: '7.4'
  }
])
param runtime object = {
  name: 'python' 
  version: '3.11'
}

@description('A set of tags to apply to all resources.')
param tags object

@description('The current timestamp for resource tagging.')
param timeNow string = utcNow('yyyy-MM-ddTHH:mm')

@description('The name of the Log Analytics workspace.')
param lawName string

// MARK: Private DNS Zones
var privateDnsZones = [
  'privatelink.vaultcore.azure.net' // 0
  'privatelink.azurewebsites.net' // 1
  'privatelink.file.core.windows.net' // 2
  'privatelink.blob.core.windows.net' // 3
]

module modPrivateDnsZones 'br/public:avm/res/network/private-dns-zone:0.7.1' = [for privateDnsZone in privateDnsZones: {
  name: '${uniqueString(deployment().name, location)}-${privateDnsZone}'
  scope: resourceGroup(rgName)
  params: {
    name: privateDnsZone
    tags: union(tags, { updatedOn: timeNow })
  }
  dependsOn: [
    modResourceGroup
  ]
}]

module modResourceGroup 'br/public:avm/res/resources/resource-group:0.4.1' = {
  name: '${uniqueString(deployment().name, location)}-${rgName}'
  params: {
    name: rgName
    location: location
    tags: union(tags, { updatedOn: timeNow })
  }
}

// MARK: Key Vault
module keyVault 'br/public:avm/res/key-vault/vault:0.12.1' = {
  name: '${uniqueString(deployment().name, location)}-${keyVaultName}'
  scope: resourceGroup(rgName)
  params: {
    name: keyVaultName
    location: location
    sku: 'standard'
    enableSoftDelete: true
    enableRbacAuthorization: true
    enablePurgeProtection: true
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      ipRules: []
    }
    privateEndpoints: [
      {
        name: 'pe-${locationOfEnv}-${env}-${entity}-${workload}-vault'
        customNetworkInterfaceName: 'pe-${locationOfEnv}-${env}-${entity}-${workload}-vault-nic'
        subnetResourceId: vNet.outputs.subnetResourceIds[0]
        tags: union(tags, { createdOn: timeNow })
        service: 'vault'
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: modPrivateDnsZones[0].outputs.resourceId
            }
          ]
        }
      }
    ]
    roleAssignments: [
      {
        principalId: umi.outputs.principalId
        roleDefinitionIdOrName: 'Key Vault Secrets User'
      }
    ]
    tags: union(tags, { updatedOn: timeNow })
  }
  dependsOn: [
    modResourceGroup
  ]
}

// MARK: Virtual Network Links
module privateDNSZoneLink 'br/public:avm/ptn/network/private-link-private-dns-zones:0.4.0' = [
  for privateDnsZone in privateDnsZones: {
    name: '${uniqueString(deployment().name, location)}-${privateDnsZone}-link'
    scope: resourceGroup(rgName)
    params: {
      privateLinkPrivateDnsZones: [
        privateDnsZone
      ]
      virtualNetworkResourceIdsToLinkTo: [
        vNet.outputs.resourceId
      ]
    }
    dependsOn: [
      modResourceGroup
    ]
  }
]

// MARK: Virtual Network + Components
module nsgPe 'br/public:avm/res/network/network-security-group:0.5.1' = {
  name: '${uniqueString(deployment().name, location)}-${nsgPeName}'
  scope: resourceGroup(rgName)
  params: {
    name: nsgPeName
    location: location
    tags: union(tags, { updatedOn: timeNow })
  }
  dependsOn: [
    modResourceGroup
  ]
}

module nsgInt 'br/public:avm/res/network/network-security-group:0.5.1' = {
  name: '${uniqueString(deployment().name, location)}-${nsgIntName}'
  scope: resourceGroup(rgName)
  params: {
    name: nsgIntName
    location: location
    tags: union(tags, { updatedOn: timeNow })
  }
  dependsOn: [
    modResourceGroup
  ]
}

module vNet 'br/public:avm/res/network/virtual-network:0.6.1' = {
  name: '${uniqueString(deployment().name, location)}-${virtualNetworkName}'
  scope: resourceGroup(rgName)
  params: {
    addressPrefixes: [
      vnetPrefix
    ]
    name: virtualNetworkName
    location: location
    subnets: [
      {
        name: peSubnetName // 0
        addressPrefix: peSubnetPrefix
        networkSecurityGroupResourceId: nsgPe.outputs.resourceId
      }
      {
        name: integrationSubnetName //1
        addressPrefix: integrationSubnetPrefix
        networkSecurityGroupResourceId: nsgInt.outputs.resourceId
        delegation: 'Microsoft.App/environments' // Flex Integration delegation req
      }
    ]
    tags: union(tags, { updatedOn: timeNow })
  }
  dependsOn: [
    modResourceGroup
  ]
}

// MARK: Azure Function App + Components
// Application Insights
module law 'br/public:avm/res/operational-insights/workspace:0.11.1' = {
  name: '${uniqueString(deployment().name, location)}-${lawName}'
  scope: resourceGroup(rgName)
  params: {
    name: lawName
    dailyQuotaGb: 1
    location: location
    dataRetention: 30
    tags: union(tags, { updatedOn: timeNow })
  }
  dependsOn: [
    modResourceGroup
  ]
}

module functionAppInsights 'br/public:avm/res/insights/component:0.6.0' = {
  name: '${uniqueString(deployment().name, location)}-${applicationInsightsFuncName}'
  scope: resourceGroup(rgName)
  params: {
    name: applicationInsightsFuncName
    location: location
    kind: 'web'
    applicationType: 'web'
    workspaceResourceId: law.outputs.resourceId
    disableLocalAuth: true
    tags: union(tags, { updatedOn: timeNow })
  }
  dependsOn: [
    modResourceGroup
  ]
}

module functionStorageAccount 'br/public:avm/res/storage/storage-account:0.19.0' = {
  scope: resourceGroup(rgName)
  name: '${uniqueString(deployment().name, location)}-${functionStorageAccountName}'
  params: {
    name: functionStorageAccountName
    allowBlobPublicAccess: false
    location: location
    skuName: 'Standard_LRS'
    supportsHttpsTrafficOnly: true
    allowSharedKeyAccess: false
    managedIdentities: {
      systemAssigned: true
      userAssignedResourceIds: [
        umi.outputs.resourceId
      ]
    }
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      }
    blobServices: {
      containers: [
        {
          name: functionStorageBlobContainerName
          publicAccess: 'None'
        }
      ]
    }
    privateEndpoints: [
      {
        name: 'pe-${locationOfEnv}-${env}-${entity}-${workload}-blob'
        customNetworkInterfaceName: 'pe-${locationOfEnv}-${env}-${entity}-${workload}-blob-nic'
        subnetResourceId: vNet.outputs.subnetResourceIds[0]
        service: 'blob'
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: modPrivateDnsZones[3].outputs.resourceId
            }
          ]
        }
        tags: union(tags, { createdOn: timeNow })
      }
      {
        name: 'pe-${locationOfEnv}-${env}-${entity}-${workload}-file'
        customNetworkInterfaceName: 'pe-${locationOfEnv}-${env}-${entity}-${workload}-file-nic'
        subnetResourceId: vNet.outputs.subnetResourceIds[0]
        service: 'file'
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: modPrivateDnsZones[2].outputs.resourceId
            }
          ]
        }
        tags: union(tags, { createdOn: timeNow })
      }
    ]
    secretsExportConfiguration: {
      keyVaultResourceId: keyVault.outputs.resourceId
      connectionString1Name: 'connectionString1'
      connectionString2Name: 'connectionString2'
     }
     tags: union(tags, { updatedOn: timeNow })
  }
  dependsOn: [
    modResourceGroup
  ]
}

module umi 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = {
  name: '${uniqueString(deployment().name, location)}-${umiName}'
  scope: resourceGroup(rgName)
  params: {
    name: umiName
    tags: union(tags, { updatedOn: timeNow })
  }
  dependsOn: [
    modResourceGroup
  ]
}

module functionAppPlan 'br/public:avm/res/web/serverfarm:0.4.1' = {
  scope: resourceGroup(rgName)
  name: '${uniqueString(deployment().name, location)}-${functionAppPlanName}'
  params: {
    name: functionAppPlanName
    zoneRedundant: env == 'prd' ? true : false
    skuName: 'FC1'
    location: location
    kind: 'functionApp'
    skuCapacity: 0
    maximumElasticWorkerCount: 1
    elasticScaleEnabled: false
    perSiteScaling: false
    reserved: true
    targetWorkerCount: 0
    targetWorkerSize: 0
    tags: union(tags, { updatedOn: timeNow })
  }
  dependsOn: [
    modResourceGroup
  ]
}

module functionAppFlex 'br/public:avm/res/web/site:0.15.1' = {
  scope: resourceGroup(rgName)
  name: '${uniqueString(deployment().name, location)}-${functionAppName}'
  params: {
    name: functionAppName
    kind: 'functionapp,linux'
    serverFarmResourceId: functionAppPlan.outputs.resourceId
    location: location
    httpsOnly: true
    virtualNetworkSubnetId: vNet.outputs.subnetResourceIds[1]
    vnetRouteAllEnabled: true
    appInsightResourceId: functionAppInsights.outputs.resourceId
    keyVaultAccessIdentityResourceId: umi.outputs.resourceId
    storageAccountResourceId: functionStorageAccount.outputs.resourceId
    storageAccountUseIdentityAuthentication: true
    storageAccountRequired: true
    publicNetworkAccess: 'Enabled'
    managedIdentities: {
      systemAssigned: true
      userAssignedResourceIds: [
        umi.outputs.resourceId
      ]
    }
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobcontainer'
          value: 'https://${functionStorageAccountName}.blob.core.windows.net/${functionStorageBlobContainerName}'
          authentication: {
            type: 'systemassignedidentity'
          }
        }
      }
      scaleAndConcurrency: scaleAndConcurrency
      runtime: runtime
    }
    appSettingsKeyValuePairs: {
      APPLICATIONINSIGHTS_AUTHENTICATION_STRING: 'Authorization=AAD'
      APPLICATIONINSIGHTS_CONNECTION_STRING: functionAppInsights.outputs.connectionString
      AzureWebJobsStorage__accountName: functionStorageAccountName
    }
    siteConfig: {
      healthCheckPath: '/'
      use32BitWorkerProcess: false
      http20Enabled: true
      minTlsVersion: '1.2'
      scmSiteConfig: {
        useScmSecurity: false
        ftpsState: 'Disabled'
      }
      ipSecurityRestrictionsDefaultAction: 'Deny'
      ipSecurityRestrictions: [
        {
          ipAddress: 'any'
          action: 'deny'
          priority: 2147483647
          name: 'Deny all'
          description: 'Deny all access'
        }
      ]
      scmIpSecurityRestrictionsDefaultAction: 'Deny'
      scmIpSecurityRestrictionsUseMain: true
      scmIpSecurityRestrictions: [
        {
          ipAddress: 'any'
          action: 'deny'
          priority: 2147483647
          name: 'Deny all'
          description: 'Deny all access'
        }
      ]
    }
    privateEndpoints: [
      {
        name: 'pe-${locationOfEnv}-${env}-${entity}-${workload}-func'
        customNetworkInterfaceName: 'pe-${locationOfEnv}-${env}-${entity}-${workload}-func-nic'
        subnetResourceId: vNet.outputs.subnetResourceIds[0]
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: modPrivateDnsZones[1].outputs.resourceId
            }
          ]
        }
        tags: union(tags, { updatedOn: timeNow })
      }
    ]
    tags: union(tags, { updatedOn: timeNow })
  }
  dependsOn: [
    modResourceGroup
  ]
}

// MARK: Azure Function App RBAC 
// Needs it's own module to stop cycled dependency
// Giving the flex consumption function Storage data plane access via Managed Identity
module functionStorageRbac 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.2' = {
  scope: resourceGroup(rgName)
  name: '${uniqueString(deployment().name, location)}-${functionAppName}-st-rbac'
  params: {
    principalId: functionAppFlex.outputs.systemAssignedMIPrincipalId
    resourceId: functionStorageAccount.outputs.resourceId
    roleDefinitionId: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
    roleName: 'Storage Blob Data Contributor'
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    modResourceGroup
  ]
}

// Giving the flex consumption function Application Insights publishing access via Managed Identity
module functionAppInsightsRbac 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.2' = {
  scope: resourceGroup(rgName)
  name: '${uniqueString(deployment().name, location)}-${applicationInsightsFuncName}-rbac'
  params: {
    principalId: functionAppFlex.outputs.systemAssignedMIPrincipalId
    resourceId: functionAppInsights.outputs.resourceId
    roleDefinitionId: '3913510d-42f4-4e42-8a64-420c390055eb'
    roleName: 'Monitoring Metrics Publisher'
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    modResourceGroup
  ]
}
