#!/usr/bin/env bash

declare newline=$'\n'

# AZ CLI check
echo "Making sure you're signed in to Azure CLI..."
az account show -o none

if [ ! $? -eq 0 ]
then
    exit 1
fi

echo "Using the following Azure subscription. If this isn't correct, press Ctrl+C and select the correct subscription with \"az account set\""
echo "${newline}"
az account show -o table
echo "${newline}"

# GitHub CLI check
echo "Making sure you're signed in to GitHub CLI..."
gh auth status

if [ ! $? -eq 0 ]
then
    exit 1
fi

owner=$(gh repo view --json owner -q ".owner.login")

# Repository name is the appName!
appName=$(gh repo view --json name -q ".name")

echo
echo "Getting credentials from signed in user...."
echo
azureSubscriptionId=$(az account show --query "id" --output tsv)

# is this really required?
az account set -s $azureSubscriptionId

# check for existing app first
clientId=$(az ad app list --display-name ${appName} --query "[].appId" --output tsv)

if [ ! -z "$clientId" ]
then
  echo "Application ${appName} already exists, exiting."
  exit 1
fi

# Create a Microsoft Entra application.
echo "Creating new Microsoft Entra application ...."
az ad app create --display-name ${appName}
clientId=$(az ad app list --display-name ${appName} --query "[].appId" --output tsv)
echo "Application Created."

# Create new Service principal
echo "Creating new Service principal ...."
if [ ! -z "$clientId" ]
then
  az ad sp create --id ${clientId}
fi

# Get ObjectId of the Service principal
spObjectId=$(az ad sp list --display-name ${appName} --query "[].id" --output tsv)

# Add role assignment
# not working with --scope as of November 2023
if [ ! -z "spObjectId" ]
then
  az role assignment create \
    --role "Contributor" \
    --subscription ${azureSubscriptionId} \
    --assignee-object-id ${spObjectId} \
    --assignee-principal-type ServicePrincipal \
    --output none
fi

# Create a new federated identity credential
# Needs object id of the app registration not service principal
appObjectId=$(az ad app list --display-name ${appName} --query "[].id" --output tsv)

# Create credential.json using Heredoc
cat > "credential.json" << EOF
{
    "name": "${appName}",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:${owner}/${appName}:ref:refs/heads/main",
    "description": "${appName}",
    "audiences": [
        "api://AzureADTokenExchange"
    ]
}
EOF

echo "Adding federated credentials...."
if [ ! -z "appObjectId" ]
then
  az ad app federated-credential create --id ${appObjectId} --parameters credential.json
fi

echo "--- Cleaning up ..."
  rm credential.json 2>/dev/null