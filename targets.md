# Targets

## Description

Targets are a simple piece of code that is executed on the computer executing SCM and determine, whether the computer should apply configuration settings defined for that Target or not.

Think of it as a more flexible version of WMI Filters in Group Policy.

For example, you could target all computers, or just any computer that happens to run a server operating system, or just any Linux computer, or ...

Whatever else, really. The sky is the limit.

> Target Files

To define a target, create a .ps1 file in the Content Path under the subfolder `targets`.
For example, the file for a Target specifying Windows computers could be `<Content Path>/targets/windows.ps1`.

Each of these script files calls `Register-ScmTarget`, thus registering the target and making it available for processing.

> Error Handling

Target scripts should never throw exceptions, instead only return `$true` or `$false`.

## Example Target files

Some examples from our prepare example content:

> All.ps1

Target all computers

```powershell
Register-ScmTarget -Name All -ScriptBlock {
    $true
}
```

> Servers.ps1

Targets only non-Domain Controller windows servers

```powershell
Register-ScmTarget -Name Servers -ScriptBlock {
    3 -eq (Get-CimInstance Win32_OperatingSystem -ErrorAction Ignore).ProductType
}
```
