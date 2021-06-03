<#
.SYNOPSIS
    Ensures a folder exists.

.DESCRIPTION
    This Action ensures the specified folder exists.
    Ensure the path specified is legitimate.

.NOTES
    {
        "Author": "Friedrich Weinmann",
        "Version": "1.0.0",
        "ErrorCodes": {
            "400": "Error creating directory. Might be a bad path name or an access error."
        }
    }
#>

$validationCode = {
    param ($Parameters)

    $parameterHash = $Parameters.Parameters

    $result = Test-Path -LiteralPath $parameterHash.Path -PathType Container
    if (-not $result) { return $false }

    try { $item = Get-Item -LiteralPath $parameterHash.Path -ErrorAction Stop }
    catch { return $false }

    # Could theoretically be a registry path or some other provider source based on Test-Path alone
    $item.PSProvider.Name -eq 'FileSystem'
}

$executionCode = {
    param ($Parameters)

    $parameterHash = $Parameters.Parameters
    try { $null = New-Item -Path $parameterHash.Path -ItemType Directory -Force -ErrorAction Stop }
    catch {
        Write-ScmLog -Source ScmAction -Type Error -EventId 400 -Message "Error creating directory $($parameterHash.Path)" -ErrorRecord $_
    }
}

$parametersRequired = @{
    Path = "Path to ensure exists"
}
$parametersOptional = @{

}

$paramRegisterScmAction = @{
	Name			   = 'Folder'
	Description	       = 'Ensures a folder exists'
	ParametersRequired = $parametersRequired
	ParametersOptional = $parametersOptional
	Validation		   = $validationCode
	Execution		   = $executionCode
}

Register-ScmAction @paramRegisterScmAction