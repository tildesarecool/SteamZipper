# Original steamzipper repo found at
# https://github.com/tildesarecool/SteamZipper
# v3
# Feb 2025

# pwsh -command '& { .\steamzipper-v3.ps1 "P:\steamzipper\steam temp storage" "P:\steamzipper\backup-steam\" -KeepDuplicateZips }'
# Set-ItemProperty -Path "P:\steamzipper\zip test output\testfile1.zip" -Name LastWriteTime -Value "2024-10-10T12:00:00"
# Get-ChildItem -Path "P:\steamzipper\zip test output" | Sort-Object LastWriteTime -Descending | Select-Object Name, LastWriteTime

# A perpetually grunting man-freak-beast dressed in WWII-garb semi-terrorizes the French countryside.
# Meanwhile, a vacationing couple take shelter in an ominous, gothic chateau for the night. The elderly 
# keepers of the grand castle tell a tale of a galleon running aground from five pillagers setting a 
# huge bonfire on a nearby beach to lure the ship in. This prompts the old drunkard owner to take a 
# shotgun with unlimited ammo out to murder a wild black stallion for ten continuous hours. The ghostly 
# galleon then erupts from a cake doubling as a mountainside as its contents of barrels and an 
# Egyptian casket spill forth. A mummy emerges with a thunder clap and the young vacationing woman 
# ends up in the middle of it all in a fight for survival after leaving the safety of the medieval fortress.
# Color / 73 mins / 1985
# HORSE! HORSE! HORSE! HORSE! HORSE! HORSE! HORSE! HORSE! 

# Script parameters (this should be the very first thing in the script)
param (
    [Parameter(Mandatory=$true)]
    [string]$sourceFolder,      # Source folder with subfolders to zip

    [Parameter(Mandatory=$true)]
    [string]$destinationFolder,  # Destination folder for the zip files

    [Parameter(Mandatory=$false)] # Optional parameter with a default value
    #[string]$jobs, # i don't remember any more if I had made $jobs a string for a specific reason. it won't be established until later anyway so I'm changing it to [int]
    [int]$jobs,

    [switch]$KeepDuplicateZips

    #    [Parameter(Mandatory=$false)] # Optional parameter: keep outdated zip file with old date code in name along side new/updated zip file.
#    [string]$KeepDuplicateZips  
)

# set default for max number of parallel jobs
# e.g. the number of zip operations happening at once
# you can adjust this by appending things like 
# * 2 or / 2 
# to increase/decrease this 
if (-not (Test-Path Variable:\maxJobsDefine   )) {
    Set-Variable -Name "maxJobsDefine" -Value $([System.Environment]::ProcessorCount) -Scope Global -Option ReadOnly
    #$maxJobsDefine = [int]$maxJobsDefine
    #Write-Host "value of maxjobdefine is $maxJobsDefine"
}


# Define constants only if they are not already defined
# --------------------------------------
if (-not (Test-Path Variable:\PreferredDateFormat) ) {
    # hopefully this is straight forward: 
# MM is month, dd is day and yyyy is year
# so if you wanted day-month-year you'd change this to
# ddMMyyyy (in quotes)
# DON'T RUN IT ONCE AND CHANGE IT as the script isn't smart enough to recognize a different format (although I haven't tested this)
# (the file names will be off too)
# also, MUST CAPITALIZE the MM part. Capital MM == month while lower case mm == minutes. So capitalize the "M"s
#$Global:PreferredDateFormat = "MMddyyyy"

    Set-Variable -Name "PreferredDateFormat" -Value "MMddyyyy" -Scope Global -Option ReadOnly
}

#if (-not (Test-Path Variable:\maxJobs)) {
#    Set-Variable -Name "maxJobs" -Value ([System.Environment]::ProcessorCount) -Scope Global -Option Constant
#}
# --------------------------------------
#if (-not (Test-Path Variable:\sizeLimitKB)) {
#
#
#
#
#
#    Set-Variable -Name "sizeLimitKB" -Value 50 -Scope Global -Option ReadOnly
#}







