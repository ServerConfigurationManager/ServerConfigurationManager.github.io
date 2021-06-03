Register-ScmTarget -Name Servers -ScriptBlock {
    3 -eq (Get-CimInstance Win32_OperatingSystem -ErrorAction Ignore).ProductType
}