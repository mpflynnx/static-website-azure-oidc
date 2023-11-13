#!/usr/bin/env bash

# Text formatting
declare red=`tput setaf 1`
declare bold=`tput bold`
declare newline=$'\n'

# Element styling
declare errorStyle="${red}${bold}"

# Get from environment variable
resourceGroup=${RESOURCE_GROUP}

# Check resourceGroup variable has a value
if [ -z "$resourceGroup" ]
then
  echo "${newline}${errorStyle}ERROR: RESOURCE_GROUP not defined as environment variable.${defaultTextStyle}${newline}"
  exit 1
fi

appName=$(gh repo view --json name -q ".name")
clientId=$(az ad app list --display-name ${appName} --query "[].appId" --output tsv)

# Microsoft Entra application check
if [ -z "$clientId" ]
then
  echo "${newline}${errorStyle}ERROR: Client Id not defined, have you run azure-oidc-setup.sh?.${defaultTextStyle}${newline}"
  exit 1
fi

echo
echo "Getting credentials from signed in user...."
echo

azureTenantId=$(az account show --query "tenantId" --output tsv)

if [ -z "$azureTenantId" ]
then
  echo "${newline}${errorStyle}ERROR: Tenant ID not found!${defaultTextStyle}${newline}"
  exit 1
fi

azureSubscriptionId=$(az account show --query "id" --output tsv)

if [ -z "$azureSubscriptionId" ]
then
  echo "${newline}${errorStyle}ERROR: Subscription ID not found!${defaultTextStyle}${newline}"
  exit 1
fi

echo
echo "Getting resource names from Azure resource group...."
echo

storageAccountName=$(az storage account list --resource-group ${resourceGroup} --query "[].name" --output tsv)

if [ -z "$storageAccountName" ]
then
  echo "${newline}${errorStyle}ERROR: Storage account not found!${defaultTextStyle}${newline}"
  exit 1
fi

cdnProfileName=$(az afd profile list --resource-group ${resourceGroup} --query "[].name" --output tsv)

if [ -z "$cdnProfileName" ]
then
  echo "${newline}${errorStyle}ERROR:  Azure Front Door profile not found!${defaultTextStyle}${newline}"
  exit 1
fi

cdnEndpoint=$(az afd endpoint list --resource-group ${resourceGroup} --profile-name ${cdnProfileName} --query "[].name" --output tsv)

if [ -z "$cdnEndpoint" ]
then
  echo "${newline}${errorStyle}ERROR: Azure Front Door endpoint not found!${defaultTextStyle}${newline}"
  exit 1
fi

# Use Heredoc to create a .env file
cat > ".env" << EOF
AZURE_CLIENT_ID=${clientId}
AZURE_TENANT_ID=${azureTenantId}
AZURE_SUBSCRIPTION_ID=${azureSubscriptionId}
STORAGE_ACCOUNT_NAME=${storageAccountName}
CDN_PROFILE_NAME=${cdnProfileName}
CDN_ENDPOINT=${cdnEndpoint}
RESOURCE_GROUP=${resourceGroup}
EOF

# Set multiple secrets imported from the ".env" file must make sure
# .env is not part of VCS i.e .gitignore
echo
echo "Adding repository GitHub secrets to be referenced in your workflow...."
echo
gh secret set -f .env
echo

echo "--- Cleaning up ..."
  rm .env 2>/dev/null
