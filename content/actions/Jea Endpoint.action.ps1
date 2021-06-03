<#
.SYNOPSIS
    Deploys and configures a JEA endpoint on the local computer.

.DESCRIPTION
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

.NOTES
    {
        "Author": "Friedrich Weinmann",
        "Version": "1.0.0",
        "ErrorCodes": {
            "400": "Written when not successful cleaning up a previous version of the JEA Endpoint module. It might be in use.",
            "401": "Failed to copy the necessary JEA Endpoint module files from the Content Path to the local modules folder under Program Files.",
            "402": "Failed to unregister a previous JEA Session configuration. This would generally imply technical issues with the WinRM service.",
            "403": "Failed to register the new JEA Session configuration. This could happen if the JEA Endpoint module is not properly built, such as lacking the needed register command. Another potential issue is when assigned identities/groups permitted to connect do not exist in reality.",
            "404": "Written when there is no viable JEA Endpoint source. For example if no JEA module has been provided in resources or the maximum version is lower than the available versions",
            "405": "Written when unable to start the WinRM service after deploying the JEA Endpoint, manual intervention necessary!"
        }
    }
#>

$validationCode = {
    param ($Parameters)

    $parameterHash = $Parameters.Parameters
    $contentPath = $Parameters.ContentPath
    $jeaName = $parameterHash.Name

    # Test if module has been deployed
    $moduleFolder = "$([Environment]::GetFolderPath('ProgramFiles'))\WindowsPowerShell\Modules\$($jeaName)"
    $manifestFile = Join-Path -Path $moduleFolder -ChildPath "$($jeaName).psd1"
    if (-not (Test-Path $manifestFile)) { return $false }

    #region Check Version Constraint of deployed endpoint
    $minVersion = $parameterHash.MinimumVersion -as [version] # null if bad syntax or empty
    $maxVersion = $parameterHash.MaximumVersion -as [version] # null if bad syntax or empty

    try { $sessionCfg = Get-PSSessionConfiguration -Name $jeaName -ErrorAction Stop }
    catch { return $false }
    if ($sessionCfg.Description -notmatch "^\[$jeaName (?<version>[\d\.]+?)\]") {
        return $false
    }
    $endpointVersion = $matches.version -as [version]
    if (-not $endpointVersion) { return $false }
    if ($minVersion -and $endpointVersion -lt $minVersion) { return $false }
    if ($maxVersion -and $endpointVersion -gt $maxVersion) { return $false }

    # If min Version is specified and we meet the requirement, no further test needed - don't need to update to latest version
    if ($minVersion) { return $true }
    #endregion Check Version Constraint of deployed endpoint
    
    #region Check for Version Update
    $jeaContentRoot = Join-Path -Path $contentPath -ChildPath "resources\JEA\$jeaName"
    $jeaModuleFolder = Get-ChildItem -Path $jeaContentRoot | ForEach-Object {
        [PSCustomObject]@{
            Path    = $_.FullName
            Name    = $_.Name
            Version = $_.Name -as [version]
        }
    } | Where-Object Version | Where-Object {
        if ($maxVersion -and $maxVersion -lt $_.Version) { return $false }
        $true
    } | Sort-Object Version -Descending | Select-Object -First 1

    if (-not $jeaModuleFolder) { 
        return $false
    }
    # Do we need to update?
    $endpointVersion -ge $jeaModuleFolder.Version
    #endregion Check for Version Update
}

