# P:\steamzipper

# Script parameters (this should be the very first thing in the script)
param (
    [string]$sourceFolder,      # Source folder with subfolders to zip
    [string]$destinationFolder  # Destination folder for the zip files
)

#Write-Host "source folder is $sourceFolder and destination folder is $destinationFolder"

if (-not $sourceFolder -or -not $destinationFolder) {
    Write-Host "Error: Source folder and destination folder must be specified."
    exit 1
}

function Get-PlatformShortName {
    param (
        [string]$path
    )

    $platforms = @{
        "epic games"   = "epic"
        "Amazon Games" = "amazon"
        "GOG"          = "gog"
        "Steam"        = "steam"
    }

    foreach ($platform in $platforms.Keys) {
        if ($path -like "*$platform*") {
            return $platforms[$platform]
        }
    }
    return "unknown"  # Default value if no match
}

#if (-not (Test-Path -Path $destinationFolder)) {
#    New-Item -Path $destinationFolder -ItemType Directory
#}

$folders = Get-ChildItem -path $sourceFolder -Directory
$totalFolders - $folders.Count

foreach ($subfolder in $folders) {
    $platformShortName = Get-PlatformShortName -path $subfolder.FullName
}

Write-Host "the platform is $platformShortName"