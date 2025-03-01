param (
    [Parameter(Mandatory=$true)]
    [string]$sourceFolder,      # Source folder with subfolders

    [Parameter(Mandatory=$true)]
    [string]$destinationFolder  # Destination folder with files
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


#################################### Validate script parameters
function Validate-ScriptParameters {
    # Validate source folder exists
    if (-not (Test-Path -Path $sourceFolder -PathType Container)) {
        Write-Error -Message "Error: Source folder '$sourceFolder' not found, exiting..."
        exit 1
    }

    # Validate or create destination folder
    if (-not (Test-Path -Path $destinationFolder -PathType Container)) {
        try {
            New-Item -Path $destinationFolder -ItemType Directory -ErrorAction Stop | Out-Null
            Write-Host "Successfully created destination folder: $destinationFolder"
        }
        catch {
            Write-Host "Failed to create destination folder: $destinationFolder" -ForegroundColor Red
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
            exit 1
        }
    }
}

#################################### Call validation immediately after globals
Validate-ScriptParameters



#################################### newly revised version with redundancy removed
function Get-PlatformShortName {
    $platforms = @{
        "epic games"   = "epic"
        "Amazon Games" = "amazon"
        "GOG"          = "gog"
        "Steam"        = "steam"
        #"Origin"      = "origin"
    }
    foreach ($platform in $platforms.Keys) {
        if ($sourceFolder -like "*$platform*") {
            return $platforms[$platform]
        }
    }
    return "unknown"  # Default value if no match
}
#################################### newly revised version with redundancy removed

# Retrieve and sort subfolders by LastWriteTime
function Get-SortedSubfolders {
    param ([string]$folderPath)
    $subfolders = Get-ChildItem -Path $folderPath -Directory | 
                  Select-Object Name, LastWriteTime | 
                  Sort-Object LastWriteTime
    Write-Host "Found $($subfolders.Count) subfolders in $folderPath"
    return $subfolders
}

# Retrieve, parse dates from filenames, and sort files
function Get-SortedFiles {
    param ([string]$folderPath)
    $files = Get-ChildItem -Path $folderPath -File | 
             ForEach-Object {
                 $parts = $_.Name -split "_"
                 try {
                     if ($parts.Count -ge 3 -and ($date = [datetime]::ParseExact($parts[-2], $global:PreferredDateFormat, $null))) {
                         [PSCustomObject]@{
                             Name = $_.Name
                             LastWriteTime = $date
                         }
                     } else {
                         $null
                     }
                 } catch {
                     $null
                 }
             } | Where-Object { $_ -ne $null } |
             Sort-Object LastWriteTime
    Write-Host "Found $($files.Count) valid files in $folderPath"
    return $files
}

function SubfolderFilesTableBuild {
    
    $subfolders = Get-SortedSubfolders -folderPath $sourceFolder
    $files = Get-SortedFiles -folderPath $destinationFolder
    
    $hashTable = @()
    $maxCount = [Math]::Max($subfolders.Count, $files.Count)

    if ($maxCount -eq 0) {
        Write-Host "No subfolders or files found to process."
        return $null
    }

    for ($i = 0; $i -lt $maxCount; $i++) {
        $hashTable += [PSCustomObject]@{
            "Subfolder Name" = if ($i -lt $subfolders.Count) { $subfolders[$i].Name } else { "" }
            "Folder Last Write Date" = if ($i -lt $subfolders.Count) { $subfolders[$i].LastWriteTime } else { "" }
            "File Name" = if ($i -lt $files.Count) { $files[$i].Name } else { "" }
            "File Last Write Date" = if ($i -lt $files.Count) { $files[$i].LastWriteTime } else { "" }
        }
    }
    Write-Host "Built table with $maxCount entries"
    return $hashTable
}

function Build-ZipFileNames {
    $platform = Get-PlatformShortName
    foreach ($entry in $global:SubfolderFilesTable) {
        if ($entry."Subfolder Name") {
            $subfolderName = $entry."Subfolder Name" -replace " ", "_"
            $dateCode = $entry."Folder Last Write Date".ToString($global:PreferredDateFormat)
            $zipName = "${subfolderName}_${dateCode}_${platform}.$global:CompressionExtension"
            Write-Host "Generated zip name: $zipName"
            # Future: Add zip creation logic here
        }
    }
}


function main {
    $global:SubfolderFilesTable = SubfolderFilesTableBuild
    
    if ($null -eq $global:SubfolderFilesTable) {
        Write-Host "SubfolderFilesTable is null or empty"
    } else {
        Write-Host "SubfolderFilesTable contains $($global:SubfolderFilesTable.Count) entries"
        # Prevent modification after initialization
        Set-Variable -Name "SubfolderFilesTable" -Value $global:SubfolderFilesTable -Scope Global -Option ReadOnly
        # Display the table
        $global:SubfolderFilesTable | Format-Table -AutoSize

        # $platform = Get-PlatformShortName
        # Write-Host "Platform: $platform"

        # hypothetical name build from source folders/last write dates/platform
        #Build-ZipFileNames
    }
}

main