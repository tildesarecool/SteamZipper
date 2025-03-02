#pwsh -command '& { .\hashtable_build.ps1 "P:\steamzipper\steam temp storage" "P:\steamzipper\zip test output" -debugMode }'

param (
    [Parameter(Mandatory=$true)]
    [string]$sourceFolder,      # Source folder with subfolders
    [Parameter(Mandatory=$true)]
    [string]$destinationFolder, # Destination folder with files
    [switch]$debugMode          # Optional debug flag to toggle verbose output
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
             } | Where-Object { $_ -ne $null }
    
    $hashTable = @()
    $maxCount = [Math]::Max($subfolders.Count, $files.Count)
    for ($i = 0; $i -lt $maxCount; $i++) {
        $hashTable += [PSCustomObject]@{
            "Subfolder Name" = if ($i -lt $subfolders.Count) { $subfolders[$i].Name } else { "" }
            "Folder Last Write Date" = if ($i -lt $subfolders.Count) { $subfolders[$i].LastWriteTime } else { "" }
            "File Name" = if ($i -lt $files.Count) { $files[$i].Name } else { "" }
            "File Last Write Date" = if ($i -lt $files.Count) { $files[$i].LastWriteTime } else { "" }
        }
    }
    if ($debugMode) { Write-Host "Built initialization table with $maxCount entries" }
    return $hashTable
}

# Build refined table excluding empty subfolders
function Build-FirstRefinedTable {
    param (
        [Parameter(Mandatory=$true)]
        $initTable
    )
    $platform = Get-PlatformShortName
    $refinedTable = @()

    # Get all subfolders and zips from the init table
    $subfolders = $initTable | Where-Object { $_."Subfolder Name" -ne "" } | Select-Object "Subfolder Name", "Folder Last Write Date"
    $zips = $initTable | Where-Object { $_."File Name" -ne "" } | Select-Object "File Name", "File Last Write Date"

    foreach ($subfolder in $subfolders) {
        $fullSubfolderPath = Join-Path -Path $sourceFolder -ChildPath $subfolder."Subfolder Name"
        $folderSizeKB = Get-FolderSizeKB -folderPath $fullSubfolderPath

        # Skip if folder is empty (below size limit)
        if ($folderSizeKB -lt $global:sizeLimitKB) {
            if ($debugMode) { Write-Host "Skipping empty subfolder: $($subfolder.'Subfolder Name') (Size: $folderSizeKB KB)" }
            continue
        }

        $subfolderName = $subfolder."Subfolder Name" -replace " ", "_"
        $dateCode = $subfolder."Folder Last Write Date".ToString($global:PreferredDateFormat)
        $expectedZip = "${subfolderName}_${dateCode}_${platform}.$global:CompressionExtension"

        # Find the latest matching zip for this subfolder
        $matchingZip = $zips | Where-Object { $_."File Name" -like "${subfolderName}*_${platform}.$global:CompressionExtension" } | 
                       Sort-Object "File Last Write Date" -Descending | 
                       Select-Object -First 1

        $refinedTable += [PSCustomObject]@{
            "Subfolder Name" = $subfolder."Subfolder Name"
            "Folder Last Write Date" = $subfolder."Folder Last Write Date"
            "Zip File Name" = if ($matchingZip) { $matchingZip."File Name" } else { $expectedZip }
        }
    }
    if ($debugMode) { Write-Host "Built first refined table with $($refinedTable.Count) entries" }
    return $refinedTable
}

function Build-ZipDecisionTable {
    param (
        [Parameter(Mandatory=$true)]
        $refinedTable
    )
    $platform = Get-PlatformShortName
    $decisionTable = @()
    $deletedFolder = Join-Path -Path $destinationFolder -ChildPath "deleted"

    # Create deleted folder if it doesn't exist (only in debug mode)
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

        # Check if the zip name is hypothetical (no real zip exists)
        if ($entry."Zip File Name" -eq $expectedZip) {
            $status = "NeedsZip"
            if ($debugMode) { 
                Write-Host "Subfolder $($entry.'Subfolder Name') has no existing zip, marked as NeedsZip"
                # Create stub zip file
                New-Item -Path $expectedZipPath -ItemType File -Force | Out-Null
                Write-Host "Created stub zip: $expectedZipPath (0 KB)"
            }
        } else {
            # Parse the date from the existing zip filename
            $parts = $entry."Zip File Name" -split "_"
            $existingDate = [datetime]::ParseExact($parts[-2], $global:PreferredDateFormat, $null)
            $existingZipPath = Join-Path -Path $destinationFolder -ChildPath $entry."Zip File Name"

            # Compare dates
            if ($existingDate -lt $entry."Folder Last Write Date") {
                $status = "NeedsUpdate"
                if ($debugMode) { 
                    Write-Host "Subfolder $($entry.'Subfolder Name') zip ($($entry.'Zip File Name')) is older than folder, marked as NeedsUpdate"
                    # Move old zip to deleted folder
                    if (Test-Path -Path $existingZipPath) {
                        $deletedZipPath = Join-Path -Path $deletedFolder -ChildPath $entry."Zip File Name"
                        Move-Item -Path $existingZipPath -Destination $deletedZipPath -Force
                        Write-Host "Moved old zip to: $deletedZipPath"
                    }
                    # Create stub zip file
                    New-Item -Path $expectedZipPath -ItemType File -Force | Out-Null
                    Write-Host "Created stub zip: $expectedZipPath (0 KB)"
                }
            } else {
                $status = "NoAction"
                if ($debugMode) { Write-Host "Subfolder $($entry.'Subfolder Name') zip ($($entry.'Zip File Name')) is current or newer, marked as NoAction" }
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
# Main execution function
function main {
    Validate-ScriptParameters

    $global:InitializationTable = Build-InitializationTable
    if ($null -eq $global:InitializationTable) {
        Throw "Failed to build InitializationTable - no data returned"
    }
    Set-Variable -Name "InitializationTable" -Value $global:InitializationTable -Scope Global -Option ReadOnly

    $global:FirstRefinedTable = Build-FirstRefinedTable -initTable $global:InitializationTable
    if ($null -eq $global:FirstRefinedTable) {
        Throw "Failed to build FirstRefinedTable -no data returned"
    }
    Set-Variable -Name "FirstRefinedTable" -Value $global:FirstRefinedTable -Scope Global -Option ReadOnly

    $global:ZipDecisionTable = Build-ZipDecisionTable -refinedTable $global:FirstRefinedTable
    if ($null -eq $global:ZipDecisionTable) {
        Throw "Failed to build ZipDecisionTable - no data returned"
    }
    Set-Variable -Name "ZipDecisionTable" -Value $global:ZipDecisionTable -Scope Global -Option ReadOnly

    # Debug output only if -debugMode is specified
    if ($debugMode) {
        Write-Host "Initialization Table:"
        $global:InitializationTable | Format-Table -AutoSize
        Write-Host "First Refined Table:"
        $global:FirstRefinedTable | Format-Table -AutoSize
        Write-Host "Zip Decision Table:"
        $global:ZipDecisionTable | Format-Table -AutoSize
    }
}
# Execute the script
main