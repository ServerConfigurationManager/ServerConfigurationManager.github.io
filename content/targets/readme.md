# Targets

This folder should contain scripts that define "Targets".
A Target is a scriptblock definition that a server runs and should return $true or $false.
It should never throw an exception.

This is used by the server running the module to determine, whether a specific configuration applies to it or not.

For example, a valid Target would be a scriptblock determining, whether it was a Windows 10 Client.
Or a Server OS of any type.

Think of this as similar to WMI filters for GPO.

> Note: Naming Targets
> Each Target must have a name that is valid as a foldername.
> Pick short and simple target names, to make life easier.
