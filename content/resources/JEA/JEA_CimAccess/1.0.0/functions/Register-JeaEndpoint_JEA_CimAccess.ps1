function Register-JeaEndpoint_JEA_CimAccess
{
<#
	.SYNOPSIS
		Registers the module's JEA session configuration in WinRM.
	
	.DESCRIPTION
		Registers the module's JEA session configuration in WinRM.
		This effectively enables the module as a remoting endpoint.
	
	.EXAMPLE
		PS C:\> Register-JeaEndpoint_JEA_CimAccess
	
		Register this module in WinRM as a remoting target.
#>
	[CmdletBinding()]
	param (
		
	)
	
	process
	{
		Register-JeaEndpoint
	}
}