#pwsh -command '& { .\hashtable_build.ps1 "P:\steamzipper\steam temp storage" "P:\steamzipper\zip test output" -debugMode }'

# Version check at the very top

#pwsh -command '& { .\hashtable_build.ps1 "P:\steamzipper\steam temp storage" "P:\steamzipper\zip test output" -debugMode }'

[CmdletBinding(DefaultParameterSetName="Manual", SupportsShouldProcess=$true)] # SupportsShouldProcess enables WhatIf
param (
    [Parameter(ParameterSetName="Manual")][string]$sourceFolder,
    [Parameter(ParameterSetName="Manual")][string]$destinationFolder,
    [Parameter(ParameterSetName="Manual")][string]$sourceFile,
    [Parameter(ParameterSetName="Manual")][switch]$debugMode,
    [Parameter(ParameterSetName="Manual")][switch]$VerbMode,
    [Parameter(ParameterSetName="Manual")][switch]$keepDuplicates,
    [Parameter(ParameterSetName="Manual")][ValidateSet("Optimal", "Fastest", "NoCompression")][string]$CompressionLevel = "Optimal",
    [Parameter(ParameterSetName="Manual")][string]$answerFile,
    [Parameter(ParameterSetName="Manual")][string]$createAnswerFile
)

# Remove this check since AnswerFile set is gone
# if ($PSCmdlet.ParameterSetName -eq "AnswerFile" -and -not $answerFile) { ... }
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "Error: This script requires PowerShell 7 or later. You are running PowerShell $($PSVersionTable.PSVersion.ToString())." -ForegroundColor Red
    Write-Host "Please upgrade to PowerShell 7 or higher. Download it from: https://aka.ms/powershell" -ForegroundColor Yellow
    Write-Host "Exiting now." -ForegroundColor Red
    exit 1
}

# Define immutable global variables
$global:maxJobsDefine = [System.Environment]::ProcessorCount
$global:PreferredDateFormat = "MMddyyyy"
$global:CompressionExtension = "zip"
$global:scriptfolder = Split-Path -Parent $MyInvocation.MyCommand.Path
$global:sizeLimitKB = 50
$global:logBaseName = "transcript.txt"


