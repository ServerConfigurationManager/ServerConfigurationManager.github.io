# Actions

## Description

Actions are the implementing logic of the Server Configuration Manager.
Actions are configured to bring the Target into a desired state.
This desired state might be a specific module being installed, a JEA endpoint being deployed or whatever else might be needed.

An Action is defined by the following properties:

+ Name: A unique name
+ Description: A proper description, covering what it does.
+ Parameters: A list of parameters required to tell the Action what to do.
+ TestScript: A scriptblock, that given parameters will validate, whether they are deployed correctly.
+ ActionScript: A scriptblock, that given parameters will bring the computer into the desired state.

## Design Guidance

Actions are processed in the following order:

+ Test Script (Do I need to do anything?)
+ Execution Script (Do it)
+ Test Script (Was I successful?)

Neither the test script nor the execution script should throw exceptions, but are strongly encourage to implement [Logging](logging.html).
Both scriptblocks receive a single argument - a hashtable with four properties:

+ Parameters: A hashtable (within the argument hashtable) containing the parameters specified in the configuration
+ ContentPath: The filesystem path to the root folder of the overall content. If the originally provided Content Path was a weblink, it will point at the temporary local folder that the launcher script stored it in.
+ Repository: The name of the SCM repository. Use this if you need to install / update additional PowerShell modules.
+ ConfigurationName: The name of the configuration setting that triggered this action. Use this for logging purposes.

## Placement

Each action file should be published to the `actions` subfolder of the Content Path.
For example, an action to create a folder would be place under `<ContentPath>/actions/Folder.action.ps1`.

> The actual filename is not relevant.

## Template

Each template should roughly follow this layout:

```powershell
<#
.SYNOPSIS
    ENTER SYNOPSIS

.DESCRIPTION
    ENTER DESCRIPTION

.NOTES
    {
        "Author": "<author>",
        "Version": "1.0.0",
        "ErrorCodes": {
            "<code>": "<description>"
        }
    }
#>

$validationCode = {
    param ($Parameters)

    $parameterHash = $Parameters.Parameters
    $contentPath = $Parameters.ContentPath
    $repositoryName = $Parameters.Repository
    $configName = $parameters.ConfigurationName

}

$executionCode = {
    param ($Parameters)

    $parameterHash = $Parameters.Parameters
    $contentPath = $Parameters.ContentPath
    $repositoryName = $Parameters.Repository
    $configName = $parameters.ConfigurationName

}

$parametersRequired = @{
    
}
$parametersOptional = @{

}

$paramRegisterScmAction = @{
    Name               = 'INSERT NAME'
    Description        = 'INSERT DESCRIPTION'
    ParametersRequired = $parametersRequired
    ParametersOptional = $parametersOptional
    Validation         = $validationCode
    Execution          = $executionCode
}

Register-ScmAction @paramRegisterScmAction
```
