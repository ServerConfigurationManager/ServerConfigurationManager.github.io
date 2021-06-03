Register-ScmTarget -Name DomainControllers -ScriptBlock {
    2 -eq (Get-CimInstance Win32_OperatingSystem -ErrorAction Ignore).ProductType
}