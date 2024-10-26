# Original steamzipper repo found at
# https://github.com/tildesarecool/SteamZipper
# Oct 2024

# module to look into later:
# https://github.com/santisq/PSCompression/tree/main
# (i found it on the PS gallery https://www.powershellgallery.com/packages/PSCompression/2.0.7)

# Script parameters (this should be the very first thing in the script)
param (
    [Parameter(Mandatory=$true)]
    [string]$sourceFolder,      # Source folder with subfolders to zip

    [Parameter(Mandatory=$true)]
    [string]$destinationFolder,  # Destination folder for the zip files

    [Parameter(Mandatory=$false)] # Optional parameter with a default value
    [string]$jobs
)

#Write-Host "source folder is $sourceFolder and destination folder is $destinationFolder"

# hopefully this is straight forward: 
# MM is month, dd is day and yyyy is year
# so if you wanted day-month-year you'd change this to
# ddMMyyyy (in quotes)
# DON'T RUN IT ONCE AND CHANGE IT as the script isn't 
# smart enough to recognize a different format 
# also, MUST CAPITALIZE the MM part. Capital MM == month while lower case mm == minutes. So capitalize the "M"s
$PreferredDateFormat = "MMddyyyy"

if (-not $sourceFolder -or -not $destinationFolder) {
    Write-Host "Error: Source folder and destination folder must be specified."
    exit 1
}

function Define-Jobs {
    if ( ($jobs -eq "enable-jobs") -or ($jobs -eq "enablejobs") )  {
        # this should skip if $jobs isn't specific or something not "enable-jobs"/enablejobs is passed in
        # and the -eq should default to non-case sensitive. So that's a relief.

            # this function and therefore variable is only defined if jobs is enabled from the execution of the script
            # ProcessorCount should be considered a starting off point. You could make it ProcessorCount  * 2
            # or ProcessorCount / 2 (assuming an even number of CPU cores/threads)
            # zip operations are most likely to run into a CPU bottleneck (unless you have a really slow storage device?)
            $maxJobs = [System.Environment]::ProcessorCount 
    #        $jobslist = @()
            return $maxJobs
        }
    return $false
}




