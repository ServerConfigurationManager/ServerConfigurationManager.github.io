Register-ScmTarget -Name Clients -ScriptBlock {
    1 -eq (Get-CimInstance Win32_OperatingSystem -ErrorAction Ignore).ProductType
}