# --------------------------------------
if (-not (Test-Path Variable:\CompressionExtension)) {
    # This is more of a place holder. In case compress-archive ever supports more compression formats than zip (like 7z, rar, gzip etc)
# could also use it in conjuction with a compress-archive alternative like 7zip CLI which supports compression to other formats
# I'm trying to be future-forward thinking and/or modular but I may be adding additional complexity for no good reason
    Set-Variable -Name "CompressionExtension" -Value "zip" -Scope Global -Option ReadOnly
}

if (-not (Test-Path Variable:\scriptfolder )) {
    # this is just setting up a variable for the current working directory the script is running from so this value
    # can be accessed by the preferences file creation folder and the start-transcription lines below
    # as well as any other instance that might need that for some reason
    Set-Variable -Name "scriptfolder" -Value (Split-Path -Parent $MyInvocation.MyCommand.Path) -Scope Global -Option ReadOnly
}


if (! (Test-Path $sourceFolder) ) {
    Write-Error -message "Error: Source folder $sourceFolder not found, exiting..."
    exit 1
}

# Create the destination folder if it doesn't exist
if (-not (Test-Path -Path $destinationFolder)) {
    try {
        New-Item -Path $destinationFolder -ItemType Directory -ErrorAction Stop
        Write-Host "Successfully created the folder: $destinationFolder"
    }
    catch {
        # I have yet to test to 'catch' statement. I'll just assume it works
        Write-Host "Failed to create the destination folder at: $destinationFolder" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
        exit 1
        
    }
}

function Get-PlatformShortName {
    #    param (
    #        [string]$path
    #    )
    
        $path = $sourceFolder
        # additional platforms (xbox (Windows store?), origin, uplay, etc) can be added to the table below
        # easiest way would be to copy/paste an existing line
        # and modify it left/right (sample origin below. remove # to enable)
        $platforms = @{
            "epic games"   = "epic"
            "Amazon Games" = "amazon"
            "GOG"          = "gog"
            "Steam"        = "steam"
            #"Origin"        = "origin"
        }
        Set-Variable -Name $platforms -Option ReadOnly
        # fortunately, the -like parameter is NOT case sensitive by default
        foreach ($platform in $platforms.Keys) {
            if ($path -like "*$platform*") {
                return $platforms[$platform]
            }
        }
        return "unknown"  # Default value if no match
}

#############################################################
# # at least as of this test (Feb 4th) this function tests valid
# Get-PlatformShortName #(using P:\steamzipper\steam temp storage for input path) # returned "steam" successfully
# Get-PlatformShortName #(using P:\steamzipper\gog temp storage for input path) # returned "gog" successfully
#############################################################



#################### hey, new feature! save preferences to a json file in the source folder by default ##########
#################### obviously this comes after dealing with source/destination folders


# Define preference file path in the script's directory
$preferenceFile = Join-Path -Path $scriptFolder -ChildPath "steamzipper-preferences.json"

# Note: Specify the folder minimum size limit (in KB) (see function Get-FolderSizeKB below)
# this constant is the minimum size a folder can contain before it will be zipped up
# Or said another way "no reason to backup/zip a 0KB sized folder"
# I just set this arbitrarily to 50KBs - adjust this number as you see fit
# this folder size kilobyte minimum is stored in the JSON file

# note: make sure these preferences match the JSON and vice-versa
# Default preferences structure

