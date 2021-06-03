# Jea Endpoint

## Synopsis

Deploys and configures a JEA endpoint on the local computer.

## Description

This Action will prepare and configure a JEA endpoint.
Note: Executing either a fresh deployment or an update will cause a reboot of the local WinRM service.

This action only supports basic JEA endpoints, not advanced JEA endpoints.
Characteristics of basic endpoints:

- No support for Side-by-Side module installation of different versions
- Unable to specify Role Capabilities by path, only by name
- Deployed using file copy
- Groups allowed to access the endpoint are hardcoded into the JEA module text

In order to successfully deploy a JEA Endpoint, the source path must be available.
This Action will look for the source in the following location:

```text
<ContentPath>\resources\JEA\<Name>\<Version>
```

Assuming "ContentPath" being "\\server\ScmContent" and we want to deploy version 1.0.3 of the endpoint "JEA_CimAccess" that would be:

```text
\\server\ScmContent\resources\JEA\JEA_CimAccess\1.0.3\
```

Once the files have been transfered, it will try to register the endpoint by calling `Register-JeaEndpoint_<name>` .
In case of the previous example, that would be `Register-JeaEndpoint_JEA_CimAccess` .
The JEA module _must_ provide this command, otherwise deployment is impossible.

> Note: To generate JEA endpoint modules that adhere to this format, use the PowerShell module JEAnalyzer

Example JEAnalyzer code to generate the sample resource:

```powershell
$module = New-JeaModule -Name CimAccess -Author 'Friedrich Weinmann' -Company 'Contoso Ltd.' -Description 'JEA Endpoint exposing WMI/CIM capabilities'
'New-CimInstance', 'Invoke-CimMethod', 'Remove-CimInstance', 'Set-CimInstance' | New-JeaRole -Name CimWrite -Identity 'contoso\JEA-WmiAccess-Write' -Module $module
'Get-CimInstance', 'Get-CimClass', 'Get-CimAssociatedInstance' | New-JeaRole -Name CimRead -Identity 'contoso\JEA-WmiAccess-Read' -Module $module
$module | Export-JeaModule -Path . -Basic
```

## Parameters

> Mandatory

|Name|Name of the JEA endpoint to deploy|

> Optional

|MinimumVersion|The minimum version required. Will always update to latest if not specified.|
|MaximumVersion|The maximum version deployed. Will not update beyond this version.|

## Errors

|400|Written when not successful cleaning up a previous version of the JEA Endpoint module. It might be in use.|
|401|Failed to copy the necessary JEA Endpoint module files from the Content Path to the local modules folder under Program Files.|
|402|Failed to unregister a previous JEA Session configuration. This would generally imply technical issues with the WinRM service.|
|403|Failed to register the new JEA Session configuration. This could happen if the JEA Endpoint module is not properly built, such as lacking the needed register command. Another potential issue is when assigned identities/groups permitted to connect do not exist in reality.|
|404|Written when there is no viable JEA Endpoint source. For example if no JEA module has been provided in resources or the maximum version is lower than the available versions|
|405|Written when unable to start the WinRM service after deploying the JEA Endpoint, manual intervention necessary!|

## Notes

|Author|Friedrich Weinmann|
|Version|1.0.0|
