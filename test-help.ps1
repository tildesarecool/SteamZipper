[CmdletBinding()]
<# 
.SYNOPSIS
    Test script help.
.DESCRIPTION
    This is a test.
.PARAMETER TestParam
    A test parameter.
.EXAMPLE
    .\test-help.ps1 -TestParam "value"
#>
param (
    [string]$TestParam
)
Write-Host "Test"