#   $defaultPreferences = @{
#       DefaultPreferences = @{
#           #PreferredDateFormat  = $PreferredDateFormat
#           maxJobs             = $maxJobsDefine
#           sizeLimitKB         = 50  # No size limit by default
#           #CompressionExtension = "zip"
#           maxLogFiles         = 5  # Retain the last 5 log files. for start-transcript functionality.
#       }
#       UserPreferences = @{}  # Empty for now, to be used later
#   }
#   
#   # Check if preference file exists, load or create it
#   if (Test-Path -Path $preferenceFile) {
#       try {
#           $userPreferences = Get-Content -Path $preferenceFile | ConvertFrom-Json
#           Write-Host "Loaded user preferences from $preferenceFile"
#       } catch {
#           Write-Host "Failed to read preferences file. Using defaults." -ForegroundColor Yellow
#           $userPreferences = $defaultPreferences
#       }
#   } else {
#       # Save default preferences to a new JSON file
#       $defaultPreferences | ConvertTo-Json -Depth 3 | Set-Content -Path $preferenceFile
#       Write-Host "Created default preference file at: $preferenceFile"
#       $userPreferences = $defaultPreferences
#   }
#   
#   $sizeLimitKB = $userPreferences.DefaultPreferences.sizeLimitKB
#   if (-not $sizeLimitKB) { $sizeLimitKB = 50 }  # Fallback to default if not set

#################### second new feature: 
#################### using start transcript to record information for later review using Start-Transcript
# Define log file path in the script's directory

# this is actually a new version of this function. hopefully it works

# intention behind this start-transcript section
# implement a "rolling log" sort of approach to the transcript:
# 1. start with steamzipper-log-01.txt, use that as the log until the file reaches 500KB
# 2. from there start on the next file, -log-02.txt and so on through -log-05.txt
# 3. once  -log-05.txt is 500KB start back with steamzipper-log-01.txt, over-writing the original file
# 4. then proceed with the 2, 3, 4 and 5 files and back to one. 
# I was trying to fine a balance between lots of logs and not having a txt file taking up my whole HDD 
# during development of the script.

# Define log settings
$logFolder = $scriptFolder
$logBaseName = "steamzipper-log"
$logExtension = ".txt"
$maxLogFiles = 5
$maxLogSizeKB = 500  # Maximum log size before rolling over (500KB)

# Function to determine the next log file to use
function Get-NextLogFile {
    for ($i = 1; $i -le $maxLogFiles; $i++) {
        $logFile = Join-Path -Path $logFolder -ChildPath "$logBaseName-$i$logExtension"
        
        # If file does not exist, use it
        if (!(Test-Path -Path $logFile)) {
            return $logFile
        }

        # If file exists but is under the max size, continue using it
        if ((Get-Item $logFile).Length / 1KB -lt $maxLogSizeKB) {
            return $logFile
        }
    }

    # If all log files are full, start back at -1 (overwrite)
    return Join-Path -Path $logFolder -ChildPath "$logBaseName-1$logExtension"
}

# Determine the log file to use
$logFile = Get-NextLogFile

# Start transcript logging
try {
    Start-Transcript -Path $logFile -Force
    Write-Host "Logging started: $logFile"
} catch {
    Write-Host "Failed to start transcript logging: $($_.Exception.Message)" -ForegroundColor Red
}




function Get-FolderSizeKB {
    param (
        [string]$folderPath
    )
    # Specify the folder path 
    # $sizeLimitKB defined as constant at top of script
    $FolderSizeKBTracker = 0

    foreach ($file in Get-ChildItem -Path $folderPath -Recurse -File) {
        $FolderSizeKBTracker += $file.Length / 1KB

        # exit if size limit exceeded
        if ($FolderSizeKBTracker -ge $sizeLimitKB) {
            return $true
        }
    }
    return $false
}

#############################################################
# at least as of this test (11:50 Feb 4th) this function tests valid
#Get-FolderSizeKB "P:\steamzipper\steam temp storage\cyberpunk" # folder exists but has no files (under minimum KB size)
#Get-FolderSizeKB "P:\steamzipper\steam temp storage\PAC-MAN" # folder exists and has files (over minimum KB size)
#############################################################

