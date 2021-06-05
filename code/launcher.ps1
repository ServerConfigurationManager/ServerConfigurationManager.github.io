<#
.SYNOPSIS
    Launcher script that deploys the Server Configuration Manager and launches the self-configuration workflow.

.DESCRIPTION
    Launcher script that deploys the Server Configuration Manager and launches the self-configuration workflow.

    Steps taken:
    - Deploy logging to EventLog
      Creates a new Application eventlog named "ServerConfigurationManager".
    - Deploy Package Management
      Ensures nuget binaries are available
      Ensures the corporate PSRepository is registered, configured correctly and available
    - Installs the latest version of ServerConfigurationManager
      Uses the registered PSRepository for the task.
    - Executes the Server Configuration Manager primary workflow.

    Logging:
    The launcher performs logging to the windows eventlog.
    All actions are logged to the created ServerConfigurationManager log, except for an error to create that very log itself.

    Error Events:
    > Application | Application

    - ID 666 : Generated when unable to deploy logging itself.

    > ServerConfigurationManager | ScmLauncher

    - ID 666 : General Launcher Error - each other error ALSO triggers this error.
    - ID 700 : Failed to deploy nuget binaries
    - ID 701 : Failed to update PSRepository
    - ID 702 : Failed to register PSRepository
    - ID 703 : Repository not found (triggers in edge cases where the previous commands fail to cause an exception)
    - ID 720 : Error creating config folder in the current user's LocalAppData folder. This would happen if there is a fundamental problem accessing environment variables.
    - ID 721 : Failed to write repository configuration file. Could happen if the file is locked or antivirus interferes.
    - ID 800 : Error installing the latest version of ServerConfigurationManager

.PARAMETER RepositoryName
    The name under which the SCM repository should be created.

.PARAMETER RepositoryPath
    The path to where the repository is found.
    Can be both file share or nuget repository, but must be accessibly to the executing account.

.PARAMETER ContentPath
    The network share containing the configuration, Action, Target and resource data needed to operate this workflow.

.PARAMETER UsePSGet
    Whether the launcher script should use PowerShellGet to configure its repositories.
    By default, repository registration happens manually to avoid hanged processes that tend to happen when using PowerShellGet the first time.

.NOTES
    Version: 1.0.0
    Author: Friedrich Weinmann
    Company: Microsoft
    Created on: 2021-05-25

    License:

MIT License

Copyright (c) Friedrich Weinmann

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $RepositoryName,

    [Parameter(Mandatory = $true)]
    [string]
    $RepositoryPath,

    [Parameter(Mandatory = $true)]
    [string]
    $ContentPath,

    [switch]
    $UsePSGet
)

#region Functions
function Set-SourceRepository {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $RepositoryName,

        [Parameter(Mandatory = $true)]
        [string]
        $RepositoryPath,

        [Parameter(Mandatory = $true)]
        [string]
        $ContentPath,

        [switch]
        $UsePSGet
    )
    try {
        if (-not (Get-Item -Path "$([System.Environment]::GetFolderPath("ProgramFiles"))\PackageManagement\ProviderAssemblies\nuget\*\Microsoft.PackageManagement.NuGetProvider.dll" -ErrorAction Ignore)) {
            Write-Log -Message "Copying nuget binaries from '$ContentPath\resources\nuget'"
            Copy-Item -Path "$ContentPath\resources\nuget" -Destination "$env:ProgramFiles\PackageManagement\ProviderAssemblies\" -Recurse -Force -ErrorAction Stop
        }
    }
    catch {
        Write-Log -Message "Failed to deploy nuget binaries! $_" -Type Error -EventId 700 -Source ScmLauncher
        Write-Log -Message "Error Setting up Server Configuration Manager! $_" -Type Error -EventId 666 -Source ScmLauncher
        throw
    }

    #region Manually build repository entry
    if (-not $UsePSGet) {
        $repoConfigFile = "$env:LOCALAPPDATA\Microsoft\Windows\PowerShell\PowerShellGet\PSRepositories.xml"
        if (Test-Path $repoConfigFile) {
            $repositoryHash = Import-Clixml -Path $repoConfigFile
        }
        else {
            try { $null = New-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\PowerShell\PowerShellGet" -ItemType Directory -Force -ErrorAction Stop }
            catch {
                Write-Log -Message "Failed to create repository config folder! $_" -Type Error -EventId 720 -Source ScmLauncher
                Write-Log -Message "Error Setting up Server Configuration Manager! $_" -Type Error -EventId 666 -Source ScmLauncher
                throw
            }
            $repositoryHash = [ordered]@{ }
        }

        $repositoryHash[$RepositoryName] = [PSCustomObject]@{
            Name = $RepositoryName
            SourceLocation = $RepositoryPath
            PublishLocation = $RepositoryPath
            ScriptSourceLocation = $RepositoryPath
            ScriptPublishLocation = $RepositoryPath
            Trusted = $true
            Registered = $true
            InstallationPolicy = 'Trusted'
            PackageManagementProvider = 'NuGet'
            ProviderOptions = @{ }
        }

        try { $repositoryHash | Export-Clixml -Path $repoConfigFile -Depth 99 -ErrorAction Stop }
        catch {
            Write-Log -Message "Failed to export repository configuration! $_" -Type Error -EventId 721 -Source ScmLauncher
            Write-Log -Message "Error Setting up Server Configuration Manager! $_" -Type Error -EventId 666 -Source ScmLauncher
            throw
        }
    }
    #endregion Manually build repository entry

    #region Use PowerShellGet to create repository entry
    else {
        $repositories = Get-PSRepository -ErrorAction Ignore
        if ($systemRepo = $repositories | Where-Object Name -EQ $RepositoryName) {
            $param = @{ }
            if ($systemRepo.SourceLocation -ne $RepositoryPath) {
                $param.SourceLocation = $RepositoryPath
            }
            if ($systemRepo.InstallationPolicy -ne "Trusted") {
                $param.InstallationPolicy = 'Trusted'
            }
            if ($param.Count -gt 0) {
                try { Set-PSRepository -Name $RepositoryName @param -ErrorAction Stop }
                catch {
                    Write-Log -Message "Failed to update repository $RepositoryName ($RepositoryPath)! $_" -Type Error -EventId 701 -Source ScmLauncher
                    Write-Log -Message "Error Setting up Server Configuration Manager! $_" -Type Error -EventId 666 -Source ScmLauncher
                    throw
                }
            }
        }
        else {
            Write-Log -Message "Registering new repository from $RepositoryPath"
            try { Register-PSRepository -Name $RepositoryName -SourceLocation $RepositoryPath -InstallationPolicy Trusted -ErrorAction Stop }
            catch {
                Write-Log -Message "Failed to register repository $RepositoryName ($RepositoryPath)! $_" -Type Error -EventId 702 -Source ScmLauncher
                Write-Log -Message "Error Setting up Server Configuration Manager! $_" -Type Error -EventId 666 -Source ScmLauncher
                throw
            }
        }
    }
    #endregion Use PowerShellGet to create repository entry

    # Should always work, but just in case validate it anyway
    try { $repository = Get-PSRepository -Name $RepositoryName -ErrorAction Stop }
    catch {
        Write-Log -Message "Failed to find repository $RepositoryName ($RepositoryPath)! $_" -Type Error -EventId 703 -Source ScmLauncher
        Write-Log -Message "Error Setting up Server Configuration Manager! $_" -Type Error -EventId 666 -Source ScmLauncher
        throw
    }
    if (-not $repository) {
        Write-Log -Message "Failed to find repository $RepositoryName ($RepositoryPath)!" -Type Error -EventId 703 -Source ScmLauncher
        Write-Log -Message "Error Setting up Server Configuration Manager!" -Type Error -EventId 666 -Source ScmLauncher
        throw "Failed to find repository $RepositoryName ($RepositoryPath)!"
    }
}

