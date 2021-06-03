# Setup

## Synopsis

To install this solution, three steps are necessary:

+ Set up a PowerShell repository to reference
+ Set up a content source
+ Deploy the launcher code to the target machines

The launcher will execute whenever you want it to and bring the current machine into the desired state.
This could be a one-time thing, it could be a scheduled task running on a schedule ... whatever meets your needs, really.

The basic bootstrap workflow of this solution once set up is:

+ Execute launcher
+ Configure local packagemanagement to use the defined repository
+ Download the current version of the ServerConfigurationManager module
+ Execute the ServerConfigurationManager against the defined content source

The SCM module then uses the content source to ...

+ Determine which targets are applicable to the current machine
+ Based on targets, determine which configuration sets apply
+ For each applicable configuration setting, check whether an action is necessary and execute it if so.

## Setting up a PowerShell Repository

While you can use the public PowerShell Gallery, in many cases this is not possible for servers, as they tend to not have direct internet access.
You can host a repository in a file share or on any nuget server.

> Note: In its current state, the only supported authentication mechanism is integrated Windows authentication.
> The SCM workflow should be executed as SYSTEM, so the computer account needs to have read access to the repository.

When setting up the launcher, you will need to specify the source location path and a repository name you want to register it under.
The name is arbitrary and not something you need to configure in this step.

The repository in question may contain any PowerShell module of choice in any desired version, but must at a minimum include the ServerConfigurationManager module.

> Example: Internal Fileshare

Assuming we are in a Active Directory domain environment, we could set this repository up like this:

```powershell
# Path to the network share from where we want to provide internal PowerShell modules
$repositoryShare = '\\contoso.com\it\SCM\psrepository'

Register-PSRepository -Name contoso -SourceLocation $repositoryShare -PublishLocation $repositoryShare -InstallationPolicy trusted
Save-Module ServerConfigurationManager -Path . -Repository PSGallery
Publish-Module -Path (Get-Item .\ServerConfigurationManager\*).FullName -Repository contoso
```

This would need to be done once from an admin machine that has access to both the internet (the PowerShell Gallery specifically) and write access to the share in question.
If this cannot be done for security purposes, it is perfectly viable to execute the `Save-Module` step separately and copy the downloaded content over to the client used to setup the repository.

> Warning: The repository is security sensitive, as an attacker controlling it could control the code being executed on all machines managed by this system.

## Setting up a Content Source

The Content Source is the data repository containing ...

+ The Target code, which categorizes the computer executing them. The categories are arbitrary, could target by name, by OS type, by whatever, really. Think of Targets as something similar to WMI filters.
+ The Action code, which implements a given configuration setting type (e.g.: Ensure a folder exists, a module is installed, etc.)
+ The configuration settings, which map an Action to a Target with a given configuration (e.g.: All Servers (Target) should have a Folder (Action) named "Contoso" under "C:\" (Configuration))
+ Additional Resources, such as the required nuget binaries or other resources an Action might need to do its job.

> Continuing our example from before ...

Setting a new Content Path under `\\contoso.com\it\SCM\Content` would then look like this:

```text
\\contoso.com\it\SCM\Content
├actions
├configuration
├resources
└targets
```

When set up in a network share like this, please mind execution policy:
Depending on your settings, execution policy might interfere with executing the Action and Target code.
To resolve that, add the network share as a trusted host.

> Weblink, rather than fileshare?

A fileshare might not be convenient in all circumstances, so why not provide it as weblink?
Well, that is very much possible, but supports no special authentication protocols.

Anyway, to provide the Content via weblink, rather than share, create a zip package with content in the same layout and provide a download link to that zip file.

The disadvantage to this approach is that _all_ content must be downloaded, whether applicable or not.

> Security Concerns

In both cases make sure the write access to the Content Path is secure, as an attacker gaining control over it will gain code execution on all managed systems.

> Leaving an Audit trail

For manageability reasons, it is strongly recommended to put your Content Path into source control and deploy the content from there, in order to be able to track any changes in the desired state.

> Example? Prebuilt Actions/Targets?

In order to simplify the access we have created a [sample structure on Github](https://github.com/ServerConfigurationManager/ServerConfigurationManager.github.io/tree/master/content).
It contains a set of [pre-defined Actions](default-actions.html) to simplify getting started.

## Deploy the launcher code to the target machines

Once ready, you need to get the managed systems to run the [launcher script](https://github.com/ServerConfigurationManager/ServerConfigurationManager.github.io/blob/master/code/launcher.ps1).
In a domain environment, this could be placed in the SYSVOL share and execution deployed as a scheduled task.
Otherwise adding it to the OS image or deploying it in any other way to the machine will do.

The launcher should be executed as `SYSTEM` with elevation.

The launcher script requires three parameters:

+ RepositoryName: The name under which to register the repository SCM uses. Try to pick a unique name to avoid collision, if other solutions you use register their own repostories. In the previous example, this would have been `contoso`.
+ RepositoryPath: The source location from which to install modules. In the previous example this would have been `\\contoso.com\it\SCM\psrepository` but can also be a weblink if using a nuget repository.
+ ContentPath: The Content Path set up. In the previous example this would have been `\\contoso.com\it\SCM\Content`.

> UsePSGet

A fourth switch parameter is also supported: `-UsePSGet`:

When setting up / configuring a repository for the first time, the builtin PowerShellGet module has a tendency to hang.
To work around this, we - by default - configure it by directly manipulating / creating the configuration file backing PowerShellGet.
This has proven perfectly stable in tests so far.

If however for some reasons this does not work for you and you want to use the builtin tooling, set this parameter.

> Resources needed

In order for the launcher to complete successfully, it will deploy the nuget binaries if needed.
If they haven't been deployed yet, it will search the Content Path for a `resources/nuget` folder and copy it over.
This folder should have a subfolder named after its version (e.g. `2.8.5.208`) which contains the needed nuget binaries (`Microsoft.PackageManagement.NuGetProvider.dll`).
