## Gitpod development platform

This project can utilise the [Gitpod](https://www.gitpod.io/) development platform.

Gitpod is an open-source developer platform automating the provisioning of ready-to-code developer environments. [Try for free](https://gitpod.io/login/)

Install the [Gitpod extension](https://chrome.google.com/webstore/detail/gitpod/dodmmooeoklaejobgleioelladacbeki) into your Chrome or Microsoft Edge browser. This extension adds a button to your GitHub repository to easily spin up a dev environment with a single click for the selected branch.

### .gitpod.yml

The development environment is built for the project by defining tasks in the [.gitpod.yml](.gitpod.yml) configuration file at the root of the project.

I configure this file to execute two bash scripts which in turn install applications [GitHub CLI](https://cli.github.com/) and [Azure CLI](https://learn.microsoft.com/en-gb/cli/azure/what-is-azure-cli).

With Gitpod, you have the following three types of [tasks](https://www.gitpod.io/docs/configure/workspaces/tasks):

### Execution order

- before: Use this for tasks that need to run before init and before command. For example, customize the terminal or install global project dependencies.
- init: Use this for heavy-lifting tasks such as downloading dependencies or compiling source code.
- command: Use this to start a database or development server.

### Wait for commands to complete

When working with multiple terminals, you may have a situation where terminal 1 runs build scripts and terminal 2 and 3 require that these scripts complete first. This can be achieved with gp sync-await and gp sync-done.

As I have multiple scripts using the apt package manager. apt creates a lock file while it's in use, therefore any other scripts using apt will fail.

I want the install-gh-cli.sh bash script to finish before any other scripts are run. To achieve this I used the [gp sync-done](https://www.gitpod.io/docs/references/gitpod-cli#sync-done) command after install-gh-cli.sh is run.


```yaml
gp sync-done gh-cli
```
I then used [gp sync-await](https://www.gitpod.io/docs/references/gitpod-cli#sync-await) command before running any other scripts.

```yaml
gp sync-await gh-cli
```

### Restart a Workspace
When you restart a workspace, Gitpod already executed the init task either as part of a Prebuild or when you started the workspace for the first time. The init task will not be
run when the workspace is restarted. Gitpod executes the before and command tasks on restarts. **It is recommended to use the before task not the init task.**

## Azure CLI

The Azure Command-Line Interface (CLI) is a cross-platform command-line tool to connect to Azure and execute administrative commands on Azure resources. It allows the execution of commands through a terminal using interactive command-line prompts or a script.[<sup>[5]</sup>](#external-references)

### Azure users
Upon sign up completion of a new Azure account, you have the "Owner" and "User Access Administrator" roles for the subscription. For development, is it best practice to create a new user and assign less privileged roles. 

I have created a [bash script]() which will create a new user with the "Contributor" and "Role Based Access Control Administrator" roles to the subscription. Which for this and most projects should be sufficient.

To execute the script you must be logged in to the Azure CLI terminal using the first user account.

Enter the Azure CLI terminal.

Login using the [az login](https://learn.microsoft.com/en-us/cli/azure/authenticate-azure-cli-interactively) command.

```bash
az login --use-device-code 
```
You will need to copy the code given into the newly opened browser tab. Then sign in with your username and password.

At the terminal prompt enter the path to the script followed by a name for the user. In the below example the name give is "developer1".

```bash
./bin/new-azure-user.sh developer1
```

Upon the scripts completion a new user "developer1" will be created. Make a note of the login and the password.

Logout of the first Azure account.

```bash
az logout
```

Login as the new user.

```bash
az login --use-device-code 
```
You will need to copy the code given into the newly opened browser tab. Then sign in with the login details of user "developer1".

If it is the first time you have logged in, you will be prompted to change the password and setup two factor authentication.

You are now signed in as the user "developer1".
