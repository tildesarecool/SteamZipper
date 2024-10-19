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
#    param (
#        [string]$path
#    )

    $path = $sourceFolder

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

#$PlatName = Get-PlatformShortName -path $sourceFolder
#Write-Host "platform name is $PlatName"

function Get-DateFromZipName {
    param (
        [string]$zipFileName
    )

    $pattern = "\d{8}" # Matches an 8-digit date
    if ($zipFileName -match $pattern) {
        return $matches[0]
    }
    
    return $null
}

# function Get-FiileFolderModifiedDate {
#     # this function was just for testing. it's been replaced
#     #    param (
# #        [string]$zipFileName
# #        [string]$folderName
# #    )
#     #$pattern = "\d{8}"
# 
#     #$digModDate = $sourceFolder + "dig dog\"
#     #Write-Host "digModDate is $digModDate"
# 
#     $gameFolder = "Horizon Chase"
#     $digDogFullPath = Join-Path -Path $sourceFolder -ChildPath $gameFolder
# 
# #    return $digDogFullPath
# 
#     $digModDate =  (Get-Item $digDogFullPath).LastWriteTime.ToString("MMddyyyy")
#     return $digModDate
# #
#     #return $digModDate.LastWriteTime.ToString("MMddyyyy")
# 
# }

function Confirm-ZipFileReq {
    $folders = Get-ChildItem -Path $sourceFolder -Directory #output is all subfolder paths on one line
    #Write-Host "value of folders is $folders"

    $ZipFoldersTable = @{}
    $buildZipList = @()
    $buildSrcFolderList = @()

    foreach ($subfolder in $folders) {
        $folderName = $subfolder.Name -replace ' ', '_'
        $FolderModDate = $subfolder.LastWriteTime.ToString("MMddyyyy")
        #$dateStamp = (Get-Item $FolderModDate).ToString("MMddyyyy")
        $plat = Get-PlatformShortName #-path $sourceFolder
        
        $finalName = "$folderName" + "_$FolderModDate" + "_$plat.zip"

        #$buildZipList += $finalName
        $DestZipExist = Join-Path -Path $destinationFolder -ChildPath $finalName
        #$srcZipExist = Join-Path -Path $sourceFolder -ChildPath $finalName

        if (-not (Test-Path -Path $DestZipExist)) {

            $buildSrcFolderList += $subfolder

            #Write-Host "Zip needs to be created $DestZipExist"
            #$buildZipList += $finalName
            #$buildZipList += $srcZipExist
            $buildZipList += $DestZipExist
            #Write-Host "not Found zip file in backup folder, $destinationFolder"
            #Write-Host "finalname: $srcZipExist"
            #Write-Host "destzipex: $DestZipExist"
        }

        
        
        #Write-Host "filename: $finalName"
        #Write-Host "contents of Zip list is $buildZipList"
        #Write-Host "value of destzipexist is $DestZipExist"

    }

    # Fill the hashtable
    for ($i = 0; $i -lt $buildSrcFolderList.Length; $i++) {
        $ZipFoldersTable[$buildSrcFolderList[$i]] = $buildZipList[$i]
    }

   
#    Write-Host "contents of Zip list is $buildZipList"
    #Write-Host "buildSrcFolderList is $buildSrcFolderList"
    
    #Write-Host "contents of Zip list is $buildZipList"
    #return $buildZipList
    return $ZipFoldersTable
}

function Go-SteamZipper {
    $ZipToCreate = Confirm-ZipFileReq
    #Write-Host "ZipFoldersTable value is $ZiptoCreate"



    # not sure write-progress is necessary but i'm trying it out
    $currentFolderIndex = 0
    $totalFolders = $ZipToCreate.Count
    

    foreach ($key in $ZipToCreate.Keys) {
        Write-Host "$key **maps to** $($ZipToCreate[$key])"
    
        $currentFolderIndex++
        $percentComplete = ($currentFolderIndex / $totalFolders) * 100
        Write-Progress -Activity "Zipping files" `
                        -Status "Zipping $($key.Name)" `
                        -PercentComplete $percentComplete
    
        Compress-Archive -Path $key -DestinationPath $($ZipToCreate[$key])
    }


}

Go-SteamZipper
#Confirm-ZipFileReq



