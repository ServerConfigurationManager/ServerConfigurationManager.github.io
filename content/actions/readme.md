# Actions

This folder should contain ps1 files, each defining an Action taken.
Actions are configured to bring the Target into a desired state.
This desired state might be a specific module being installed, a JEA endpoint being deployed or whatever else might be needed.

An Action is defined by the following properties:

+ Name: A unique name
+ Description: A proper description, covering what it does.
+ Parameters: A list of parameters required to tell the Action what to do.
+ TestScript: A scriptblock, that given parameters will validate, whether they are deployed correctly.
+ ActionScript: A scriptblock, that given parameters will bring the computer into the desired state.

## Template

Each template should follow this layout in order to enable automatic documentation generation.

```powershell
<#
.SYNOPSIS
    ENTER SYNOPSIS

.DESCRIPTION
    ENTER DESCRIPTION

.NOTES
    {
        "Author": "Friedrich Weinmann",
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
