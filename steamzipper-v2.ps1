# Original steamzipper repo found at
# https://github.com/tildesarecool/SteamZipper
# Oct 2024

# module to look into later:
# https://github.com/santisq/PSCompression/tree/main
# (i found it on the PS gallery https://www.powershellgallery.com/packages/PSCompression/2.0.7)

# set default for max number of parallel jobs
# e.g. the number of zip operations happening at once
# you can adjust this by appending things like 
# * 2 or / 2 
# to increase/decrease this 
$Global:maxJobs = [System.Environment]::ProcessorCount 
#Set-Variable -Name "maxJobs" -value ([System.Environment]::ProcessorCount ) -Scope global -Option ReadOnly
# --------------------------------------
# hopefully this is straight forward: 
# MM is month, dd is day and yyyy is year
# so if you wanted day-month-year you'd change this to
# ddMMyyyy (in quotes)
# DON'T RUN IT ONCE AND CHANGE IT as the script isn't smart enough to recognize a different format (although I haven't tested this)
# (the file names will be off too)
# also, MUST CAPITALIZE the MM part. Capital MM == month while lower case mm == minutes. So capitalize the "M"s
#$Global:PreferredDateFormat = "MMddyyyy"
Set-Variable -Name "PreferredDateFormat" -value ("MMddyyyy") -Scope global -Option ReadOnly
# --------------------------------------
# Specify the folder minimum size limit (in KB) (see function Get-FolderSizeKB below)
# this constant is the minimum size a folder can contain before it will be zipped up
# Or said another way "no reason to backup/zip a 0KB sized folder"
# I just set this arbitrarily to 50KBs - adjust this number as you see fit
#$Global:sizeLimitKB = 50 
Set-Variable -Name "sizeLimitKB" -Value 50 -Scope global -Option ReadOnly
# --------------------------------------
# This is more of a place holder. In case compress-archive ever supports more compression formats than zip (like 7z, rar, gzip etc)
# could also use it in conjuction with a compress-archive alternative like 7zip CLI which supports compression to other formats
# I'm trying to be future-forward thinking and/or modular but I may be adding additional complexity for no good reason
Set-Variable -Name "CompressionExtension" -Value "zip" -Scope global -Option ReadOnly


# Script parameters (this should be the very first thing in the script)
param (
    [Parameter(Mandatory=$true)]
    [string]$sourceFolder,      # Source folder with subfolders to zip

    [Parameter(Mandatory=$true)]
    [string]$destinationFolder,  # Destination folder for the zip files

    [Parameter(Mandatory=$false)] # Optional parameter with a default value
    [string]$jobs,

    [Parameter(Mandatory=$false)] # Optional parameter: keep outdated zip file with old date code in name along side new/updated zip file.
    [string]$KeepDuplicateZips  
)


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

#$PlatName = Get-PlatformShortName -path $sourceFolder
#Write-Host "platform name is $PlatName"


