# Configuration File Format

## Synopsis

Configurations map [Actions](actions.html) to [Targets](targets.html), then add parameters.
For example, a configuration could ...

+ Assign the Action "Folder"
+ To the Target "Servers"
+ With the parameter "Path" set to "C:\Contoso"

Causing every server to create the C:\Contoso folder.

In your Content Path, configuration files are stored in the subfolder "configurations" as ".psd1" files.
For each target, create a folder with the same name as the target.
All configuration files assigned to a target must be placed in that folder.

Using the example above, the configuration file would be in:
`<ContentPath>/configurations/Servers/folder contoso.psd1`

## Description

Each Configuration file is assumed to be a psd1 file returning one configuration entry.
Each Entry is a hashtable formated thus:

```powershell
@{
    Name = "Contoso\Scripts Folder"
    Target = "Servers"
    Action = "Folder"
    Parameters = @{
        Path = "C:\Contoso\Scripts"
    }
    Weight = 50
    Tier = 0
    DependsOn = @(
        'Contoso Folder'
    )
}
```

## Parameters

> Name

Arbitrary text, used for logging purposes and to declare dependencies on something.
Should be unique.

> Target

The name of the target the setting applies to. Optional.
For documentation purposes, as configuration settings are targeted by the folder they are stored in.

> Action

Name of the Action implementing this setting.
A mandatory property that must point at an existing action.

> Parameters

A hashtable of parameters to pass on to the Action.
This governs just how the Action executes.
Each Action defines a set of parameters it requires - if they are not provided, execution will fail.
Specifying parameters that the action does not use is ok, but will be ignored.

> Weight

The Weight determines the processing order within the same tier of settings.
The lower the number, the earlier it is applied.

> Tier

The tier is the first order sorting mechanism.
The lower the tier, the earlier a setting is applied.

> DependsOn

A list of configuration settings that must have succeeded in order for the current configuration setting to even be attempted.

## Processing Order

Two properties govern the processing order: Tier and Weight.
Configuration entries are sorted by Tier first and Weight Second.

Example: Three Configuration entries:

```text
A: Tier 1, Weight 10
B: Tier 2, Weight 40
C: Tier 1, Weight 80
```

In this situation, the processing order is `A > C > B` - B might have a lower weight, but since its Tier is higher, it comes after C.
