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

function Compress-Subfolders {
    param (
        [string]$sourceFolderPath,
        [string]$destinationFolderPath,
        [string]$folderName,
        [string]$platformShortName,
        [string]$dateStamp
    )

    $zipFileName = "${folderName}_${dateStamp}_${platformShortName}.zip"
    $zipFilePath = Join-Path -Path $destinationFolderPath -ChildPath $zipFileName

    if ($platformShortName -eq "") {
        $platformShortName = Get-PlatformShortName
        Write-Host "platformShortName is $platformShortName"
    }

    # check if zip file already exists
#    if (Test-Path -Path $zipFileName) {
    if (1 -eq 1) {
        # extract date from existing zip file name and compare with fodler last modified date
        $existingDate = ($zipFileName -split "_")[1]
        $folderModifiedDate = (Get-Item $sourceFolderPath).LastWriteTime.ToString("MMddyyyy")

        Write-Host "zip file name is $zipFileName and zip file path is $zipFilePath"
        Write-Host "existing date is $existingDate and folder modified date is $folderModifiedDate"
        Write-Host "source folder path is $sourceFolderPath and destionation folder path is $destinationFolderPath"

        #        

        if ($existingDate -eq $folderModifiedDate) {
            Write-Host "Skipping $folderName (no changes since $existingDate)"
            return
        } else {
            Write-Host "Updating folderName (folder modified after $existingDate)"
        }
    }
    # create zip file
    Compress-Archive -Path "$sourceFolderPath\*" -DestinationPath $zipFilePath -Force
    Write-Host "compress-archive command here"
    Write-Host "created/updated: $zipFileName"
}

Compress-Subfolders -sourceFolder $sourceFolder -destinationFolder $destinationFolder

#if (-not (Test-Path -Path $destinationFolder)) {
#    New-Item -Path $destinationFolder -ItemType Directory
#}

#$folders = Get-ChildItem -path $sourceFolder -Directory
##$totalFolders = $folders.Count
#
#foreach ($subfolder in $folders) {
#    $platformShortName = Get-PlatformShortName -path $subfolder.FullName
#}

# Write-Host "the platform is $platformShortName" # (successfully parsed platform)