function Get-FileDateStamp {
    # $FileName is either a path to a folder or the zip file name. 
    # must pass in whole path for the folder but just a file name is fine for zip
    # so the folder i do the lastwritetime.tostring to get the date
    # and zip file name parse to date code with the [-2]
param (
    [Parameter(Mandatory=$true)]
    $FileName
)
if (   ($FileName -is [string]) -and ($FileName.Length -eq $PreferredDateFormat.Length)   ) {
    try {
        $datecode = $FileName
        return [datetime]::ParseExact($datecode,$PreferredDateFormat,$null)
    } catch {
        Write-Output "Warning: Invalid DateCode format. Expected format is $PreferredDateFormat."
        return $null
    }
}
$justdate = ""
if (Test-Path -Path $FileName -PathType Container) {
    Write-Host "Inside get-filedatestamp, the filename parameter is $FileName"
    $FolderModDate = (Get-Item -Path $FileName).LastWriteTime.ToString($PreferredDateFormat)
    $FolderModDate = [datetime]::ParseExact($FolderModDate,$PreferredDateFormat,$null)
    if ($FolderModDate -is [datetime]) {
        return $FolderModDate
    }

    } elseif  (Test-Path -Path $FileName -PathType Leaf) {
        try {
                $justdate = $FileName -split "_"
                if ($justdate.Length -ge 2) {
                    $justdate = $justdate[-2]
                    if ($justdate.Length -eq 8) {
                        return [datetime]::ParseExact($justdate,$PreferredDateFormat,$null)
                    }
                }
        }
        catch {
            Write-Host "Unable to determine or convert to date object from value $justdate"
            return $null
         }
    }  elseif  ( (!(Test-Path -Path $FileName -PathType Leaf)) -and (!( Test-Path -Path $FileName -PathType Container) ) )    {
        Write-Host "the filename parameters, $FileName, is not a folder or a file"
        return $null
        }
}


#############################################################
# at least as of this test ( Feb 4th) this function tests valid
 #Get-FileDateStamp "P:\steamzipper\backup-steam\Horizon_Chase_11152024_steam.zip"
 #Get-FileDateStamp "P:\steamzipper\steam temp storage\PAC-MAN"
 #Get-FileDateStamp "10162024"
  #Get-FileDateStamp "P:\steamzipper\steam temp storage\PACMAN"
#############################################################

function Build-SourceAndDestinationTables {
    param (
        [string]$sourceFolder,
        [string]$destinationFolder
    )

    # Initialize empty hash tables
    #$sourceFoldersInTable = @{}
    #$destinationZipsInTable = @{}

    Write-Host "Debug: Processing source folders..." -ForegroundColor Cyan
    $sourceFoldersInTable = @{}
    Get-ChildItem -Path $sourceFolder -Directory | ForEach-Object {
    $sourceFoldersInTable[$_.FullName] = Get-FileDateStamp $_.FullName
    Write-Host "  Added: $($_.FullName) -> $($sourceFoldersInTable[$_.FullName])"
}

Write-Host "`nDebug: Processing destination zips..." -ForegroundColor Green
$destinationZipsInTable = @{}
Get-ChildItem -Path $destinationFolder -Filter "*.$CompressionExtension" | ForEach-Object {
    $zipNameParts = $_.BaseName -split "_"
    $dateCode = $zipNameParts[-2]
    
    if ($dateCode -match "^\d{8}$") {
        $destinationZipsInTable[$_.FullName] = Get-FileDateStamp $dateCode
        Write-Host "  Added: $($_.FullName) -> $($destinationZipsInTable[$_.FullName])"
    } else {
        Write-Host "  Skipped (invalid date format): $($_.FullName)" -ForegroundColor Yellow
    }
}
    return @{
        SourceFoldersInTable   = $sourceFoldersInTable
        DestinationZipsInTable = $destinationZipsInTable
    }
}