function Set-Logging {
    [CmdletBinding()]
    param (

    )

    try {
        $eventlog = [System.Diagnostics.EventLog]::GetEventLogs().Where{ $_.Log -eq "ServerConfigurationManager" }
        if ($eventlog) { return }
    
        [System.Diagnostics.EventLog]::CreateEventSource("ScmLauncher", "ServerConfigurationManager")
        [System.Diagnostics.EventLog]::CreateEventSource("ScmExecution", "ServerConfigurationManager")
        [System.Diagnostics.EventLog]::CreateEventSource("ScmDebug", "ServerConfigurationManager")
        [System.Diagnostics.EventLog]::CreateEventSource('ScmAction', "ServerConfigurationManager")
    }
    catch {
        Write-EventLog -LogName Application -Source Application -EntryType Error -Category 666 -EventId 666 -Message "Error Setting up Server Configuration Manager logging! $_"
        throw
    }
}

function Install-ServerConfigurationManager {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $RepositoryName
    )

    Write-Log -Message "Installing Server Configuration Manager module from $RepositoryName"
    try { Install-Module -Name ServerConfigurationManager -Repository $RepositoryName -Force -AllowClobber -ErrorAction Stop }
    catch {
        Write-Log -Message "Failed to install module: $_" -Type Error -EventId 800
        throw
    }
}

function Write-Log {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Message,

        [System.Diagnostics.EventLogEntryType]
        $Type = 'Information',

        [int]
        $EventId = 1000,

        [ValidateSet('ScmLauncher', 'ScmExecution', 'ScmDebug')]
        [string]
        $Source = 'ScmLauncher'
    )

    $eventlog = [System.Diagnostics.EventLog]::GetEventLogs().Where{ $_.Log -eq "ServerConfigurationManager" }[0]
    $eventlog.Source = $Source
    $eventlog.WriteEntry($Message, $Type, $EventId)
}

function Test-WebContentPath {
    [CmdletBinding()]
    param (
        [string]
        $Path
    )

    $Path -match '^http|^https'
}

function Install-WebContent {
    [CmdletBinding()]
    param (
        [string]
        $Path
    )

    $basePath = $env:TEMP
    if (-not $basePath) { $basePath = [System.Environment]::GetFolderPath("temp") }
    if (-not $basePath) { $basePath = $HOME }

    $archivePath = Join-Path -Path $basePath -ChildPath "contentPath_$(Get-Random).zip"
    $newContentPath = Join-Path -Path $basePath -ChildPath "content_$(Get-Random)"
    $null = New-Item -Path $newContentPath -Force -ItemType Directory    
    Invoke-WebRequest -Uri $Path -OutFile $archivePath
    Expand-Archive -Path $archivePath -DestinationPath $newContentPath
    Remove-Item $archivePath
    $newContentPath
}
#endregion Functions

# Setup Logging
Set-Logging
Write-Log -Message 'Starting Launcher' -EventId 999
$isWebContentPath = Test-WebContentPath -Path $ContentPath
if ($isWebContentPath) {$ContentPath = Install-WebContent -Path $ContentPath }

Set-SourceRepository -RepositoryName $RepositoryName -RepositoryPath $RepositoryPath -ContentPath $ContentPath -UsePSGet:$UsePSGet
Install-ServerConfigurationManager -RepositoryName $RepositoryName
try { Invoke-ServerConfiguration -RepositoryName $RepositoryName -ContentPath $ContentPath }
finally { if ($isWebContentPath) { Remove-Item -Path $ContentPath -Force -Recurse -ErrorAction Ignore }}

Write-Log -Message 'Launcher Execution Completed' -EventId 1001