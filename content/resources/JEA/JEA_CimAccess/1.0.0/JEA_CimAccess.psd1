@{

# Script module or binary module file associated with this manifest.
RootModule = 'JEA_CimAccess.psm1'

# Version number of this module.
ModuleVersion = '1.0.0'

# ID used to uniquely identify this module
GUID = '4f44ff9f-ca4f-432e-b3c6-fb2636c78be2'

# Author of this module
Author = 'Friedrich Weinmann'

# Company or vendor of this module
CompanyName = 'Contoso Ltd.'

# Copyright statement for this module
Copyright = '(c) Friedrich Weinmann. All rights reserved.'

# Description of the functionality provided by this module
Description = 'JEA Endpoint exposing WMI/CIM capabilities'

# Modules that must be imported into the global environment prior to importing this module
RequiredModules = @('CimCmdlets')

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = 'Register-JeaEndpoint_JEA_CimAccess'

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = 'JEA', 'JEAnalyzer', 'JEA_Module'

        # A URL to the license for this module.
        # LicenseUri = ''

        # A URL to the main website for this project.
        # ProjectUri = ''

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        # ReleaseNotes = ''

        # Prerelease string of this module
        # Prerelease = ''

        # Flag to indicate whether the module requires explicit user acceptance for install/update/save
        # RequireLicenseAcceptance = $false

        # External dependent modules of this module
        # ExternalModuleDependencies = @()

    } # End of PSData hashtable

} # End of PrivateData hashtable
}