Write-Host "Compression Extension: $CompressionExtension"

# Build the tables
#$tables = Build-SourceAndDestinationTables -sourceFolder $sourceFolder -destinationFolder $destinationFolder

# Assign table results
$sourceFoldersInTable = $tables.SourceFolders
$destinationZipsInTable = $tables.DestinationZips

# Debug Output
Write-Host " Source Folders in Table:" -ForegroundColor Cyan
foreach ($key in $sourceFoldersInTable.Keys) {
    Write-Host "  - $key => $($sourceFoldersInTable[$key])"
}

Write-Host "`n Destination Zips in Table:" -ForegroundColor Green
foreach ($key in $destinationZipsInTable.Keys) {
    Write-Host "  - $key => $($destinationZipsInTable[$key])"
}

# Verify "zip output" exists
$zipOutputFolder = Join-Path -Path $scriptfolder -ChildPath "zip test output"
if (-not (Test-Path $zipOutputFolder)) {
    Write-Host "`n  Warning: 'zip test output' folder does not exist!" -ForegroundColor Yellow
} else {
    Write-Host "`n 'zip test output' folder detected at: $zipOutputFolder" -ForegroundColor Green
}


function Determine-ZipStatus {
    param (
        [string]$sourceFolderPath,
        [hashtable]$sourceFoldersMap,
        [hashtable]$destinationZipsMap
    )

    # Extract the folder name from the full path
    $folderName = Split-Path -Leaf $sourceFolderPath
    $sourceDate = $sourceFoldersMap[$sourceFolderPath]

    Write-Host "`nChecking: $folderName (Last Modified: $sourceDate)"

    # Find matching zips
    $matchingZips = $destinationZipsMap.GetEnumerator() | Where-Object {
        $_.Key -like "*$folderName*"
    }

    if ($matchingZips.Count -eq 0) {
        Write-Host "  → No existing zip found. Needs new zip." -ForegroundColor Yellow
        return "new"
    }

    # Sort existing zips by date (newest first)
    $matchingZips = $matchingZips | Sort-Object Value -Descending
    $latestZip = $matchingZips[0]
    $latestZipDate = $latestZip.Value

    Write-Host "  → Latest zip: $(Split-Path -Leaf $latestZip.Key) (Date: $latestZipDate)"

    if ($latestZipDate -lt $sourceDate) {
        Write-Host "  → Outdated zip found. Needs update." -ForegroundColor Red
        return "update"
    }

    Write-Host "  → Zip is up-to-date. No action needed." -ForegroundColor Green
    return "skip"
}


# Call the function to build tables
$tables = Build-SourceAndDestinationTables -sourceFolder $sourceFolder -destinationFolder $destinationFolder

# Extract the hashtables from the returned object
$sourceFoldersMap = $tables.SourceFoldersInTable
$destinationZipsMap = $tables.DestinationZipsInTable

# Loop through each source folder and determine zip status
foreach ($folder in $sourceFoldersMap.Keys) {
    Determine-ZipStatus -sourceFolderPath $folder -sourceFoldersMap $sourceFoldersMap -destinationZipsMap $destinationZipsMap
}



