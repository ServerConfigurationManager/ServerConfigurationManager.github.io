#requires -Modules PSFramework

[CmdletBinding()]
param (
	
)

$tempFolder = New-PSFTempDirectory -Name build -ModuleName build
Copy-Item -Path "$PSScriptRoot\contentbootstrap\run.ps1" -Destination $tempFolder
Copy-Item -Path "$PSScriptRoot\contentbootstrap\launcher-bootstrap.ps1" -Destination $tempFolder
Copy-Item -Path "$PSScriptRoot\..\content" -Destination $tempFolder -Recurse
$moduleRoot = New-Item -Path $tempFolder -Name Modules -ItemType Directory -Force
Save-Module -Name ServerConfigurationManager -Path $moduleRoot.FullName
Save-Module -Name Microsoft.PowerShell.PSResourceGet -Path $moduleRoot.FullName -AllowPrerelease

& "$PSScriptRoot\bootstrap\New-BootstrapScript.ps1" -Path $tempFolder -OutPath "$PSScriptRoot\..\code\bootstrap.ps1"

Remove-PSFTempItem -Name build -ModuleName build