if ($answerFile) {
    $answerFilePath = if ($answerFile -notmatch '[\\/]') { 
        Join-Path -Path $global:scriptfolder -ChildPath $answerFile 
    } else { 
        $answerFile 
    }
    if (-not (Test-Path $answerFilePath)) { 
        Write-Host "Error: Answer file '$answerFilePath' does not exist. Please provide a valid file path." -ForegroundColor Red
        exit 1 
    }
    try {
        $params = Get-Content $answerFilePath -Raw | ConvertFrom-Json -ErrorAction Stop
        foreach ($prop in @("debugMode", "VerbMode", "keepDuplicates")) {
            if ($null -ne $params.$prop -and $params.$prop -isnot [bool]) {
                Write-Host "Error: '$prop' in '$answerFilePath' must be a boolean (true/false), got '$($params.$prop)'" -ForegroundColor Red
                exit 1
            }
        }
    } catch {
        Write-Host "Error: Failed to parse answer file '$answerFilePath': $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
    if ($params.sourceFolder) { $sourceFolder = $params.sourceFolder }
    if ($params.destinationFolder) { $destinationFolder = $params.destinationFolder }
    if ($null -ne $params.debugMode) { $debugMode = $params.debugMode }
    if ($null -ne $params.VerbMode) { $VerbMode = $params.VerbMode }
    if ($null -ne $params.keepDuplicates) { $keepDuplicates = $params.keepDuplicates }
    if ($params.CompressionLevel) { $CompressionLevel = $params.CompressionLevel }
    if ($params.sourceFile) { $sourceFile = $params.sourceFile }  # Add support in answer file
}

# Validate script parameters

function Validate-ScriptParameters {
    $cleanSource = $sourceFolder.Trim('"', "'")
    $cleanDest = $destinationFolder.Trim('"', "'")
    if (-not (Test-Path -Path $cleanSource -PathType Container)) {
        Write-Host "Error: Source folder '$cleanSource' does not exist. Please provide a valid path." -ForegroundColor Red
        exit 1
    }
    if (-not (Test-Path -Path $cleanDest -PathType Container)) {
        try {
            New-Item -Path $cleanDest -ItemType Directory -ErrorAction Stop | Out-Null
            Write-Host "Successfully created destination folder: $cleanDest" -ForegroundColor Green
        } catch {
            Write-Host "Error: Failed to create destination folder '$cleanDest': $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    }
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
    $subfolders = @()
    if ($sourceFile) {
        # Resolve sourceFile path
        $sourceFilePath = if ($sourceFile -notmatch '[\\/]') { 
            Join-Path -Path $global:scriptfolder -ChildPath $sourceFile 
        } else { 
            $sourceFile 
        }
        if (-not (Test-Path $sourceFilePath -PathType Leaf)) { 
            Write-Host "Error: Source file '$sourceFilePath' does not exist or is not a file. Please provide a valid file path." -ForegroundColor Red
            exit 1
        }
        # Read and process subfolder names from file
        $subfolderNames = Get-Content $sourceFilePath -ErrorAction Stop | 
                         Where-Object { $_ -match '\S' } | 
                         ForEach-Object { $_.Trim() }
        if ($subfolderNames.Count -eq 0) {
            Write-Host "Error: Source file '$sourceFilePath' is empty or contains no valid entries." -ForegroundColor Red
            exit 1
        }
        $subfolders = $subfolderNames | ForEach-Object {
            $fullPath = Join-Path -Path $sourceFolder -ChildPath $_
            if (Test-Path $fullPath -PathType Container) {
                [PSCustomObject]@{
                    Name = $_
                    LastWriteTime = (Get-Item $fullPath).LastWriteTime
                }
            } else {
                if ($VerbMode) { Write-Host "Warning: Subfolder '$fullPath' not found, skipping" -ForegroundColor Yellow }
                $null
            }
        } | Where-Object { $_ }
        if ($subfolders.Count -eq 0) {
            Write-Host "Error: No valid subfolders from '$sourceFilePath' exist in '$sourceFolder'." -ForegroundColor Red
            exit 1
        }
        if ($VerbMode) { Write-Host "Loaded $($subfolders.Count) subfolders from '$sourceFilePath'" -ForegroundColor Green }
    } else {
        # Default behavior: all subfolders in sourceFolder
        $subfolders = Get-ChildItem -Path $sourceFolder -Directory -ErrorAction Stop | 
                      Select-Object Name, LastWriteTime
        if ($VerbMode) { Write-Host "Loaded $($subfolders.Count) subfolders from '$sourceFolder'" -ForegroundColor Green }
    }

    $files = Get-ChildItem -Path $destinationFolder -File -Filter "*.$global:CompressionExtension" -ErrorAction Stop | 
             Select-Object Name
    $hashTable = @()
    $maxCount = [Math]::Max($subfolders.Count, $files.Count)
    for ($i = 0; $i -lt $maxCount; $i++) {
        $hashTable += [PSCustomObject]@{
            "Subfolder Name" = if ($i -lt $subfolders.Count) { $subfolders[$i].Name } else { "" }
            "Folder Last Write Date" = if ($i -lt $subfolders.Count) { $subfolders[$i].LastWriteTime } else { "" }
            "File Name" = if ($i -lt $files.Count) { $files[$i].Name } else { "" }
        }
    }
    if ($VerbMode) { Write-Host "Built initialization table with $maxCount entries" -ForegroundColor Green }
    return $hashTable
}
# Build refined table excluding empty subfolders

function Build-ZipDecisionTable {
    param ([Parameter(Mandatory=$true)] $refinedTable)
    $platform = Get-PlatformShortName
    $decisionTable = @()
    $existingZips = Get-ChildItem -Path $destinationFolder -File -Filter "*.$global:CompressionExtension" | Select-Object -Property Name, @{Name="ParsedDate"; Expression={
        $parts = $_.Name -split "_"
        try { [datetime]::ParseExact($parts[-2], $global:PreferredDateFormat, $null) } catch { $null }
    }} | Where-Object { $_.ParsedDate -ne $null }

    foreach ($entry in $refinedTable) {
        $subfolderName = $entry."Subfolder Name" -replace " ", "_"
        $dateCode = $entry."Folder Last Write Date".ToString($global:PreferredDateFormat)
        $expectedZip = "${subfolderName}_${dateCode}_${platform}.$global:CompressionExtension"
        $matchingZips = $existingZips | Where-Object { 
            $parts = $_.Name -split "_"
            ($parts[-1] -eq "$platform.$global:CompressionExtension") -and ($parts[0..($parts.Count - 3)] -join "_") -eq $subfolderName
        }
        if ($entry."Zip File Name" -eq $expectedZip -and -not ($matchingZips | Where-Object { $_.Name -eq $expectedZip })) {
            $status = "NeedsZip"
            if ($VerbMode) { Write-Host "Subfolder $($entry.'Subfolder Name') has no existing zip, marked as NeedsZip" }
        } else {
            $existingParts = $entry."Zip File Name" -split "_"
            $existingDate = [datetime]::ParseExact($existingParts[-2], $global:PreferredDateFormat, $null).Date  # Fix 1: Strip time
            $folderDate = $entry."Folder Last Write Date".Date  # Fix 1: Strip time
            if ($existingDate -lt $folderDate) {
                $status = "NeedsUpdate"
                if ($VerbMode) { Write-Host "Subfolder $($entry.'Subfolder Name') zip ($($entry.'Zip File Name')) is older than folder, marked as NeedsUpdate" }
            } else {
                $status = "NoAction"
                if ($VerbMode) { Write-Host "Subfolder $($entry.'Subfolder Name') zip ($($entry.'Zip File Name')) is current or newer, marked as NoAction" }
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
    if ($VerbMode) { Write-Host "Built zip decision table with $($decisionTable.Count) entries" }
    return $decisionTable
}
## function between here and Main are in place and in addition to the Build-ZipDecisionTable function
# that had balooned into ~100 lines and therefore needed to be broken up
function Get-FileDateStamp {
    param ([Parameter(Mandatory=$true)] [string]$InputValue)
    if ($InputValue.Length -eq $global:PreferredDateFormat.Length) {
        try { return [datetime]::ParseExact($InputValue, $global:PreferredDateFormat, $null) }
        catch { if ($VerbMode) { Write-Host "Warning: Invalid date code '$InputValue'. Expected format: $global:PreferredDateFormat" }; return $null }  # Changed from $debugMode
    }
    $parts = $InputValue -split "_"
    if ($parts.Count -ge 3) {
        try { return [datetime]::ParseExact($parts[-2], $global:PreferredDateFormat, $null) }
        catch { if ($VerbMode) { Write-Host "Unable to parse date from '$InputValue'" }; return $null }  # Changed from $debugMode
    }
    if (Test-Path -Path $InputValue -PathType Container) { return (Get-Item -Path $InputValue).LastWriteTime }
    if ($VerbMode) { Write-Host "'$InputValue' is neither a valid date code, zip file, nor folder" }  # Changed from $debugMode
    return $null
}
#function Create-StubZip {
#    param (
#        [string]$ZipPath
#    )
#    if ($debugMode) {
#        New-Item -Path $ZipPath -ItemType File -Force | Out-Null
#        Write-Host "Created stub zip: $ZipPath (0 KB)"
#    }
#}
#function Move-DuplicateZips {
#    param ([string]$SubfolderName, [datetime]$ReferenceDate, [string]$ExpectedZip, [string]$DestinationFolder, [string]$DeletedFolder, [switch]$KeepDuplicates)
#    if (-not $KeepDuplicates) {  # Removed $debugMode condition—moves should always happen unless -keepDuplicates
#        $platform = Get-PlatformShortName
#        $duplicateZips = Get-ChildItem -Path $DestinationFolder -Filter "${SubfolderName}*_${platform}.$global:CompressionExtension" | 
#                         Where-Object { $dupDate = Get-FileDateStamp -InputValue $_.Name; $dupDate -and $dupDate -lt $ReferenceDate -and $_.Name -ne $ExpectedZip }
#        foreach ($dup in $duplicateZips) {
#            $dupPath = $dup.FullName
#            $deletedDupPath = Join-Path -Path $DeletedFolder -ChildPath $dup.Name
#            Move-Item -Path $dupPath -Destination $deletedDupPath -Force
#            if ($VerbMode) { Write-Host "Moved duplicate older zip to: $deletedDupPath" }  # Changed from Write-Host without condition
#        }
#    }
#}

function Move-DuplicateZips {
    param ([string]$SubfolderName, [datetime]$ReferenceDate, [string]$ExpectedZip, [string]$DestinationFolder, [string]$DeletedFolder, [switch]$KeepDuplicates)
    if (-not $KeepDuplicates) {
        $platform = Get-PlatformShortName
        $duplicateZips = Get-ChildItem -Path $DestinationFolder -Filter "${SubfolderName}*_${platform}.$global:CompressionExtension" | 
                         Where-Object { $dupDate = Get-FileDateStamp -InputValue $_.Name; $dupDate -and $dupDate -lt $ReferenceDate -and $_.Name -ne $ExpectedZip }
        foreach ($dup in $duplicateZips) {
            $dupPath = $dup.FullName
            $deletedDupPath = Join-Path -Path $DeletedFolder -ChildPath $dup.Name
            if ($PSCmdlet.ShouldProcess($dupPath, "Move duplicate to $deletedDupPath")) {
                Move-Item -Path $dupPath -Destination $deletedDupPath -Force
                if ($VerbMode) { Write-Host "Moved duplicate older zip to: $deletedDupPath" }
            }
        }
    }
}



function Build-FirstRefinedTable {
    param ([Parameter(Mandatory=$true)] $initTable)
    $platform = Get-PlatformShortName
    $refinedTable = @()
    $subfolders = $initTable | Where-Object { $_."Subfolder Name" -ne "" } | Select-Object "Subfolder Name", "Folder Last Write Date"
    $zips = Get-ChildItem -Path $destinationFolder -File -Filter "*.$global:CompressionExtension" | Select-Object -Property Name, @{Name="ParsedDate"; Expression={
        $parts = $_.Name -split "_"
        try { [datetime]::ParseExact($parts[-2], $global:PreferredDateFormat, $null) } catch { $null }
    }} | Where-Object { $_.ParsedDate -ne $null }

    foreach ($subfolder in $subfolders) {
        $fullSubfolderPath = Join-Path -Path $sourceFolder -ChildPath $subfolder."Subfolder Name"
        $folderSizeKB = Get-FolderSizeKB -folderPath $fullSubfolderPath
        if ($VerbMode) { Write-Host "Checking $($subfolder.'Subfolder Name'): Size $folderSizeKB KB" }
        if ($folderSizeKB -lt $global:sizeLimitKB) {
            if ($VerbMode) { Write-Host "Skipping empty subfolder: $($subfolder.'Subfolder Name') (Size: $folderSizeKB KB)" }
            continue
        }
        $subfolderName = $subfolder."Subfolder Name" -replace " ", "_"
        $dateCode = $subfolder."Folder Last Write Date".ToString($global:PreferredDateFormat)
        $expectedZip = "${subfolderName}_${dateCode}_${platform}.$global:CompressionExtension"
        $matchingZip = $zips | Where-Object { $_.Name -eq $expectedZip } | Select-Object -First 1
        if (-not $matchingZip) {
            $matchingZip = $zips | Where-Object { 
                $parts = $_.Name -split "_"
                ($parts[-1] -eq "$platform.$global:CompressionExtension") -and ($parts[0..($parts.Count - 3)] -join "_") -eq $subfolderName
            } | Sort-Object "ParsedDate" -Descending | Select-Object -First 1
        }

        $refinedTable += [PSCustomObject]@{
            "Subfolder Name" = $subfolder."Subfolder Name"
            "Folder Last Write Date" = $subfolder."Folder Last Write Date"
            "Zip File Name" = $expectedZip  # Always use MMddyyyy format
        }

        #        $refinedTable += [PSCustomObject]@{
#            "Subfolder Name" = $subfolder."Subfolder Name"
#            "Folder Last Write Date" = $subfolder."Folder Last Write Date"
#            "Zip File Name" = if ($matchingZip) { $matchingZip.Name } else { $expectedZip }
#        }
    }
    if ($VerbMode) { Write-Host "Built first refined table with $($refinedTable.Count) entries" }
    return $refinedTable
}
# [Everything above Build-CompressTable remains unchanged]

function Build-CompressTable {
    param ([Parameter(Mandatory=$true)] $zipDecisionTable)
    $platform = Get-PlatformShortName
    $compressTable = @($zipDecisionTable | Where-Object { $_.Status -in @("NeedsZip", "NeedsUpdate") } | ForEach-Object {
        $subfolderName = $_."Subfolder Name"
        $underscoreName = $subfolderName -replace " ", "_"
        $matchingZips = Get-ChildItem -Path $destinationFolder -File -Filter "*.$global:CompressionExtension" | Where-Object { 
            $parts = $_.Name -split "_"
            ($parts[-1] -eq "$platform.$global:CompressionExtension") -and ($parts[0..($parts.Count - 3)] -join "_") -eq $underscoreName
        }
        $latestZip = if ($_.Status -eq "NeedsUpdate") { $_."Existing Zip Name" } else { "" }
        $oldZips = if ($matchingZips.Count -gt 1) { $matchingZips | Where-Object { $_.Name -ne $latestZip -and $_.Name -ne $_."Expected Zip Name" } | Select-Object -ExpandProperty Name } else { $null }
        [PSCustomObject]@{
            "Subfolder Name" = $subfolderName
            "Folder Last Write Date" = $_."Folder Last Write Date"
            "Expected Zip" = $_."Expected Zip Name"
            "Existing Zip" = $latestZip
            "Old Zips" = $oldZips
            "Status" = $_.Status
        }
    } | Sort-Object "Status", "Subfolder Name")
    if ($VerbMode) { Write-Host "Built compress table with $($compressTable.Count) entries" }
    return $compressTable
}

function Compress-Folders {
    param (
        [Parameter(Mandatory=$true)] $decisionTable,
        [switch]$keepDuplicates,
        [string]$CompressionLevel = "Optimal"
    )
    $deletedFolder = Join-Path -Path $destinationFolder -ChildPath "deleted"
    if (-not (Test-Path -Path $deletedFolder)) { 
        if ($PSCmdlet.ShouldProcess($deletedFolder, "Create deleted folder")) {
            New-Item -Path $deletedFolder -ItemType Directory | Out-Null
            if ($VerbMode) { Write-Host "Created deleted folder: $deletedFolder" }
        }
    }

    foreach ($entry in $decisionTable) {
        $sourcePath = Join-Path -Path $sourceFolder -ChildPath $entry."Subfolder Name"
        $zipPath = Join-Path -Path $destinationFolder -ChildPath $entry."Expected Zip"
        
        if ($entry."Existing Zip" -and $entry.Status -eq "NeedsUpdate") {
            Move-DuplicateZips -SubfolderName ($entry."Subfolder Name" -replace " ", "_") `
                              -ReferenceDate $entry."Folder Last Write Date" `
                              -ExpectedZip $entry."Expected Zip" `
                              -DestinationFolder $destinationFolder `
                              -DeletedFolder $deletedFolder `
                              -KeepDuplicates:$keepDuplicates
        }
        if ($entry."Old Zips") {
            Move-DuplicateZips -SubfolderName ($entry."Subfolder Name" -replace " ", "_") `
                              -ReferenceDate $entry."Folder Last Write Date" `
                              -ExpectedZip $entry."Expected Zip" `
                              -DestinationFolder $destinationFolder `
                              -DeletedFolder $deletedFolder `
                              -KeepDuplicates:$keepDuplicates
        }
        if ($PSCmdlet.ShouldProcess($zipPath, "Compress $($entry.'Subfolder Name')")) {
            if (-not $debugMode) {
                $timer = Measure-Command {
                    Compress-Archive -Path $sourcePath -DestinationPath $zipPath -Force -CompressionLevel $CompressionLevel -ErrorAction Stop
                    Write-Host "Compressed $($entry.'Subfolder Name') to $zipPath"
                    if ($VerbMode) { Write-Host "Compression completed for $($entry.'Subfolder Name')" }
                }
                $roundedTime = [Math]::Round($timer.TotalSeconds, 1)
                Write-Host "Operation for $($entry.'Subfolder Name') took $roundedTime seconds"
            } else {
                New-Item -Path $zipPath -ItemType File -Force | Out-Null
                Write-Host "Created stub zip: $zipPath (0 KB)"
            }
        } else {
            Write-Host "Would compress '$($entry.'Subfolder Name')' to '$zipPath'" -ForegroundColor Cyan
            if ($VerbMode) { 
                $action = if ($debugMode) { "stub creation" } else { "compression" }
                Write-Host "WhatIf: Skipped $action for $($entry.'Subfolder Name')"
            }
        }
    }
}


# Main execution function

function main {
    $transcriptPath = Join-Path -Path $global:scriptfolder -ChildPath $global:logBaseName
    if (-not $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('WhatIf')) {
        try { Start-Transcript -Path $transcriptPath -Force -ErrorAction Stop | Out-Null } catch {}
    }

    # Existing validation and setup...
    Write-Host "Welcome to SteamZipper!" -ForegroundColor Cyan
    Write-Host "This script zips your Steam folders. Ensure the storage device of '$destinationFolder' has enough space!" -ForegroundColor Yellow
    Write-Host "Running on $([System.Environment]::MachineName) - $(Get-Date)" -ForegroundColor Green

    Validate-ScriptParameters
    $global:InitializationTable = Build-InitializationTable
    if ($null -eq $global:InitializationTable) { Throw "Failed to build InitializationTable" }
    Set-Variable -Name "InitializationTable" -Value $global:InitializationTable -Scope Global -Option ReadOnly

    $global:FirstRefinedTable = Build-FirstRefinedTable -initTable $global:InitializationTable
    if ($null -eq $global:FirstRefinedTable) { Throw "Failed to build FirstRefinedTable" }
    Set-Variable -Name "FirstRefinedTable" -Value $global:FirstRefinedTable -Scope Global -Option ReadOnly

    $global:ZipDecisionTable = Build-ZipDecisionTable -refinedTable $global:FirstRefinedTable
    if ($null -eq $global:ZipDecisionTable) { Throw "Failed to build ZipDecisionTable" }
    Set-Variable -Name "ZipDecisionTable" -Value $global:ZipDecisionTable -Scope Global -Option ReadOnly

    $compressTable = Build-CompressTable -zipDecisionTable $global:ZipDecisionTable
    if ($null -eq $compressTable -or $compressTable.Count -eq 0) {
        Write-Host "Everything is up to date, no changes made" -ForegroundColor Green
        # Summary for no changes
        if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('WhatIf')) {
            Write-Host "Summary: No files will be created as all zips are up to date." -ForegroundColor Cyan
        } else {
            $action = if ($debugMode) { "stub files" } else { "zip files" }
            Write-Host "Summary: No $action were created as everything is already up to date." -ForegroundColor Green
        }
    } else {
        Compress-Folders -decisionTable $compressTable -keepDuplicates:$keepDuplicates -CompressionLevel $CompressionLevel
        # Summary for changes
        if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('WhatIf')) {
            Write-Host "Summary: The following zip files would be created at '$destinationFolder' when run:" -ForegroundColor Cyan
            $compressTable | ForEach-Object {
                Write-Host "  - $($_.'Expected Zip')" -ForegroundColor Cyan
            }
        } else {
            $action = if ($debugMode) { "Stub files" } else { "Zip files" }
            Write-Host "Summary: The following $action were created at '$destinationFolder':" -ForegroundColor Green
            $compressTable | ForEach-Object {
                Write-Host "  - $($_.'Expected Zip')" -ForegroundColor Green
            }
        }
    }

    if ($VerbMode) {
        Write-Host "Initialization Table:"; $global:InitializationTable | Format-Table -AutoSize
        Write-Host "First Refined Table:"; $global:FirstRefinedTable | Format-Table -AutoSize
        Write-Host "Zip Decision Table:"; $global:ZipDecisionTable | Format-Table -AutoSize
        Write-Host "Compress Table:"; $compressTable | Format-Table -AutoSize
    }

    Write-Host "Script completed successfully" -ForegroundColor Green
    if (-not $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('WhatIf')) {
        try { Stop-Transcript -ErrorAction Stop | Out-Null } catch {}
    }
}

main