#function DetermineZipStatusDelete {
#    param (
#        [Parameter(Mandatory=$true)]
#        [string]$szSrcFullGameDirPath,  # Path to source subfolder, e.g., "P:\steamzipper\backup-steam\Dig Dog"
#        
#        [Parameter(Mandatory=$true)]
#        [string]$szDestZipFileName      # Zip file name without extension, e.g., "Dig_Dog_11162024_steam"
#    )
#
#    Write-Host "Checking zip status for: $szDestZipFileName"
#    #     Write-Host "Checking zip status for: $szDestZipFileName$CompressionExtension" # i don't think this line is necessary
#
#
#    # Check how many matching zip files exist in the destination
#    #$existingZips = Get-ChildItem -Path $destinationFolder -Filter "$szDestZipFileName*.zip"
#    $existingZips = Get-ChildItem -Path $destinationFolder -Filter "$szDestZipFileName*$CompressionExtension"
#
#
#    $existingZipCount = $existingZips.Count
#
#    Write-Host "Existing zip file count: $existingZipCount (DetermineZipStatusDelete)"
#
#    if ($existingZipCount -eq 0) {
#        Write-Host "No zip files found. Proceeding with compression. (DetermineZipStatusDelete)"
#        return $true  # Zip needs to be created
#    }
#
#    if ($existingZipCount -eq 1) {
#        Write-Host "One zip file found. Need to compare timestamps. (DetermineZipStatusDelete)"
#        
#        # Get existing zip file
#        $existingZip = $existingZips | Select-Object -First 1
#        Write-Host "Existing zip file found: $($existingZip.Name) (DetermineZipStatusDelete)"
#        
#        # Construct the full path to the zip file
#        $zipFullPath = Join-Path -Path $destinationFolder -ChildPath $existingZip.Name
#        Write-Host "Full path to zip: $zipFullPath (DetermineZipStatusDelete)"
#        
#        # Get the date for the zip file (from the file name)
#        $zipDate = Get-FileDateStamp -FileName $zipFullPath
#        # Get the last modified date for the folder (subfolder)
#        $folderDate = Get-FileDateStamp -FileName $szSrcFullGameDirPath
#
#        # Debugging output for dates
#        Write-Host "Existing zip date: $zipDate (DetermineZipStatusDelete)" -ForegroundColor Yellow
#        Write-Host "Source folder date: $folderDate (DetermineZipStatusDelete)" -ForegroundColor Yellow
#
#        # Handle cases where date could not be determined
#        if ($null -eq $zipDate) {
#            Write-Host "Error: Could not determine date for existing zip file $zipFullPath. (DetermineZipStatusDelete)" -ForegroundColor Red
#            return $false  # Skip processing if we can't compare dates
#        }
#
#        if ($null -eq $folderDate) {
#            Write-Host "Error: Could not determine date for source folder $szSrcFullGameDirPath. (DetermineZipStatusDelete)" -ForegroundColor Red
#            return $false  # Skip processing if we can't compare dates
#        }
#        Write-Host "Comparing folder date: $folderDate with zip date: $zipDate (DetermineZipStatusDelete)" -ForegroundColor Yellow
#
#        # Compare timestamps
#        if ($folderDate -gt $zipDate) {
#            Write-Host "Folder is newer than the zip file. Moving old zip to deleted folder. (DetermineZipStatusDelete)"
#
#            # Define delete path
#            $DeletePath = Join-Path -Path $destinationFolder -ChildPath "deleted"
#            Write-Host "value of deletepath is $DeletePath (DetermineZipStatusDelete)"
#
#            # Ensure deleted folder exists
#            if (!(Test-Path -Path $DeletePath)) {
#                New-Item -Path $DeletePath -ItemType Directory -Force | Out-Null
#                Write-Host "folder of $DeletePath created successfully (DetermineZipStatusDelete)"
#            }
#
#            # Move the outdated zip
#            Move-Item -Path $zipFullPath -Destination $DeletePath -Force
#            return $true
#        } else {
#            Write-Host "Zip file is up to date. Skipping compression. (DetermineZipStatusDelete)"
#            return $false
#        }
#    }
#
#    Write-Host "More than one zip file detected. Further logic needed. (DetermineZipStatusDelete)"
#    return $false
#}
#
#
#
#
## prior to attempt to handle multiple zip matches, this test was working as far as i can tell
##DetermineZipStatusDelete "P:\steamzipper\steam temp storage_2\Dig Dog" Dig_Dog_11162024_steam # barely framework of function, accruately return a count of 1
#
##DetermineZipStatusDelete "P:\steamzipper\steam temp storage_2\Dig Dog" Dig_Dog_11162024_steam 
#
##P:\steamzipper\steam-backup
## DetermineZipStatusDelete
#
#function Tester-Function {
#    param (
#        [string]$sourceFolder,        # Source folder path
#        [string]$destinationFolder    # Destination folder for the zip files
#    )
#
#    # Loop through each subfolder in the source folder
#    Get-ChildItem -Path $sourceFolder -Directory | ForEach-Object {
#        $subFolderName = $_.Name  # Subfolder name
#
#        # Generate zip file name: replace spaces with underscores
#        $zipFileName = $subFolderName -replace ' ', '_'
#        
#        # Get the date of the subfolder and convert it to MMddyyyy format
#        $folderDate = (Get-Item $_.FullName).LastWriteTime.ToString($PreferredDateFormat)
#
#        # Get the platform from the path (example logic for platform)
#        $platform = Get-PlatformShortName  # Assuming you already have this function defined
#
#        # Construct the full zip file name (e.g., Dig_Dog_10042024_steam.zip)
#        $zipFileNameWithDate = "$zipFileName" + "_" + "$folderDate" + "_$platform" + ".$CompressionExtension"
#
#
#        # Construct the full path for the zip file in the destination folder
#        $zipFilePath = Join-Path -Path $destinationFolder -ChildPath $zipFileNameWithDate
#
#        # Log the generated zip file name for debugging
#        Write-Host "Checking zip file for: $zipFileNameWithDate (Tester-Function)"
#
#        # Check for existing zip files in the destination folder
#        $existingZips = Get-ChildItem -Path $destinationFolder -Filter "$zipFileName*$CompressionExtension"
#        $existingZipCount = $existingZips.Count
#
#        Write-Host "Existing zip file count: $existingZipCount (Tester-Function)"
#
#        if ($existingZipCount -eq 0) {
#            Write-Host "No zip files found. Proceeding with compression. (Tester-Function)"
#            
#            # Simulate a zero-byte zip file creation for testing purposes
#            New-Item -Path $zipFilePath -ItemType File -Force | Out-Null
#            Write-Host "Created zero-byte file: $zipFilePath (Tester-Function)"
#            
#            $zipStatus = DetermineZipStatusDelete -szSrcFullGameDirPath $_.FullName -szDestZipFileName $zipFileNameWithDate
#
#            if ($zipStatus) {
#                Write-Host "Zip file is warranted for: $subFolderName (`$zipFileNameWithDate`) (Tester-Function)" -ForegroundColor Green
#            } else {
#                Write-Host "No zip needed for: $subFolderName (`$zipFileNameWithDate`) (Tester-Function)" -ForegroundColor Yellow
#            }
#        } else {
#            Write-Host "Zip file already exists. Skipping creation for: $subFolderName (Tester-Function)"
#        }
#    }
#}
#
#
##Tester-Function -sourceFolder "P:\steamzipper\steam temp storage" -destinationFolder "P:\steamzipper\steam-backup"
##Tester-Function -sourceFolder "P:\steamzipper\steam temp storage" -destinationFolder "P:\steamzipper\zip test output"
##Tester-Function -sourceFolder "P:\steamzipper\steam temp storage" -destinationFolder "P:\steamzipper\zip test output"
#Tester-Function -sourceFolder "P:\steamzipper\steam temp storage" -destinationFolder "P:\steamzipper\zip test output"





################################################################################
# Clean up ReadOnly variables at script end: VERY LAST STATEMENTS OF ENTIRE SCRIPT
Remove-Variable -Name "PreferredDateFormat" -Scope Global -Force 
Remove-Variable -Name "maxJobsDefine" -Scope Global -Force
# Remove-Variable -Name "sizeLimitKB" -Scope Global -Force # still going back and forth between json and inline/both setting of this. so disable the disabling for now
Remove-Variable -Name "CompressionExtension" -Scope Global -Force