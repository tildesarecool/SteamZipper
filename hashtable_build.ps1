#pwsh -command '& { .\hashtable_build.ps1 "P:\steamzipper\steam temp storage" "P:\steamzipper\zip test output" -debugMode }'

param (
    [Parameter(Mandatory=$true)]
    [string]$sourceFolder,      # Source folder with subfolders
    [Parameter(Mandatory=$true)]
    [string]$destinationFolder, # Destination folder with files
    [switch]$debugMode,          # Optional debug flag to toggle verbose output
    [switch]$keepDuplicates     # Optional flag to keep duplicate zips (default: remove them)
)



# Define immutable global variables
if (-not (Test-Path Variable:\maxJobsDefine)) {
    Set-Variable -Name "maxJobsDefine" -Value ([System.Environment]::ProcessorCount) -Scope Global -Option ReadOnly
}

if (-not (Test-Path Variable:\PreferredDateFormat)) {
    Set-Variable -Name "PreferredDateFormat" -Value "MMddyyyy" -Scope Global -Option ReadOnly
}

if (-not (Test-Path Variable:\CompressionExtension)) {
    Set-Variable -Name "CompressionExtension" -Value "zip" -Scope Global -Option ReadOnly
}

if (-not (Test-Path Variable:\scriptfolder)) {
    Set-Variable -Name "scriptfolder" -Value (Split-Path -Parent $MyInvocation.MyCommand.Path) -Scope Global -Option ReadOnly
}

if (-not (Test-Path Variable:\sizeLimitKB)) {
    Set-Variable -Name "sizeLimitKB" -Value 50 -Scope Global -Option ReadOnly
}

if (-not (Test-Path Variable:\logBaseName)) {
    Set-Variable -Name "logBaseName" -Value "transcript.txt" -Scope Global -Option ReadOnly
}

