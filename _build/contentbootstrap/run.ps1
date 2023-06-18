[CmdletBinding()]
param (
	[string]
	$ContentPath = (Read-Host "Insert full networkshare from which clients will access the SCM content"),

	[string]
	$RepositoryPath = (Read-Host "Insert full path to the PSRepository clients will use. They will either use anonymous or windows authentication for access."),

	[string]
	$RepositoryName = (Read-Host "Specify the name of the repository to use. The repository in the path previously specified will be registered under this name.")
)

$ErrorActionPreference = 'Stop'
trap {
	Write-Warning "Script failed: $_"
	throw $_
}

#region Functions
function Get-UserChoice
{

    <#
	.SYNOPSIS
		Prompts the user to choose between a set of options.
	
	.DESCRIPTION
		Prompts the user to choose between a set of options.
		Returns the index of the choice picked as a number.
	
	.PARAMETER Options
		The options the user may pick from.
		The user selects a choice by specifying the letter associated with a choice.
		The letter assigned to a choice is picked from the character after the first '&' in any specified string.
		If there is no '&', the system will automatically pick the first letter as choice letter:
		"This &is an example" will have the character "i" bound for the choice.
		"This is &an example" will have the character "a" bound for the choice.
		"This is an example" will have the character "T" bound for the choice.
	
		This parameter takes both strings and hashtables (in any combination).
		A hashtable is expected to have two properties, 'Label' and 'Help'.
		Label is the text shown in the initial prompt, help what the user sees when requesting help.
	
	.PARAMETER Caption
		The title of the question, so the user knows what it is all about.

    .PARAMETER Vertical
        Displays the options vertically, one per line, rather than the default side-by-side display.
        Each option will be numbered.
        Option numbering starts at 1, return will always be one lower than the selected number.
	
	.PARAMETER Message
		A message to offer to the user. Be more specific about the implications of this choice.
	
	.PARAMETER DefaultChoice
		The index of the choice made by default.
		By default, the first option is selected as default choice.
	
	.EXAMPLE
		PS C:\> Get-UserChoice -Options "1) Create a new user", "2) Disable a user", "3) Unlock an account", "4) Get a cup of coffee", "5) Exit" -Caption "User administration menu" -Message "What operation do you want to perform?"
	
		Prompts the user for what operation to perform from the set of options provided
#>
    [OutputType([System.Int32])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [object[]]
        $Options,
		
        [string]
        $Caption,

        [switch]
        $Vertical,
		
        [string]
        $Message,
		
        [int]
        $DefaultChoice = 0
    )
	
    begin {
        #region Vertical Options Display
        if ($Vertical) {
            $optionStrings = foreach ($option in $Options) {
                if ($option -is [hashtable]) { $option.Keys }
                else { $option }
            }
            $count = 1
            $messageStrings = foreach ($optionString in $OptionStrings) {
                "$count $optionString"
                $count++
            }
            $count--
            $Message = ((@($Message) + @($messageStrings)) -join "`n").Trim()
            $choices = 1..$count | ForEach-Object { "&$_" }
        }
        #endregion Vertical Options Display

        #region Default Options Display
        else {
            $choices = @()
            foreach ($option in $Options) {
                if ($option -is [hashtable]) {
                    $label = $option.Keys -match '^l' | Select-Object -First 1
                    [string]$labelValue = $option[$label]
                    $help = $option.Keys -match '^h' | Select-Object -First 1
                    [string]$helpValue = $option[$help]
				
                }
                else {
                    $labelValue = "$option"
                    $helpValue = "$option"
                }
                if ($labelValue -match "&") { $choices += New-Object System.Management.Automation.Host.ChoiceDescription -ArgumentList $labelValue, $helpValue }
                else { $choices += New-Object System.Management.Automation.Host.ChoiceDescription -ArgumentList "&$($labelValue.Trim())", $helpValue }
            }
        }
        #endregion Default Options Display
    }
    process {
        # Will error on one option so we just return the value 0 (which is the result of the only option the user would have)
        # This is for cases where the developer dynamically assembles options so that they don't need to ensure a minimum of two options.
        if ($Options.Count -eq 1) { return 0 }
		
        $Host.UI.PromptForChoice($Caption, $Message, $choices, $DefaultChoice)
    }

}

function Assert-Path {
	<#
	.SYNOPSIS
		Ensures a path exists, prompts if it should be created if not.
	
	.DESCRIPTION
		Ensures a path exists, prompts if it should be created if not.
		Throws a terminating exception if it does not exist and either creation is denied or fails.
	
	.PARAMETER Path
		Path to verify exists.
	
	.EXAMPLE
		PS C:\> Assert-Path -Path C:\temp
		
		Verifies C:\temp exists and prompts whether i should be created if not.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Path
	)

	if (Test-Path -Path $Path) { return }

	$choice = Get-UserChoice -Message "Path not found. Create it? ($Path)" -Options Yes, No
	if ($choice -ne 1) { throw "Critical Path does not exist: $Path" }

	try { $null = New-Item -Path $Path -ItemType Directory -Force -ErrorAction Stop }
	catch { throw "Failed to create path: $Path | $_" }
}

