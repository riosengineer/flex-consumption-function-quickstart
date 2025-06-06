# ⚡Azure Function - Flex Consumption Private Networking Quickstart Bicep Template 💪

This repository contains a Bicep template, written entirely with Azure Verified Modules public registry modules to demo / boiler plate a template to demo Azure Function - Consumption Plan with private networking. 

> **💡 Note:**  
> The `Microsoft.App` resource provider must be registered in your Azure subscription **before** deploying.
>  
> You can register it using the Azure CLI:  
> 
> ```bash
> az provider register --namespace Microsoft.App
> ```

The Bicep template will deploy: 

- Resource Group which will contain:
- Function App & App Service (Flex Consumption) Plan
- Application Insights & Log Analytics Workspace
- Storage Account (to host the deployment runtime)
- Virtual Network with subnets
- Network Security Groups 
- Private DNS Zone(s)

The function is connected to storage through managed identity and RBAC. In addition, Application Insights is also connected via Entra ID only with RBAC.

> [!NOTE]  
> This is a demo / boilerplate quickstart template to show off Function Flex Consumption with private networking. I would not recommend you use Private DNS Zones like this directly in the resource group of your application. Use existing resource to point to your hub where your DNS Zones should be located.

## 📃 Benefits of Flex Consumption 

- ✅ Can scale to zero.
- ✅ Private networking and virtual network integration.
- ✅ Can scale up to 1000 instances, very quickly.
- ✅ AlwaysOn capability so you do not suffer from cold start issues.
- ✅ Supports managed identity connections for full platform functionality.

What it can't do (right now): Deployment Slots & Key Vault/App Config access via App Settings (only possible directly via code calls).

Read more about Flex Consumtpion here: https://learn.microsoft.com/en-gb/azure/azure-functions/flex-consumption-plan

## 🚀 Deploy

Set your `main.bicepparam` to your desired values and save.

```bash
az login
az deployment sub create -l <region> -f bicep/main.bicep -p bicep/main.bicepparam
```