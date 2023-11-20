#!/usr/bin/env bash

# Text formatting
declare red=`tput setaf 1`
declare bold=`tput bold`
declare newline=$'\n'

# Element styling
declare errorStyle="${red}${bold}"

if [ -z "$1" ]; then
  echo "${newline}${errorStyle}ERROR, please define a display name.${defaultTextStyle}${newline}"
  echo "i.e $ "$0" displayName${newline}"
  exit 1
fi

displayName="$1"

# AZ CLI check
echo "${newline}Making sure you're signed in to Azure CLI..."
az account show -o none
echo "${newline}"

if [ ! $? -eq 0 ]
then
    exit 1
fi

echo "Using the following Azure subscription. If this isn't correct, press Ctrl+C and select the correct subscription with \"az account set\""
echo "${newline}"
az account show -o table
echo "${newline}"

echo "${newline}Getting credentials from signed in user...${newline}"
azureSubscriptionId=$(az account show --query "id" --output tsv)

az account set -s $azureSubscriptionId

# Create an Microsoft Entra ID User

# check for existing user first
userObjectId=$(az ad user list --display-name ${displayName} --query "[].id" --output tsv)

if [ ! -z "$userObjectId" ]
then
  echo "${newline}${errorStyle}User '${displayName}' already exists, exiting.${newline}${errorStyle}"
  exit 1
fi

primaryDomain=$(az rest --method get --url 'https://graph.microsoft.com/v1.0/domains?$select=id' | jq -r '.value[0].id')
# primaryDomain="mpflynnx01outlook.onmicrosoft.com"

# build user-principal-name
userPrincipalName="$displayName@$primaryDomain"

# generate an initial password, user will be forced to change this
initialPasswd=$(</dev/urandom tr -dc '12345!@#$%qwertQWERTasdfgASDFGzxcvbZXCVB' | head -c8; echo "")
# initialPasswd="passWorD1!"

echo "${newline}Creating new Microsoft Entra ID User..."
if [ -z "$userObjectId" ]
then
  az ad user create \
    --display-name $displayName \
    --password $initialPasswd \
    --user-principal-name $userPrincipalName \
    --force-change-password-next-sign-in \
    --output none

  if [ ! $? -eq 0 ]
  then
    echo "${newline}${errorStyle}ERROR creating new user, exiting.${defaultTextStyle}${newline}"
    exit1
  fi

# Get ObjectId of the User
echo "${newline}User created."

  
fi

# Get ObjectId of the User
userObjectId=$(az ad user list --display-name ${displayName} --query "[].id" --output tsv)

echo "${newline}Object ID: ${userObjectId}${newline}"

# Add role to new user
echo "${newline}Adding new role assignment..."
roleName="Contributor"
if [ ! -z "userObjectId" ]
then
  az role assignment create \
    --assignee-object-id ${userObjectId} \
    --assignee-principal-type User \
    --role ${roleName} \
    --scope /subscriptions/${azureSubscriptionId} \
    --output none

  if [ ! $? -eq 0 ]
  then
    echo "${newline}${errorStyle}ERROR adding role to User, exiting.${defaultTextStyle}${newline}"
    # delete User
    az ad user delete --id ${userObjectId}
    exit1
  fi

  echo "${newline}Role '$roleName' added successfully.${newline}"
 
fi

# Add role to new user
echo "${newline}Adding new role assignment..."
roleName="Role Based Access Control Administrator"
if [ ! -z "userObjectId" ]
then
  az role assignment create \
    --assignee-object-id ${userObjectId} \
    --assignee-principal-type User \
    --role "${roleName}" \
    --scope /subscriptions/${azureSubscriptionId} \
    --output none

  if [ ! $? -eq 0 ]
  then
    echo "${newline}${errorStyle}ERROR adding role to User, exiting.${defaultTextStyle}${newline}"
    # delete User
    az ad user delete --id ${userObjectId}
    exit1
  fi

  echo "${newline}Role '$roleName' added successfully.${newline}"
 
fi

# list roles
echo "${newline}User role assignments:-"
az role assignment list --assignee ${userObjectId} --query "[].roleDefinitionName" --output tsv
echo "${newline}"
