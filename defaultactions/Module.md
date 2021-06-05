# Module

## Synopsis

Ensures a specified module is installed on the target server.

## Description

Ensures a specified module is installed on the target server.
Includes all dependencies if existing.
Installs the modules from the default SCM repository.

## Parameters

> Mandatory

|Name|Name of the module to ensure exists. No wildcards.|

> Optional

|MinimumVersion|At least this version must exist on the local computer.|
|MaximumVersion|A version no greater than this must exist on the local computer. Will not uninstall later versions!|

## Errors

|400|Invalid Parameter: MinimumVersion. Happens when you provide bad data to the MinimumVersion parameter. Only traditional version numbers supported!|
|401|Invalid Parameter: MaximumVersion. Happens when you provide bad data to the MaximumVersion parameter. Only traditional version numbers supported!|
|402|Error searching repository. Happens when for some reason the configured PowerShell repository cannot be accessed, includes error why exactly.|
|403|No applicable module found. This error happens when no version of the module in the repository meets the filter criteria. Check the configuration and make sure the targeted module is correctly published on the repository.|
|404|Error installing from the repository. Happens when for some reason the configured PowerShell repository cannot be accessed, includes error why exactly.|

## Notes

|Author|Friedrich Weinmann|
|Version|1.0.0|
