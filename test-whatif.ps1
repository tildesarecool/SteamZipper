[CmdletBinding(SupportsShouldProcess=$true)]
param (
    [string]$sourceFolder
)

Write-Host "Script started."
if ($PSCmdlet.ShouldProcess("Test action", "Doing something")) {
    Write-Host "Doing it!"
} else {
    Write-Host "WhatIf: Would do it."
}
Write-Host "Script ended."