function Get-FolderSizeKB {
    param (
        [string]$folderPath
    )
    # Specify the folder path and the size limit (in KB)
    # $sizeLimitKB now defined as constant at top of script
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


function Get-FileDateStamp {
        # $FileName is either a path to a folder or the zip file name. 
        # must pass in whole path for the folder but just a file name is fine for zip
        # so the folder i do the lastwritetime.tostring to get the date
        # and zip file name parse to date code with the [-2]
    param (
        [Parameter(Mandatory=$true)]
        $FileName
    )

    # this is something of an "undocumented feature". Sending in random date codes in 8-digit format returns a date object.
    # I don't know why, just seemed to match the vibe of the function so why not?
    if (   ($FileName -is [string]) -and ($FileName.Length -eq $PreferredDateFormat.Length)   ) {
        try {
            $datecode = $FileName
            return [datetime]::ParseExact($datecode,$PreferredDateFormat,$null)
        } catch {
            Write-Output "Warning: Invalid DateCode format. Expected format is $PreferredDateFormat."
            return $null
        }
    }

    $item = $FileName
    $justdate = ""

    if (Test-Path -Path $item -PathType Container) {
        # this may be a little redundant but I'm just going to go with it
        $FolderModDate = (Get-Item -Path $item).LastWriteTime.ToString($PreferredDateFormat)
        $FolderModDate = [datetime]::ParseExact($FolderModDate,$PreferredDateFormat,$null)
        if ($FolderModDate -is [datetime]) {
            return $FolderModDate
        }
    } elseif  (Test-Path -Path $item -PathType Leaf) {
        try {
            $ext = $item -split '\.' 
            $ext = $ext[-1]
            if ($ext -eq $CompressionExtension) { # this may not be necessary. different extensions could be added though. So I'll keeep it.
                $justdate = $item -split "_"
                if ($justdate.Length -ge 2) {
                    $justdate = $justdate[-2]
                    if ($justdate.Length -eq 8) {
                        return [datetime]::ParseExact($justdate,$PreferredDateFormat,$null)
                    }
                }
            }
        }
        catch {
            Write-Host "Unable to determine or convert to date object from value $justdate"
            return $null
         }
    }   
}

#$getDate = Get-FileDateStamp "P:\steamzipper\backup\Dig_Dog_10152024_steam.zip"
#$getDate = Get-FileDateStamp "P:\steamzipper\steam temp storage\Horizon Chase"
#Write-Host "Value returned for the function is the date $getDate"

# Get-DestZipDateString "Horizon_Chase_10152024_steam.zip" # seems to work with test data

function BuildZipTable  {
    #$folders = Get-ChildItem -Path $sourceFolder -Directory #output is all subfolder paths on one line
    #Write-Host "value of folders is $folders"
    $ZipFoldersTable = @{}
    $buildZipList = @()
    $buildSrcFolderList = @()

#    foreach ($subfolder in $folders) {
    # i was debaining on whether to use this $SourceDir directly from the parameter passed in to the script
    # or define it separately as a parameter
    # I decided to use the script parameter directly because that parameter is mandatory and validated elsewhere
    Get-ChildItem -Path $SourceDir -Directory | ForEach-Object {
        # start construction of zip file name:
        # 1. replace spaces with '_' underscores in folder name
        $folderName = $_.Name -replace ' ', '_'
        $folderPath = $_.FullName
#        $FolderModDate = $subfolder.LastWriteTime.ToString($PreferredDateFormat)
        # 2. bring in the date stamp (converted to date object)
        $FolderModDate = Get-FileDateStamp $folderName
        # 2a. convert date object to date code string
        $FolderModDateCode = $folderModDate.ToString($PreferredDateFormat)
        # 3. store the platform name for appending
        $platformName = Get-PlatformShortName
        # 4. join the variables into one long zip file name...
        $zipFileName = "$folderName`_$($FolderModDateCode)`_$platformName.$CompressionExtension"

        #5. join destination path together with the 
        $zipPath = Join-Path -Path $destinationFolder -ChildPath $zipFileName

        $conditions = @(
            { Get-FolderSizeKB -folderPath $folderPath } # checking current folder size - e.g. is it an empty folder and therefore skippable?
        )

        $shouldskip = $conditions | ForEach-Object {
            if ( -not (&$_)) {
                return $true
            }
        }
        if ($shouldskip) {
            Write-Output "Skipping '$foldername' due to failing one or more conditions."
            return
        }

        # check for existing zip files for the same folder
        $existingZipFiles = Get-ChildItem -Path $destinationFolder


        # I'm trying date string extract instead of query date last modified of zip to see if it makes more sense
        # $existZipModDate = Get-DestZipDate $DestZipExist
#        $existZipModDate = Get-FileDateStamp $DestZipExist


        #$skipFlag = 0
        $TestFolderSize = Get-FolderSizeKB $subfolder
        #Write-Host "Value of getkb is $TestFolderSize"
#        $ConvertedFolderModDate = [datetime]::ParseExact($FolderModDate,$PreferredDateFormat,$null)
        $ConvertedFolderModDate = Get-FileDateStamp $FolderModDate # [datetime]::ParseExact($FolderModDate,$PreferredDateFormat,$null)
#        Write-Host "ConvertedFolderModDate value is $ConvertedFolderModDate"

        $DoesZipExist = Test-Path -Path $DestZipExist # bool that determines if the zip exists, yes/no

        if (-not ($DoesZipExist) -or  (  `
        ($DoesZipExist  ) -and ( $existZipModDate -lt $ConvertedFolderModDate) `
        
        ) -and $TestFolderSize)  {
           $buildSrcFolderList += $subfolder
           $buildZipList += $DestZipExist
        } 

#        if (-not (Test-Path -Path $DestZipExist) -or ((Test-Path -Path $DestZipExist  ) `
#          -and ( $existZipModDate -lt $ConvertedFolderModDate)) -and $TestFolderSize)  {
#            $buildSrcFolderList += $subfolder
##            Write-Host "folderdatemod is $folderModDate and destzipexist mod date is " + $DestZipExist.LastWriteTime.ToString('MMddyyyy')
#            $buildZipList += $DestZipExist
#        } 
#        elseif ((Test-Path -Path $DestZipExist -eq $true) -and ( $DestZipExist.LastWriteTime.ToString("MMddyyyy") -gt $FolderModDate)) {
#        } 
    }
    # Fill the hashtable
    for ($i = 0; $i -lt $buildSrcFolderList.Length; $i++) {
        $ZipFoldersTable[$buildSrcFolderList[$i]] = $buildZipList[$i]
    }
    
    return $ZipFoldersTable
} # end of the BuildZipTable  function. if that wasn't clear.

if (-not (Define-Jobs) ) {
    function Go-SteamZipper-Jobless {
        $ZipToCreate = BuildZipTable 
        #Write-Host "ZipFoldersTable value is $ZiptoCreate"
        # not sure write-progress is necessary but i'm trying it out
        $currentFolderIndex = 0
        $totalFolders = $ZipToCreate.Count
        foreach ($key in $ZipToCreate.Keys) {
    #        Write-Host "$key **maps to** $($ZipToCreate[$key])"
            $currentZip = Split-Path -Path $($ZipToCreate[$key]) -Leaf
            $currentFolderIndex++
    #        $percentComplete = ($currentFolderIndex / $totalFolders) * 100

            # attempt to deal with error message 
            try {
            Write-Host "Currently zipping source folder '$key' to destination zip file '$currentZip' ($currentFolderIndex of $totalFolders)"
    #        Write-Progress -Activity "Zipping files" `
    #                        -Status "Zipping $($key.Name)" `
    #                        -PercentComplete $percentComplete    
            Compress-Archive -Path $key -DestinationPath $($ZipToCreate[$key])
            }
            catch {
                Write-Host "Failed to create the destination zip file $currentZip"
                Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }
#############################################################
Go-SteamZipper-Jobless
#############################################################
}
elseif (Define-Jobs) {
    function Go-SteamZipper-Jobbed {
        Write-Host "entering jobbed version of the zipper"
        $getMax = Define-Jobs
        $jobList = @() # create empty list for 'job pool' (like dog pool but uglier)
        $ZipToCreate = Confirm-ZipFileReq # BuildZipTable hashtable of source folders to destination zip file names
        $currentFolderIndex = 0 # to count total completed zips
        $totalFolders = $ZipToCreate.Count # total number of records in the hashtable, total jobs to do
        
        foreach ($key in $ZipToCreate.Keys) {
            $currentZip = Split-Path -Path $($ZipToCreate[$key]) -Leaf # just zip name for the providing information to the user
            $currentFolderIndex++ # increment zip job counter. probably don't need for job version
            while ($jobList.Count -ge $getMax) {
                # while the number jobs is less than or equal to my set max jobs
                # I think I understand what this does. Maybe.
                $jobList = $jobList | Where-Object { $_.State -eq 'Running'}
                Start-Sleep -Seconds 1
            }
            $oneJob = Start-Job -ScriptBlock { Compress-Archive -Path $key -DestinationPath $($ZipToCreate[$key]) }

            $jobList += $oneJob
            Write-Host "value of joblist currently is $jobList"

        }

    }

#    Write-Host "Jobs enabled. Value of getMax is $getMax."
#############################################################
    Go-SteamZipper-Jobbed
#############################################################
}


#function Define-Jobs {
#    if ( ($jobs -eq "enable-jobs") -or ($jobs -eq "enablejobs") )  {
#        # this should skip if $jobs isn't specific or something not "enable-jobs"/enablejobs is passed in
#        # and the -eq should default to non-case sensitive. So that's a relief.
#
#            # this function and therefore variable is only defined if jobs is enabled from the execution of the script
#            # ProcessorCount should be considered a starting off point. You could make it ProcessorCount  * 2
#            # or ProcessorCount / 2 (assuming an even number of CPU cores/threads)
#            # zip operations are most likely to run into a CPU bottleneck (unless you have a really slow storage device?)
#            $maxJobs = [System.Environment]::ProcessorCount 
#    #        $jobslist = @()
#            return $maxJobs
#        }
#    return $false
#}
#        $zipFinalName = "$folderName" + "_$FolderModDate" + "_$plat.$CompressionExtension" # I could make 'zip' a global variable. so the script can work with other compression formats. maybe later.
        
        #$zipFileName = "$folderName`_$($folderModDate.ToString($PreferredDateFormat))`_$platformName.$CompressionExtension"