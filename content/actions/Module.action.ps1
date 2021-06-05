<#
.SYNOPSIS
    Ensures a specified module is installed on the target server.

.DESCRIPTION
    Ensures a specified module is installed on the target server.
    Includes all dependencies if existing.
    Installs the modules from the default SCM repository.

.NOTES
    {
        "Author": "Friedrich Weinmann",
        "Version": "1.0.0",
        "ErrorCodes": {
            "400": "Invalid Parameter: MinimumVersion. Happens when you provide bad data to the MinimumVersion parameter. Only traditional version numbers supported!",
            "401": "Invalid Parameter: MaximumVersion. Happens when you provide bad data to the MaximumVersion parameter. Only traditional version numbers supported!",
            "402": "Error searching repository. Happens when for some reason the configured PowerShell repository cannot be accessed, includes error why exactly.",
            "403": "No applicable module found. This error happens when no version of the module in the repository meets the filter criteria. Check the configuration and make sure the targeted module is correctly published on the repository.",
            "404": "Error installing from the repository. Happens when for some reason the configured PowerShell repository cannot be accessed, includes error why exactly."
        }
    }
#>

$validationCode = {
    param ($Parameters)

    $parameterHash = $Parameters.Parameters
    $repositoryName = $Parameters.Repository

    $modules = Get-Module -ListAvailable -All | Where-Object Name -EQ $parameterHash.name
    if (-not $modules) { return $false }

    $minVersion = $parameterHash.MinimumVersion -as [Version]
    $maxVersion = $parameterHash.MaximumVersion -as [Version]

    # Return false if Config error on versions
    # Error reporting in this to happen in execute
    if ($parameterHash.MinimumVersion -and -not $minVersion) { return $false }
    if ($parameterHash.MaximumVersion -and -not $maxVersion) { return $false }

    if ($minVersion -or $maxVersion) {
        if ($minVersion -and -not ($modules | Where-Object Version -GE $minVersion)) {
            return $false
        }
        if ($maxVersion -and -not ($modules | Where-Object Version -LE $maxVersion)) {
            return $false
        }

        return $true
    }

    $currentVersion = @($modules | Sort-Object Version -Descending)[0].Version
    $repoVersion = (Find-Module -Name $parameterHash.Name -Repository $repositoryName -ErrorAction Ignore | Where-Object Name -EQ $parameterHash.Name).Version
    # Again, access error is handled during execute for purposes of logging
    if (-not $repoVersion) { return $false }
    if ($repoVersion -gt $currentVersion) { return $false }
    $true
}

$executionCode = {
    param ($Parameters)

    $parameterHash = $Parameters.Parameters
    $repositoryName = $Parameters.Repository
    $configName = $parameters.ConfigurationName
    $moduleName = $parameterHash.Name

    Write-ScmLog -Source ScmAction -Message "[$configName][Module] Ensuring module $($moduleName) (MinVersion: $($parameterHash.MinimumVersion) | MaxVersion: $($parameterHash.MaximumVersion))"

    $minVersion = $parameterHash.MinimumVersion -as [Version]
    $maxVersion = $parameterHash.MaximumVersion -as [Version]

    if ($parameterHash.MinimumVersion -and -not $minVersion) {
        Write-ScmLog -Source ScmAction -Type Error -EventId 400 -Message "[$configName][Module] Invalid Parameter: MinimumVersion not a valid version number: $($parameterHash.MinimumVersion)"
        return
    }
    if ($parameterHash.MaximumVersion -and -not $maxVersion) {
        Write-ScmLog -Source ScmAction -Type Error -EventId 401 -Message "[$configName][Module] Invalid Parameter: MaximumVersion not a valid version number: $($parameterHash.MaximumVersion)"
        return
    }

    try { $allServerVersions = Find-Module -Repository $repositoryName -Name $moduleName -AllVersions -ErrorAction Stop | Where-Object Name -EQ $moduleName }
    catch {
        Write-ScmLog -Source ScmAction -Type Error -EventId 402 -Message "[$configName][Module] Error searching repository $($repositoryName)" -ErrorRecord $_
        return
    }

    $versionNeeded = $allServerVersions | Where-Object {
        -not $minVersion -or
        $minVersion -le $_.Version
    } | Where-Object {
        -not $maxVersion -or
        $maxVersion -ge $_.Version
    } | Sort-Object { $_.Version -as [version] } -Descending | Select-Object -First 1

    if (-not $versionNeeded) {
        Write-ScmLog -Source ScmAction -Type Error -EventId 403 -Message "[$configName][Module] No applicable version found at $($repositoryName) out of a total of $(@($allServerVersions).Count) module versions found"
        return
    }

    Write-ScmLog -Source ScmAction -Message "[$configName][Module] Installing $($versionNeeded.Name) v$($versionNeeded.Version)"

    try {
        Install-Module -Name $versionNeeded.Name -RequiredVersion $versionNeeded.Version -Repository $repositoryName -ErrorAction Stop -Force -AllowClobber -Scope AllUsers
    }
    catch {
        Write-ScmLog -Source ScmAction -Type Error -EventId 404 -Message "[$configName][Module] Error installing $($versionNeeded.Name) v$($versionNeeded.Version) from $($repositoryName)" -ErrorRecord $_
        return
    }
}

$parametersRequired = @{
    Name = 'Name of the module to ensure exists. No wildcards.'
}
$parametersOptional = @{
    MinimumVersion = 'At least this version must exist on the local computer.'
    MaximumVersion = 'A version no greater than this must exist on the local computer. Will not uninstall later versions!'
}

$paramRegisterScmAction = @{
    Name               = 'Module'
    Description        = 'Ensures a specific PowerShell module exists on the targeterd computers'
    ParametersRequired = $parametersRequired
    ParametersOptional = $parametersOptional
    Validation         = $validationCode
    Execution          = $executionCode
}

Register-ScmAction @paramRegisterScmAction