function Install-ScmContent {
	<#
	.SYNOPSIS
		Installs the example content implementing the SCM content folder.
	
	.DESCRIPTION
		Installs the example content implementing the SCM content folder.
	
	.PARAMETER SourceRoot
		Root folder under which the "content" folder with the reference files can be found.
	
	.PARAMETER Path
		Path where the content items are copied to and the launcher looks for its content.
	
	.EXAMPLE
		PS C:\> Install-ScmContent -SourceRoot $PSScriptRoot -Path $ContentRoot
		
		Installs the content items in the "content" folder under current file's path to the path specified in $ContentRoot
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$SourceRoot,

		[Parameter(Mandatory = $true)]
		[string]
		$Path
	)

	Copy-Item -Path "$SourceRoot\content\*" -Destination $Path -Recurse -Force
}

function Install-ScmModules {
	<#
	.SYNOPSIS
		Copies the SCM-related modules to the specified folder.
	
	.DESCRIPTION
		Copies the SCM-related modules to the specified folder.
		This does not implement the repository specified - these are used in the launcher to bootstrap without requiring a repository first.
	
	.PARAMETER SourceRoot
		The root folder under which the function looks for a "Modules" folder to copy.
	
	.PARAMETER Path
		The root path to which the entire "Modules" folder is being copied.
	
	.EXAMPLE
		PS C:\> Install-ScmModules -SourceRoot $PSScriptRoot -Path $ContentRoot

		Copies the "Modules" folder under the folder containing the current script to the path in $ContentRoot
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$SourceRoot,

		[Parameter(Mandatory = $true)]
		[string]
		$Path
	)

	Copy-Item -Path "$SourceRoot\Modules" -Destination $Path -Recurse -Force
}

function Install-ScmLauncher {
	<#
	.SYNOPSIS
		Deploy the launcher script after inserting the deployment values.
	
	.DESCRIPTION
		Deploy the launcher script after inserting the deployment values.
		If there is a SYSVOL detectable, it will offer to install the launcher script to the SYSVOL scripts folder.
		Otherwise it will fallback to place it in the Content path where SCM looks for its actual working content.
	
	.PARAMETER SourceRoot
		The path in which the launcher script source code can be found.
	
	.PARAMETER Path
		The to which the SCM contenet files have been deployed.
	
	.PARAMETER RepositoryPath
		The path to the internal PowerShell repository.
	
	.PARAMETER RepositoryName
		The name under which to register the internal PowerShell repository.
	
	.EXAMPLE
		PS C:\> Install-ScmLauncher -SourceRoot $PSScriptRoot -Path $ContentPath -RepositoryPath $RepositoryPath -RepositoryName $RepositoryName

		Installs the SCM launcher, taking its source file from the same folder as the current script.
		Will inject the specified values for path and name of the internal PowerShell repository.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$SourceRoot,

		[Parameter(Mandatory = $true)]
		[string]
		$Path,

		[Parameter(Mandatory = $true)]
		[string]
		$RepositoryPath,

		[Parameter(Mandatory = $true)]
		[string]
		$RepositoryName
	)

	$launcherCode = [System.IO.File]::ReadAllText("$SourceRoot\launcher-bootstrap.ps1")
	$launcherCode = $launcherCode -replace '%RepositoryPath%',$RepositoryPath -replace '%RepositoryName%',$RepositoryName -replace '%ContentPath%',$Path

	$sysvolPath = "\\$env:USERDNSDOMAIN\Sysvol\$env:USERDNSDOMAIN\scripts"
	if (Test-Path -Path $sysvolPath) {
		$choice = Get-UserChoice -Message 'The Server Configuration Mmanager solution requires deploying a launcher script as scheduled task. Should this script be deployed to SYSVOL?' -Options Yes, No
		if ($choice -eq 0) { $Path = $sysvolPath }
	}

	$outPath = Join-Path -Path $Path -ChildPath 'SCM-Launcher.ps1'
	$encoding = [System.Text.UTF8Encoding]::new($true)
	[System.io.File]::WriteAllText($outPath, $launcherCode, $encoding)
	Write-Host @"
Launcher script has been written to: $outPath
Be sure to deploy a scheduled task (e.g. via Group Policy) that runs it:
- Schedule: OnBoot, Every Day
- Principal: System, with maximum rights
- Action Executable: powershell.exe
- Action Arguments: -ExecutionPolicy bypass -Path "$outPath"
"@
}
#endregion Functions

Assert-Path -Path $ContentPath
Install-ScmContent -SourceRoot $PSScriptRoot -Path $ContentPath
Install-ScmModules -SourceRoot $PSScriptRoot -Path $ContentPath
Install-ScmLauncher -SourceRoot $PSScriptRoot -Path $ContentPath -RepositoryPath $RepositoryPath -RepositoryName $RepositoryName