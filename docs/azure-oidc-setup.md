
## Azure OIDC setup

### Why use OpenId Connect (OIDC)

I have chosen to use OIDC, over the use a Service principal along with a repository secret to reduce creating credentials in Azure then duplicating them in GitHub as a long-lived secret.

OpenID Connect means the GitHub Action workflow can request a short-lived access token directly from Azure. The Token is only valid for a single job then expires automatically.

In Azure, we create an OIDC trust between a Microsoft Entra applications service principal and the GitHub workflow.

### Bash script

I have created a bash script [azure-oidc-setup.sh](../bin/azure-oidc-setup.sh) to automate the many steps needed in setting up OIDC. The script dynamically builds local variables and retrieves values for these from the Azure signed in users subscription and the GitHub repository. Therefore the script depends on Azure CLI and GitHub CLI being installed and ready for use. I recommend using Gitpod along with this repository. I have created a '.gitpod.yml' file  in this repository that will install both Azure CLI and GitHUb CLI in the Gitpod cloud development environment. For instructions on how to use Gitpod refer to document [Gitpod Development Environment](gitpod-development-environment.md). 

### Review of the azure-oidc-setup.sh bash script

Firstly I need to check that one of the scripts dependencies, Azure CLI is available. 

I use the [az account show](https://learn.microsoft.com/en-us/cli/azure/account?view=azure-cli-latest#az-account-show) command with an output parameter set to none. If this command returns an error it means that Azure CLI is not available and the script will exit.

```bash
## ...

# AZ CLI check
echo "Making sure you're signed in to Azure CLI..."
az account show -o none

if [ ! $? -eq 0 ]
then
    exit 1
fi

## ...

```

Then, I get the default subscription of the signed in user by using the [az account show](https://learn.microsoft.com/en-us/cli/azure/account?view=azure-cli-latest#az-account-show) command with an output parameter set to table. 

```bash
## ...

az account show -o table

## ...

```

Then, I check that another of the scripts dependencies, GitHub CLI is available.

I use the [gh auth status](https://cli.github.com/manual/gh_auth_status). If this command returns an error it means that GitHub CLI is not available and the script will exit.

```bash
## ...

# GitHub CLI check
echo "Making sure you're signed in to GitHub CLI..."
gh auth status

if [ ! $? -eq 0 ]
then
    exit 1
fi

## ...

```

I then use the [gh repo show](https://cli.github.com/manual/gh_repo_view) GitHub CLI command to assign a value to local variables 'owner' and 'appName'. These variables will be used to create the trust link with GitHub repository later.

appName will also be used as the name of the Microsoft Entra application.

```bash
## ...

owner=$(gh repo view --json owner -q ".owner.login")

appName=$(gh repo view --json name -q ".name")

## ...

```

Then, I need to check that the Microsoft Entra application doesn't already exist in Azure, by using the Azure CLI command [az ad app list](https://learn.microsoft.com/en-us/cli/azure/ad/app?view=azure-cli-latest#az-ad-app-list).

I assign the output of the command to a local variable 'clientId'.

If the 'clientId' variable has a value that means the application exists, and the script exits.

```bash
## ...

# check for existing app first
clientId=$(az ad app list --display-name ${appName} --query "[].appId" --output tsv)

if [ ! -z "$clientId" ]
then
  echo "Application ${appName} already exists, exiting."
  exit 1
fi

## ...

```

Continuing on. The application doesn't exist, so I create a new application using the [az ad app create](https://learn.microsoft.com/en-us/cli/azure/ad/app?view=azure-cli-latest#az-ad-app-create) command and pass in the local variable 'appName' as the display name.


```bash
## ...

az ad app create --display-name ${appName}

## ...
```

I now need to retrieve the Application (client) ID of the new application. I will need to use the client ID again, so I will assign the output of command [az ad app list](https://learn.microsoft.com/en-us/cli/azure/ad/app?view=azure-cli-latest#az-ad-app-list) to a local variable 'clientId'.

```bash
## ...

clientId=$(az ad app list --display-name ${appName} --query "[].appId" --output tsv)

## ...
```

Then, I check that the variable 'clientId' has a value. That means the application has successfully been created. I can then use the 'clientId' variable value to create a new Service principal using command [az ad sp create](https://learn.microsoft.com/en-us/cli/azure/ad/sp?view=azure-cli-latest#az-ad-sp-create). If the command returns an error the script exits.

```bash
## ...

echo "Creating new Service principal ...."
if [ ! -z "$clientId" ]
then
  az ad sp create --id ${clientId}

  if [ ! $? -eq 0 ]
  then
    echo "${newline}${errorStyle}ERROR creating Service principal!${defaultTextStyle}${newline}"
    exit 1
  fi

  echo "Service principal Created."

fi

## ...
```

I then need to assign a role to the Service principal. As the GitHub workflow is used to purge the CDN, the least privileged role for this is 'Contributor'. 

To assign a role, I need to provide the Object ID of the Service principal. I use the command [az ad sp list](https://learn.microsoft.com/en-us/cli/azure/ad/sp?view=azure-cli-latest#az-ad-sp-list) and assign the output to a new local variable 'spObjectId'.

```bash
## ...

spObjectId=$(az ad sp list --display-name ${appName} --query "[].id" --output tsv)

## ...
```

I can then assign the role using command [az role assignment create](https://learn.microsoft.com/en-us/cli/azure/role/assignment?view=azure-cli-latest#az-role-assignment-create).

```bash
## ...

if [ ! -z "spObjectId" ]
then
  az role assignment create \
    --role "Contributor" \
    --subscription ${azureSubscriptionId} \
    --assignee-object-id ${spObjectId} \
    --assignee-principal-type ServicePrincipal \
    --output none
fi

## ...
```

Finally, I can [configure the application to trust the GitHub repository](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation-create-trust?pivots=identity-wif-apps-methods-azcli) by 
adding federated credentials. This credential creates the trust relationship with the Microsoft Entra application and the GitHub Action workflow.

I use command [az ad app list](https://learn.microsoft.com/en-us/cli/azure/ad/app?view=azure-cli-latest#az-ad-app-list) again, but this time I want to return the Applications Object ID (id) not the Application (client) ID (appId). I assign the output to a local variable 'appObjectId'.

```bash
## ...

appObjectId=$(az ad app list --display-name ${appName} --query "[].id" --output tsv)

## ...
```

Before adding the credential, I need to create a credential.json file. I use heredoc string literals for readability.

The credential.json file contains several important pieces of information.

"name" this is the unique identifier for the federated identity credential and is required. I use the appName variable value which, in my case is the repository name and the application name.

"issuer" and "subject" are the key pieces of information needed to set up the trust relationship. The combination of issuer and subject must be unique on the app. When the external software workload requests Microsoft identity platform to exchange the external token for an access token, the issuer and subject values of the federated identity credential are checked against the issuer and subject claims provided in the external token. If that validation check passes, Microsoft identity platform issues an access token to the external software workload

"issuer" is the URL of the external identity provider, in our case it's the path to the GitHub OIDC provider: https://token.actions.githubusercontent.com 

"subject" identifies the GitHub organisation, repo, and ref path for your GitHub Actions workflow. I used GitHub CLI earlier to create local variables 'owner' and 'appName' which I use now to build up the subject string. 

I then need to add the ref path for branch/tag based on the ref path used for triggering the workflow. In my case I am triggering the workflow on a push to main branch so I use ref:refs/heads/main.

"description" is a user-provided description of the federated identity credential and is optional. I just use the variable 'appName' value. 

"audiences" lists the audiences that can appear in the external token. This is required. The recommended value is "api://AzureADTokenExchange". It says what Microsoft identity platform must accept in the aud claim in the incoming token.

```bash
## ...
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
## ...
```

I check that the variable 'appObjectId' is not empty. Then I use the command [az ad app federated-credential create](https://learn.microsoft.com/en-us/cli/azure/ad/app/federated-credential?view=azure-cli-latest#az-ad-app-federated-credential-create). The id parameter specifies the object ID of the application, not to be confused with the Application (client) ID or the Service principal Object ID. I pass the credential.json file path as the value of the parameters.

```bash
## ...

if [ ! -z "appObjectId" ]
then
  az ad app federated-credential create --id ${appObjectId} --parameters credential.json
fi

## ...
```

To finish off, I delete the credential.json file created earlier.

```bash
## ...
echo "--- Cleaning up ..."
  rm credential.json 2>/dev/null
## ...
```