$executionCode = {
    param ($Parameters)

    $parameterHash = $Parameters.Parameters
    $contentPath = $Parameters.ContentPath
    $jeaName = $parameterHash.Name

    #region Pick applicable JEA Module from Source
    $minVersion = $parameterHash.MinimumVersion -as [version] # null if bad syntax or empty
    $maxVersion = $parameterHash.MaximumVersion -as [version] # null if bad syntax or empty
    $jeaContentRoot = Join-Path -Path $contentPath -ChildPath "resources\JEA\$jeaName"
    $jeaModuleFolder = Get-ChildItem -Path $jeaContentRoot | ForEach-Object {
        [PSCustomObject]@{
            Path    = $_.FullName
            Name    = $_.Name
            Version = $_.Name -as [version]
        }
    } | Where-Object Version | Where-Object {
        if ($maxVersion -and $maxVersion -lt $_.Version) { return $false }
        if ($minVersion -and $minVersion -gt $_.Version) { return $false }
        $true
    } | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $jeaModuleFolder) { 
        Write-ScmLog -Source ScmAction -EventId 404 -Type Error -Message "No suitable JEA module version found for JEA endpoint $jeaName!"
        return
    }
    #endregion Pick applicable JEA Module from Source

    #region Ensure Module Folder is deployed
    $moduleFolder = "$([Environment]::GetFolderPath('ProgramFiles'))\WindowsPowerShell\Modules\$($jeaName)"
    if (Test-Path -Path $moduleFolder) {
        Write-ScmLog -Source ScmAction -Message "[$jeaName] Cleaning up previous JEA Module content"
        try { Remove-Item -Path $moduleFolder -Force -Recurse -ErrorAction Stop }
        catch {
            Write-ScmLog -Source ScmAction -EventId 400 -Type Error -Message "Failed to clean up module folder for JEA Endpoint $jeaName" -ErrorRecord $_
            return
        }
    }
    Write-ScmLog -Source ScmAction -Message "[$jeaName] Copying JEA Module content from $($jeaModuleFolder.Path)"
    try {
        $null = New-Item -Path $moduleFolder -ItemType Directory -Force -ErrorAction Stop
        Copy-Item -Path "$($jeaModuleFolder.Path)\*" -Destination $moduleFolder -Force -Recurse -ErrorAction Stop
    }
    catch {
        Write-ScmLog -Source ScmAction -EventId 401 -Type Error -Message "Failed to deploy module folder $($jeaModuleFolder.Path) for JEA Endpoint $jeaName" -ErrorRecord $_
        return
    }
    #endregion Ensure Module Folder is deployed

    #region Ensure Session Configuration is set
    $sessionCfg = Get-PSSessionConfiguration -Name $jeaName -ErrorAction SilentlyContinue
    if ($sessionCfg) {
        Write-ScmLog -Source ScmAction -Message "[$jeaName] Unregistering previous JEA Endpoint configuration"
        try { Unregister-PSSessionConfiguration -Name $jeaName -Force -ErrorAction Stop }
        catch { 
            Write-ScmLog -Source ScmAction -EventId 402 -Type Error -Message "Failed to clean up previous session configuration for JEA Endpoint $jeaName" -ErrorRecord $_
            return
        }
    }
    Write-ScmLog -Source ScmAction -Message "[$jeaName] Registering the new JEA Session Configuration"
    try {
        $registerCommand = Get-Command -Name "Register-JeaEndpoint_$($jeaName)" -ErrorAction Stop
        & $registerCommand -ErrorAction Stop
    }
    catch {
        Write-ScmLog -Source ScmAction -EventId 403 -Type Error -Message "Error registering session configuration for JEA Endpoint $jeaName" -ErrorRecord $_
        return
    }
    #endregion Ensure Session Configuration is set

    #region Ensure WinRM is up and running
    # Give the WinRM service time to recover naturally
    Start-Sleep -Seconds 3

    if ((Get-Service WinRM).Status -eq 'Running') {
        return
    }

    try {
        Write-ScmLog -Source ScmAction -Message "[$jeaName] Forcing WinRM service start after failure to recover automatically"
        Start-Service WinRM -ErrorAction Stop
    }
    catch {
        Write-ScmLog -Source ScmAction -EventId 405 -Type Error -Message "Error starting WinRM Service after deploying JEA Endpoint $jeaName" -ErrorRecord $_
    }
    #endregion Ensure WinRM is up and running
}

$parametersRequired = @{
    Name = 'Name of the JEA endpoint to deploy'
}
$parametersOptional = @{
    MinimumVersion = 'The minimum version required. Will always update to latest if not specified.'
    MaximumVersion = 'The maximum version deployed. Will not update beyond this version.'
}

$paramRegisterScmAction = @{
    Name               = 'Jea Endpoint'
    Description        = 'Deploys and configures a JEA endpoint on the local computer.'
    ParametersRequired = $parametersRequired
    ParametersOptional = $parametersOptional
    Validation         = $validationCode
    Execution          = $executionCode
}

Register-ScmAction @paramRegisterScmAction