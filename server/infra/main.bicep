@description('Environment name (dev or prod)')
@allowed(['dev', 'prod'])
param environment string = 'dev'

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('PostgreSQL admin password')
@secure()
param postgresAdminPassword string

var prefix = 'sheetshow-${environment}'
var acrName = replace('${prefix}acr', '-', '')

// Azure Container Registry
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: { name: 'Basic' }
  properties: { adminUserEnabled: true }
}

// Container Apps Environment
resource containerAppsEnv 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: '${prefix}-env'
  location: location
  properties: {}
}

// Container App
resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: '${prefix}-api'
  location: location
  properties: {
    managedEnvironmentId: containerAppsEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 80
      }
      registries: [
        {
          server: acr.properties.loginServer
          username: acr.listCredentials().username
          passwordSecretRef: 'acr-password'
        }
      ]
      secrets: [
        {
          name: 'acr-password'
          value: acr.listCredentials().passwords[0].value
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'api'
          image: '${acr.properties.loginServer}/${prefix}-api:latest'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
        }
      ]
    }
  }
}

// PostgreSQL Flexible Server
resource postgres 'Microsoft.DBforPostgreSQL/flexibleServers@2023-06-01-preview' = {
  name: '${prefix}-postgres'
  location: location
  sku: {
    name: 'Standard_B2ms'
    tier: 'Burstable'
  }
  properties: {
    administratorLogin: 'sheetshow_admin'
    administratorLoginPassword: postgresAdminPassword
    version: '16'
    storage: { storageSizeGB: 32 }
    backup: { backupRetentionDays: 7, geoRedundantBackup: 'Disabled' }
    highAvailability: { mode: 'Disabled' }
  }
}

// Storage Account for PDFs
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: replace('${prefix}storage', '-', '')
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

resource scoresContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'scores'
  properties: { publicAccess: 'None' }
}

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: '${prefix}-kv'
  location: location
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    softDeleteRetentionInDays: 90
  }
}

output acrLoginServer string = acr.properties.loginServer
output containerAppUrl string = containerApp.properties.configuration.ingress!.fqdn
output postgresHost string = postgres.properties.fullyQualifiedDomainName
