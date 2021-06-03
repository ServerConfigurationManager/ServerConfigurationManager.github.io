$rootPath = Split-Path $PSScriptRoot
Write-Host "Building Docs under: $rootPath"

#region Functions
function Get-Name {
    [CmdletBinding()]
    param (
        $Ast
    )

    $registerSplat = $ast.FindAll({
        $item = $args[0]
        if ($item -isnot [System.Management.Automation.Language.AssignmentStatementAst]) { return $false }
        if ($item.Left.VariablePath.UserPath -ne 'paramRegisterScmAction') { return $false }
        
        $true
        },$true)
    @($registerSplat.Right.Expression.KeyValuePairs).Where{$_.Item1.Value -eq "Name"}.Item2.PipelineElements[0].Expression.Value
}

function Get-Parameter {
    [CmdletBinding()]
    param (
        $Ast,

        [switch]
        $Optional
    )

    $variableName = 'parametersRequired'
    if ($Optional) { $variableName = 'parametersOptional' }

    $parameters = $ast.FindAll({
        $item = $args[0]
        if ($item -isnot [System.Management.Automation.Language.AssignmentStatementAst]) { return $false }
        if ($item.Left.VariablePath.UserPath -ne $variableName) { return $false }
        
        $true
        },$true)
    $paramString = foreach ($pair in $parameters.Right.Expression.KeyValuePairs) {
        '|{0}|{1}|' -f $pair.Item1.Value, $pair.Item2.PipelineElements[0].Expression.Value
    }
    if (-not $paramString) { $paramString = '&lt;none&gt;' }
    $paramString
}
#endregion Functions

#region File Template
$actionDocTemplate = @'
# {0}

## Synopsis

{1}

## Description

{2}

## Parameters

> Mandatory

{3}

> Optional

{4}

## Errors

{5}

## Notes

|Author|{6}|
|Version|{7}|
'@
#endregion File Template

Remove-Item -Path "$rootPath/defaultactions/*"

$actions = foreach ($file in Get-ChildItem -Path "$rootPath/content/actions/" -Recurse -Filter *.ps1 -File) {
    $help = Get-Help $file.FullName
    $metaData = $help.alertSet[0].alert[0].Text | ConvertFrom-Json
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
    $name = Get-Name -Ast $ast
    $nameEscaped = $name -replace '[^\d\w]','_'
    $parametersMandatory = Get-Parameter -Ast $ast
    $parametersOptional = Get-Parameter -Ast $ast -Optional
    $errorCodes = foreach ($property in $metaData.ErrorCodes.PSObject.Properties) {
        '|{0}|{1}|' -f $property.Name, $property.Value
    }

    [pscustomobject]@{
        Name        = $name
        NameEscaped = $name -replace '[^\d\w]','_'
        Description = $help.Synopsis
        Version     = $metaData.Version
    }

    $actionText = $actionDocTemplate -f $name, $help.Synopsis, $help.Description[0].Text, ($parametersMandatory -join "`n"), ($parametersOptional -join "`n"), ($errorCodes -join "`n"), $metaData.Author, $metaData.Version
    Write-Host "  Writing docs for $name to: $rootPath/defaultactions/$nameEscaped.md"
    $actionText | Set-Content -Encoding UTF8 -Path "$rootPath/defaultactions/$nameEscaped.md"
}

$indexString = @'
# Default Actions

These actions are provided by default if you use our [sample content structure on Github](https://github.com/ServerConfigurationManager.github.io/content).

## Actions

{0}
'@
$defaultActions = foreach ($action in $actions) {
    '|[{0}](defaultactions/{1}.html)|{2}|{3}|' -f $action.Name, $action.NameEscaped, $action.Version, $action.Description
}
Write-Host "  Updating: $rootPath/default-actions.md"
$indexString -f ($defaultActions -join "`n") | Set-Content -Encoding UTF8 -Path "$rootPath/default-actions.md"