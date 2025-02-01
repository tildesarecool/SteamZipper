# Original steamzipper repo found at
# https://github.com/tildesarecool/SteamZipper
# v3
# Feb 2025

# pwsh -command '& { .\steamzipper-v3.ps1 "P:\steamzipper\steam temp storage" "P:\steamzipper\backup-steam\" -KeepDuplicateZips }'

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
    [string]$jobs,

    [switch]$KeepDuplicateZips

    #    [Parameter(Mandatory=$false)] # Optional parameter: keep outdated zip file with old date code in name along side new/updated zip file.
#    [string]$KeepDuplicateZips  
)

# set default for max number of parallel jobs
# e.g. the number of zip operations happening at once
# you can adjust this by appending things like 
# * 2 or / 2 
# to increase/decrease this 
if (-not (Test-Path Variable:\maxJobs   )) {
    Set-Variable -Name "maxJobs" -Value [System.Environment]::ProcessorCount -Scope Global -Option ReadOnly
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
if (-not (Test-Path Variable:\sizeLimitKB)) {
    # Specify the folder minimum size limit (in KB) (see function Get-FolderSizeKB below)
# this constant is the minimum size a folder can contain before it will be zipped up
# Or said another way "no reason to backup/zip a 0KB sized folder"
# I just set this arbitrarily to 50KBs - adjust this number as you see fit

    Set-Variable -Name "sizeLimitKB" -Value 50 -Scope Global -Option ReadOnly
}
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
    Set-Variable -Name "scriptfolder " -Value Split-Path -Parent $MyInvocation.MyCommand.Path-Scope Global -Option ReadOnly
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




#################### hey, new feature! save preferences to a json file in the source folder by default ##########
#################### obviously this comes after dealing with source/destination folders


# Define preference file path in the script's directory
$preferenceFile = Join-Path -Path $scriptFolder -ChildPath "steamzipper-preferences.json"

# note: make sure these preferences match the JSON and vice-versa
# Default preferences structure
$defaultPreferences = @{
    DefaultPreferences = @{
        PreferredDateFormat  = "MMddyyyy"
        maxJobs             = [System.Environment]::ProcessorCount
        sizeLimitKB         = 0  # No size limit by default
        CompressionExtension = ".zip"
        maxLogFiles         = 5  # Retain the last 5 log files. for start-transcript functionality.
    }
    UserPreferences = @{}  # Empty for now, to be used later
}

# Check if preference file exists, load or create it
if (Test-Path -Path $preferenceFile) {
    try {
        $userPreferences = Get-Content -Path $preferenceFile | ConvertFrom-Json
        Write-Host "Loaded user preferences from $preferenceFile"
    } catch {
        Write-Host "Failed to read preferences file. Using defaults." -ForegroundColor Yellow
        $userPreferences = $defaultPreferences
    }
} else {
    # Save default preferences to a new JSON file
    $defaultPreferences | ConvertTo-Json -Depth 3 | Set-Content -Path $preferenceFile
    Write-Host "Created default preference file at: $preferenceFile"
    $userPreferences = $defaultPreferences
}


#################### second new feature: 
#################### using start transcript to record information for later review using Start-Transcript
# Define log file path in the script's directory

# Load maxLogFiles from preferences (use default if missing)
$maxLogFiles = $userPreferences.DefaultPreferences.maxLogFiles

# Define log file path (fixed name)
$logFile = Join-Path -Path $scriptFolder -ChildPath "steamzipper-log.txt"

# Remove old log files beyond the limit
$logFiles = Get-ChildItem -Path $scriptFolder -Filter "steamzipper-log*.txt" | Sort-Object LastWriteTime -Descending
if ($logFiles.Count -ge $maxLogFiles) {
    $logFiles[$maxLogFiles..($logFiles.Count - 1)] | Remove-Item -Force
}

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






























################################################################################
# Clean up ReadOnly variables at script end: VERY LAST STATEMENTS OF ENTIRE SCRIPT
Remove-Variable -Name "PreferredDateFormat" -Scope Global -Force 
Remove-Variable -Name "maxJobs" -Scope Global -Force
Remove-Variable -Name "sizeLimitKB" -Scope Global -Force
Remove-Variable -Name "CompressionExtension" -Scope Global -Force