# Validate script parameters
function Validate-ScriptParameters {
    if (-not (Test-Path -Path $sourceFolder -PathType Container)) {
        Write-Error -Message "Error: Source folder '$sourceFolder' not found, exiting..."
        exit 1
    }


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

# Retrieve and sort subfolders by LastWriteTime
function Get-SortedSubfolders {
    param ([string]$folderPath)
    $subfolders = Get-ChildItem -Path $folderPath -Directory | 
                  Select-Object Name, LastWriteTime | 
                  Sort-Object LastWriteTime
    if ($debugMode) { Write-Host "Found $($subfolders.Count) subfolders in $folderPath" }
    return $subfolders
}

# Retrieve, parse dates from filenames, and sort files
function Get-SortedFiles {
    param ([string]$folderPath)
    $files = Get-ChildItem -Path $folderPath -File -Filter "*.zip" | 
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
    if ($debugMode) { Write-Host "Found $($files.Count) valid files in $folderPath" }
    return $files
}

# Calculate folder size in KB
function Get-FolderSizeKB {
    param (
        [string]$folderPath
    )
    $FolderSizeKBTracker = 0
    foreach ($file in Get-ChildItem -Path $folderPath -Recurse -File -ErrorAction SilentlyContinue) {
        $FolderSizeKBTracker += $file.Length / 1KB
    }
    return $FolderSizeKBTracker  # Returns size in KB
}

# Determine platform short name from source folder path
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

# Build raw initialization table

function Build-InitializationTable {
    $subfolders = Get-ChildItem -Path $sourceFolder -Directory | 
                  Select-Object Name, LastWriteTime
    $files = Get-ChildItem -Path $destinationFolder -File -Filter "*.zip" | 
             Select-Object Name  # Only need the filename
    
    $hashTable = @()
    $maxCount = [Math]::Max($subfolders.Count, $files.Count)
    for ($i = 0; $i -lt $maxCount; $i++) {
        $hashTable += [PSCustomObject]@{
            "Subfolder Name" = if ($i -lt $subfolders.Count) { $subfolders[$i].Name } else { "" }
            "Folder Last Write Date" = if ($i -lt $subfolders.Count) { $subfolders[$i].LastWriteTime } else { "" }
            "File Name" = if ($i -lt $files.Count) { $files[$i].Name } else { "" }
        }
    }
    if ($debugMode) { Write-Host "Built initialization table with $maxCount entries" }
    return $hashTable
}

# Build refined table excluding empty subfolders

function Build-ZipDecisionTable {
    param (
        [Parameter(Mandatory=$true)]
        $refinedTable
    )
    $platform = Get-PlatformShortName
    $decisionTable = @()
    $deletedFolder = Join-Path -Path $destinationFolder -ChildPath "deleted"
    $existingZips = Get-ChildItem -Path $destinationFolder -File -Filter "*.zip" | Select-Object -Property Name, @{Name="ParsedDate"; Expression={
        $parts = $_.Name -split "_"
        try { [datetime]::ParseExact($parts[-2], $global:PreferredDateFormat, $null) } catch { $null }
    }} | Where-Object { $_.ParsedDate -ne $null }

    if ($debugMode -and -not (Test-Path -Path $deletedFolder -PathType Container)) {
        try {
            New-Item -Path $deletedFolder -ItemType Directory -ErrorAction Stop | Out-Null
            Write-Host "Created deleted folder: $deletedFolder"
        }
        catch {
            Write-Host "Failed to create deleted folder: $deletedFolder" -ForegroundColor Red
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    foreach ($entry in $refinedTable) {
        $subfolderName = $entry."Subfolder Name" -replace " ", "_"
        $dateCode = $entry."Folder Last Write Date".ToString($global:PreferredDateFormat)
        $expectedZip = "${subfolderName}_${dateCode}_${platform}.$global:CompressionExtension"
        $expectedZipPath = Join-Path -Path $destinationFolder -ChildPath $expectedZip

        # Get all zips for this subfolder
        $matchingZips = $existingZips | Where-Object { $_.Name -match "^${subfolderName}_\d{8}_${platform}\.$global:CompressionExtension$" }
        $olderZips = $matchingZips | Where-Object { $_.ParsedDate -lt $entry."Folder Last Write Date" }

        if ($entry."Zip File Name" -eq $expectedZip -and -not ($matchingZips | Where-Object { $_.Name -eq $expectedZip })) {
            $status = "NeedsZip"
            if ($debugMode) { 
                Write-Host "Subfolder $($entry.'Subfolder Name') has no existing zip, marked as NeedsZip"
                New-Item -Path $expectedZipPath -ItemType File -Force | Out-Null
                Write-Host "Created stub zip: $expectedZipPath (0 KB)"
            }
        } else {
            $existingDate = [datetime]::ParseExact(($entry."Zip File Name" -split "_")[-2], $global:PreferredDateFormat, $null)
            $existingZipPath = Join-Path -Path $destinationFolder -ChildPath $entry."Zip File Name"

            if ($existingDate -lt $entry."Folder Last Write Date") {
                $status = "NeedsUpdate"
                if ($debugMode) { 
                    Write-Host "Subfolder $($entry.'Subfolder Name') zip ($($entry.'Zip File Name')) is older than folder, marked as NeedsUpdate"
                    if (Test-Path -Path $existingZipPath) {
                        $deletedZipPath = Join-Path -Path $deletedFolder -ChildPath $entry."Zip File Name"
                        Move-Item -Path $existingZipPath -Destination $deletedZipPath -Force
                        Write-Host "Moved old zip to: $deletedZipPath"
                    }
                    New-Item -Path $expectedZipPath -ItemType File -Force | Out-Null
                    Write-Host "Created stub zip: $expectedZipPath (0 KB)"
                }
            } else {
                $status = "NoAction"
                if ($debugMode) { Write-Host "Subfolder $($entry.'Subfolder Name') zip ($($entry.'Zip File Name')) is current or newer, marked as NoAction" }
            }

            # Move all other older zips to deleted
            if ($debugMode -and $olderZips) {
                foreach ($oldZip in $olderZips) {
                    if ($oldZip.Name -ne $entry."Zip File Name" -and $oldZip.Name -ne $expectedZip) {
                        $oldZipPath = Join-Path -Path $destinationFolder -ChildPath $oldZip.Name
                        $deletedZipPath = Join-Path -Path $deletedFolder -ChildPath $oldZip.Name
                        if (Test-Path -Path $oldZipPath) {
                            Move-Item -Path $oldZipPath -Destination $deletedZipPath -Force
                            Write-Host "Moved additional old zip to: $deletedZipPath"
                        }
                    }
                }
            }
        }

        $decisionTable += [PSCustomObject]@{
            "Subfolder Name" = $entry."Subfolder Name"
            "Folder Last Write Date" = $entry."Folder Last Write Date"
            "Existing Zip Name" = if ($entry."Zip File Name" -ne $expectedZip) { $entry."Zip File Name" } else { "" }
            "Expected Zip Name" = $expectedZip
            "Status" = $status
        }
    }
    if ($debugMode) { Write-Host "Built zip decision table with $($decisionTable.Count) entries" }
    return $decisionTable
}

## function between here and Main are in place and in addition to the Build-ZipDecisionTable function
# that had balooned into ~100 lines and therefore needed to be broken up

function Get-FileDateStamp {
    param (
        [Parameter(Mandatory=$true)]
        [string]$InputValue
    )
    # Handle date code (e.g., "11012024")
    if ($InputValue.Length -eq $global:PreferredDateFormat.Length) {
        try {
            return [datetime]::ParseExact($InputValue, $global:PreferredDateFormat, $null)
        }
        catch {
            if ($debugMode) { Write-Host "Warning: Invalid date code '$InputValue'. Expected format: $global:PreferredDateFormat" }
            return $null
        }
    }
    # Handle zip filename (e.g., "PAC-MAN_11012024_steam.zip")
    $parts = $InputValue -split "_"
    if ($parts.Count -ge 3) {
        try {
            return [datetime]::ParseExact($parts[-2], $global:PreferredDateFormat, $null)
        }
        catch {
            if ($debugMode) { Write-Host "Unable to parse date from '$InputValue'" }
            return $null
        }
    }
    # Handle folder path
    if (Test-Path -Path $InputValue -PathType Container) {
        $date = (Get-Item -Path $InputValue).LastWriteTime
        return $date
    }
    if ($debugMode) { Write-Host "'$InputValue' is neither a valid date code, zip file, nor folder" }
    return $null
}

function Move-DuplicateZips {
    param (
        [string]$SubfolderName,
        [datetime]$ReferenceDate,
        [string]$ExpectedZip,
        [string]$DestinationFolder,
        [string]$DeletedFolder,
        [switch]$KeepDuplicates
    )
    if ($debugMode -and -not $KeepDuplicates) {
        $platform = Get-PlatformShortName
        $duplicateZips = Get-ChildItem -Path $DestinationFolder -Filter "${SubfolderName}*_${platform}.$global:CompressionExtension" | 
                         Where-Object { 
                             $dupDate = Get-FileDateStamp -InputValue $_.Name
                             $dupDate -and $dupDate -lt $ReferenceDate -and $_.Name -ne $ExpectedZip
                         }
        foreach ($dup in $duplicateZips) {
            $dupPath = $dup.FullName
            $deletedDupPath = Join-Path -Path $DeletedFolder -ChildPath $dup.Name
            Move-Item -Path $dupPath -Destination $deletedDupPath -Force
            Write-Host "Moved duplicate older zip to: $deletedDupPath"
        }
    }
}

function Create-StubZip {
    param (
        [string]$ZipPath
    )
    if ($debugMode) {
        New-Item -Path $ZipPath -ItemType File -Force | Out-Null
        Write-Host "Created stub zip: $ZipPath (0 KB)"
    }
}

function Build-FirstRefinedTable {
    param (
        [Parameter(Mandatory=$true)]
        $initTable
    )
    $platform = Get-PlatformShortName
    $refinedTable = @()

    $subfolders = $initTable | Where-Object { $_."Subfolder Name" -ne "" } | Select-Object "Subfolder Name", "Folder Last Write Date"
    $zips = Get-ChildItem -Path $destinationFolder -File -Filter "*.zip" | Select-Object -Property Name, @{Name="ParsedDate"; Expression={
        $parts = $_.Name -split "_"
        try { [datetime]::ParseExact($parts[-2], $global:PreferredDateFormat, $null) } catch { $null }
    }} | Where-Object { $_.ParsedDate -ne $null }

    foreach ($subfolder in $subfolders) {
        $fullSubfolderPath = Join-Path -Path $sourceFolder -ChildPath $subfolder."Subfolder Name"
        $folderSizeKB = Get-FolderSizeKB -folderPath $fullSubfolderPath

        if ($folderSizeKB -lt $global:sizeLimitKB) {
            if ($debugMode) { Write-Host "Skipping empty subfolder: $($subfolder.'Subfolder Name') (Size: $folderSizeKB KB)" }
            continue
        }

        $subfolderName = $subfolder."Subfolder Name" -replace " ", "_"
        $dateCode = $subfolder."Folder Last Write Date".ToString($global:PreferredDateFormat)
        $expectedZip = "${subfolderName}_${dateCode}_${platform}.$global:CompressionExtension"

        # Try exact match first
        $matchingZip = $zips | Where-Object { $_.Name -eq $expectedZip } | Select-Object -First 1
        if (-not $matchingZip) {
            # Find latest existing zip for this subfolder
            $matchingZip = $zips | Where-Object { $_.Name -match "^${subfolderName}_\d{8}_${platform}\.$global:CompressionExtension$" } | 
                           Sort-Object "ParsedDate" -Descending | 
                           Select-Object -First 1
        }

        $refinedTable += [PSCustomObject]@{
            "Subfolder Name" = $subfolder."Subfolder Name"
            "Folder Last Write Date" = $subfolder."Folder Last Write Date"
            "Zip File Name" = if ($matchingZip) { $matchingZip.Name } else { $expectedZip }
        }
    }
    if ($debugMode) { Write-Host "Built first refined table with $($refinedTable.Count) entries" }
    return $refinedTable
}


function Compress-Folders {
    param (
        [Parameter(Mandatory=$true)]
        $decisionTable
    )
    $deletedFolder = Join-Path -Path $destinationFolder -ChildPath "deleted"

    if (-not (Test-Path -Path $deletedFolder -PathType Container)) {
        try {
            New-Item -Path $deletedFolder -ItemType Directory -ErrorAction Stop | Out-Null
            if ($debugMode) { Write-Host "Created deleted folder: $deletedFolder" }
        }
        catch {
            Write-Host "Failed to create deleted folder: $deletedFolder" -ForegroundColor Red
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
            return
        }
    }

    foreach ($entry in $decisionTable) {
        if ($entry.Status -eq "NeedsZip" -or $entry.Status -eq "NeedsUpdate") {
            $sourcePath = Join-Path -Path $sourceFolder -ChildPath $entry."Subfolder Name"
            $zipPath = Join-Path -Path $destinationFolder -ChildPath $entry."Expected Zip Name"

            # Move any existing zip at the target path to deleted (prevents overwrite)
            if (Test-Path -Path $zipPath) {
                $deletedZipPath = Join-Path -Path $deletedFolder -ChildPath $entry."Expected Zip Name"
                Move-Item -Path $zipPath -Destination $deletedZipPath -Force
                if ($debugMode) { Write-Host "Moved existing zip to: $deletedZipPath" }
            }

            # Move existing zip for NeedsUpdate
            if ($entry.Status -eq "NeedsUpdate" -and $entry."Existing Zip Name" -ne "") {
                $oldZipPath = Join-Path -Path $destinationFolder -ChildPath $entry."Existing Zip Name"
                if (Test-Path -Path $oldZipPath) {
                    $deletedZipPath = Join-Path -Path $deletedFolder -ChildPath $entry."Existing Zip Name"
                    Move-Item -Path $oldZipPath -Destination $deletedZipPath -Force
                    if ($debugMode) { Write-Host "Moved old zip to: $deletedZipPath" }
                }
            }

            # Compress the subfolder
            try {
                Compress-Archive -Path $sourcePath -DestinationPath $zipPath -Force -ErrorAction Stop
                if ($debugMode) { Write-Host "Compressed $($entry.'Subfolder Name') to $zipPath" }
            }
            catch {
                Write-Host "Failed to compress $($entry.'Subfolder Name') to $zipPath" -ForegroundColor Red
                Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        elseif ($debugMode) {
            Write-Host "No compression needed for $($entry.'Subfolder Name') (Status: $($entry.Status))"
        }
    }
}



# Main execution function
function main {
    # Start transcript, overwriting existing file silently
    $transcriptPath = Join-Path -Path $global:scriptfolder -ChildPath $global:logBaseName
    try {
        Start-Transcript -Path $transcriptPath -Force -ErrorAction Stop | Out-Null
    } catch {
        # Silently ignore failure
    }

    Validate-ScriptParameters

    $global:InitializationTable = Build-InitializationTable
    if ($null -eq $global:InitializationTable) {
        Throw "Failed to build InitializationTable - no data returned"
    }
    Set-Variable -Name "InitializationTable" -Value $global:InitializationTable -Scope Global -Option ReadOnly

    $global:FirstRefinedTable = Build-FirstRefinedTable -initTable $global:InitializationTable
    if ($null -eq $global:FirstRefinedTable) {
        Throw "Failed to build FirstRefinedTable - no data returned"
    }
    Set-Variable -Name "FirstRefinedTable" -Value $global:FirstRefinedTable -Scope Global -Option ReadOnly

    $global:ZipDecisionTable = Build-ZipDecisionTable -refinedTable $global:FirstRefinedTable
    if ($null -eq $global:ZipDecisionTable) {
        Throw "Failed to build ZipDecisionTable - no data returned"
    }
    Set-Variable -Name "ZipDecisionTable" -Value $global:ZipDecisionTable -Scope Global -Option ReadOnly

    # Compress folders based on decision table (commented out for now)
    # Compress-Folders -decisionTable $global:ZipDecisionTable

    # Debug output only if -debugMode is specified
    if ($debugMode) {
        Write-Host "Initialization Table:"
        $global:InitializationTable | Format-Table -AutoSize
        Write-Host "First Refined Table:"
        $global:FirstRefinedTable | Format-Table -AutoSize
        Write-Host "Zip Decision Table:"
        $global:ZipDecisionTable | Format-Table -AutoSize
    }

    # Stop transcript
    try {
        Stop-Transcript -ErrorAction Stop | Out-Null
    } catch {
        # Silently ignore failure
    }
}
main