#$digModDate = Get-FiileFolderModifiedDate
#Write-Host "digModDate is $digModDate"
#
#$PlatName = Get-PlatformShortName -path $sourceFolder
#Write-Host "platform name is $PlatName"
#
#$existingZipDate = Get-DateFromZipName -zipFileName Outzone_10152024_steam.zip
#Write-Host "existing zip date is $existingZipDate"
#
#$folderName = "dig dog"
#$zipName = $folderName -replace ' ', '_'
#Write-Host "zip file name is $zipName"
#
#$zipFileName = "${zipName}_${existingZipDate}_${PlatName}.zip"
#Write-Host "generated zip file name is $zipFileName"
#
#Write-Host "for the game outzone, the final zip file name will be:"
#$zipNameAssemble = "Horizon_Chase" + "_" + $digModDate + "_" + $PlatName + ".zip"
#Write-Host "$zipNameAssemble"
#
#
#if (Get-DateFromZipName -zipFileName $zipNameAssemble -eq $digModDate) {
#    Write-Host "value of zipNameAssemble is $zipNameAssemble and file mod date is $digModDate"
#    Write-Host "there's a match"
#} else {
#    Write-Host "_there was not a match_"
#    Write-Host "value of zipNameAssemble is $zipNameAssemble and file mod date is $digModDate"
#}
#
























#Get-ChildItem -Path $sourceFolder -Directory | ForEach-Object {
#
#    # Get the last modified date of the folder
#    $folderModifiedDate = $_.LastWriteTime
#    $dateStamp = $folderModifiedDate.ToString("MMddyyyy") # Format the date as MMDDYYYY
#
#}


########################################################################
#function Compress-Subfolders {
#    param (
#        [string]$sourceFolderPath,
#        [string]$destinationFolderPath,
#        [string]$folderName,
#        [string]$platformShortName,
#        [string]$dateStamp
#    )
#
#    $zipFileName = "${folderName}_${dateStamp}_${platformShortName}.zip"
#    $zipFilePath = Join-Path -Path $destinationFolderPath -ChildPath $zipFileName
#
#    if ($platformShortName -eq "") {
#        $platformShortName = Get-PlatformShortName
#        Write-Host "platformShortName is $platformShortName"
#    }
#
#    # check if zip file already exists
##    if (Test-Path -Path $zipFileName) {
#    if (1 -eq 1) {
#        # extract date from existing zip file name and compare with fodler last modified date
#        $existingDate = ($zipFileName -split "_")[1]
#        $folderModifiedDate = (Get-Item $sourceFolderPath).LastWriteTime.ToString("MMddyyyy")
#
#        Write-Host "zip file name is $zipFileName and zip file path is $zipFilePath"
#        Write-Host "existing date is $existingDate and folder modified date is $folderModifiedDate"
#        Write-Host "source folder path is $sourceFolderPath and destionation folder path is $destinationFolderPath"
#
#        #        
#
#        if ($existingDate -eq $folderModifiedDate) {
#            Write-Host "Skipping $folderName (no changes since $existingDate)"
#            return
#        } else {
#            Write-Host "Updating folderName (folder modified after $existingDate)"
#        }
#    }
#    # create zip file
#    Compress-Archive -Path "$sourceFolderPath\*" -DestinationPath $zipFilePath -Force
#    Write-Host "compress-archive command here"
#    Write-Host "created/updated: $zipFileName"
#}
#
#function Get-FolderInfoAndZip {
#    param (
#        [string]$sourceFolder,
#        [string]$destinationFolder
#    )
#
#    if (-not (Test-Path -Path $destinationFolder)) {
#        New-Item -Path $destinationFolder -ItemType Directory
#    }
#
#    $folders = Get-ChildItem -Path $sourceFolder -Directory
#    $totalFolders = $folders.Count
#
#    foreach ($subfolder in $folders) {
#        $folderName = $subfolder.Name -replace ' ', '_' 
#        $folderModifiedDate = (Get-Item $subfolder.FullName).LastWriteTime.ToString("MMddyyyy")
#        $platformShortName = Get-PlatformShortName -path $subfolder.FullName
#        
#        param ($src, $dest, $fname, $platform, $dStamp)
##
#        Compress-Subfolders -sourceFolderPath $src, -destinationFolderPath $dest -folderName $fname -platformShortName $platform -dateStamp $dStamp
#
#        Write-Host "folderName is $folderName, foldermodifieddate is $folderModifiedDate and platformShortName is $platformShortName"
#    }
#
#
#}
#
#Get-FolderInfoAndZip -sourceFolder $sourceFolder -destinationFolder $destinationFolder


# -sourceFolder $sourceFolder -destinationFolder $destinationFolder

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