function Get-PlatformShortName {
#    param (
#        [string]$path
#    )

    $path = $sourceFolder
    # additional platforms (xbox, origin, uplay, etc) can be added to the table below
    # easiest way would be to copy/paste an existing line
    # and modify it left/right (sample origin below. remove # to enable)
    $platforms = @{
        "epic games"   = "epic"
        "Amazon Games" = "amazon"
        "GOG"          = "gog"
        "Steam"        = "steam"
        #"Origin"        = "origin"
    }
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

# I realized i wasn't calling this function so there's no reason for it. 
# i think i know how to re-write it in a better way using underscore as a delimeter anyway...
# function Get-DateFromZipName {
#     param (
#         [string]$zipFileName
#     )
# 
#     $pattern = "\d{8}" # Matches an 8-digit date
#     if ($zipFileName -match $pattern) {
#         return $matches[0]
#     }
#     
#     return $null
# }

# function Get-FiileFolderModifiedDate {

function Get-FolderSizeKB {
    param (
        $folderPath
    )
    # Specify the folder path and the size limit (in KB)
    $sizeLimitKB = 50

    # Get the total size of the folder (recursively)
    $totalSize = (Get-ChildItem -Path $folderPath -Recurse -File | Measure-Object -Property Length -Sum).Sum

    # Convert size to KB
    $totalSizeKB = [math]::Round($totalSize / 1KB, 2)

    # Output the total size of the folder
    #Write-Host "Total folder size: $totalSizeKB KB"

    # Compare the total size to the size limit
    if ($totalSizeKB -gt $sizeLimitKB) {
        #Write-Host "The folder size is greater than $sizeLimitKB KB."
        return $true
    } else {
        #Write-Host "The folder size is less than or equal to $sizeLimitKB KB."
        return $false
    }

}

function Get-DestZipDate {
    param (
        $zipFileName
    )
    $splitdate = $zipFileName -split "_"
    if ($splitdate[-2] ) {
        $justdate = $splitdate[-2]
        $justdate = [datetime]::ParseExact($justdate,$PreferredDateFormat,$null)
#        Write-Host "Inside get-destzipdate, jusdate value is $justdate"
        return $justdate    
    } 
    else {
        return 000
    }

    #Write-Host "justdate is $justdate" # debugging thing
    #return $justdate    
}

# Get-DestZipDateString "Horizon_Chase_10152024_steam.zip" # seems to work with test data

function Confirm-ZipFileReq {
    $folders = Get-ChildItem -Path $sourceFolder -Directory #output is all subfolder paths on one line
    #Write-Host "value of folders is $folders"
    $ZipFoldersTable = @{}
    $buildZipList = @()
    $buildSrcFolderList = @()

    foreach ($subfolder in $folders) {
        $folderName = $subfolder.Name -replace ' ', '_'
        # $PreferredDateFormat defined at top of script
        $FolderModDate = $subfolder.LastWriteTime.ToString($PreferredDateFormat)
        #$FolderModDate = [datetime]::ParseExact($FolderModDate,$PreferredDateFormat,$null)

        #$existZipModDate = $subfolder.LastWriteTime.ToString("MMddyyy")

#        Write-Host "existing zip mod date is $existZipModDate" # and folder mod date is $FolderModDate"
        $plat = Get-PlatformShortName #-path $sourceFolder
        $finalName = "$folderName" + "_$FolderModDate" + "_$plat.zip"
        $DestZipExist = Join-Path -Path $destinationFolder -ChildPath $finalName

        # I'm trying date string extract instead of query date last modified of zip to see if it makes more sense
        $existZipModDate = Get-DestZipDate $DestZipExist


        #$skipFlag = 0
        $TestFolderSize = Get-FolderSizeKB $subfolder
        #Write-Host "Value of getkb is $TestFolderSize"
        $ConvertedFolderModDate = [datetime]::ParseExact($FolderModDate,$PreferredDateFormat,$null)
#        Write-Host "ConvertedFolderModDate value is $ConvertedFolderModDate"
        if (-not (Test-Path -Path $DestZipExist) -or ((Test-Path -Path $DestZipExist  ) `
          -and ( $existZipModDate -lt $ConvertedFolderModDate)) -and $TestFolderSize)  {
            $buildSrcFolderList += $subfolder
#            Write-Host "folderdatemod is $folderModDate and destzipexist mod date is " + $DestZipExist.LastWriteTime.ToString('MMddyyyy')
            $buildZipList += $DestZipExist
        } 
#        elseif ((Test-Path -Path $DestZipExist -eq $true) -and ( $DestZipExist.LastWriteTime.ToString("MMddyyyy") -gt $FolderModDate)) {
#        } 
    }
    # Fill the hashtable
    for ($i = 0; $i -lt $buildSrcFolderList.Length; $i++) {
        $ZipFoldersTable[$buildSrcFolderList[$i]] = $buildZipList[$i]
    }
    return $ZipFoldersTable
}

if (-not (Define-Jobs) ) {
    function Go-SteamZipper-Jobless {
        $ZipToCreate = Confirm-ZipFileReq
        #Write-Host "ZipFoldersTable value is $ZiptoCreate"
        # not sure write-progress is necessary but i'm trying it out
        $currentFolderIndex = 0
        $totalFolders = $ZipToCreate.Count
        foreach ($key in $ZipToCreate.Keys) {
    #        Write-Host "$key **maps to** $($ZipToCreate[$key])"
            $currentZip = Split-Path -Path $($ZipToCreate[$key]) -Leaf
            $currentFolderIndex++
    #        $percentComplete = ($currentFolderIndex / $totalFolders) * 100
            Write-Host "Currently zipping source folder '$key' to destination zip file '$currentZip' ($currentFolderIndex of $totalFolders)"
    #        Write-Progress -Activity "Zipping files" `
    #                        -Status "Zipping $($key.Name)" `
    #                        -PercentComplete $percentComplete    
            Compress-Archive -Path $key -DestinationPath $($ZipToCreate[$key])
        }
    }
    Go-SteamZipper-Jobless
}
elseif (Define-Jobs) {
    function Go-SteamZipper-Jobbed {
        Write-Host "entering jobbed version of the zipper"
        $getMax = Define-Jobs
        $jobList = @() # create empty list for 'job pool' (like dog pool but uglier)
        $ZipToCreate = Confirm-ZipFileReq # hashtable of source folders to destination zip file names
        $currentFolderIndex = 0 # to count total completed zips
        $totalFolders = $ZipToCreate.Count # total number of records in the hashtable, total jobs to do
        
        foreach ($key in $ZipToCreate.Keys) {
            $currentZip = Split-Path -Path $($ZipToCreate[$key]) -Leaf # just zip name for the providing information to the user
            $currentFolderIndex++ # increment zip job counter. probably don't needs for job version
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
    Go-SteamZipper-Jobbed
}


