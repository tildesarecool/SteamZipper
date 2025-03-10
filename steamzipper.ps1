#pwsh -command '& { .\hashtable_build.ps1 "P:\steamzipper\steam temp storage" "P:\steamzipper\zip test output" -debugMode }'

param (
    [Parameter(Mandatory=$true, ParameterSetName="Manual")]
    [string]$sourceFolder,
    [Parameter(Mandatory=$true, ParameterSetName="Manual")]
    [string]$destinationFolder,
    [Parameter(ParameterSetName="Manual")]
    [string]$sourceFile,  # New optional parameter
    [switch]$debugMode,
    [switch]$VerbMode,
    [switch]$keepDuplicates,
    [ValidateSet("Optimal", "Fastest", "NoCompression")]
    [string]$CompressionLevel = "Optimal",
    [Parameter(ParameterSetName="AnswerFile")]
    [string]$answerFile,
    [string]$createAnswerFile
)

# Load answer file if provided
if ($answerFile) {
    if (-not (Test-Path $answerFile)) { Write-Error "Answer file '$answerFile' not found"; exit 1 }
    $params = Get-Content $answerFile -Raw | ConvertFrom-Json
    $sourceFolder = $params.sourceFolder
    $destinationFolder = $params.destinationFolder
    $debugMode = $params.debugMode
    $VerbMode = $params.VerbMode
    $keepDuplicates = $params.keepDuplicates
    $CompressionLevel = $params.CompressionLevel
    # If we later allow sourceFile in answerFile, add: $sourceFile = $params.sourceFile
}

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
    if ($sourceFile) {
        # Check if sourceFile is a simple filename (no path separators)
        if ($sourceFile -notmatch '[\\/]') {
            $potentialPath = Join-Path -Path $global:scriptfolder -ChildPath $sourceFile
            if (Test-Path $potentialPath) {
                $sourceFilePath = $potentialPath
            } else {
                # If not in script folder, assume it's a full path
                $sourceFilePath = $sourceFile
            }
        } else {
            $sourceFilePath = $sourceFile
        }
        if (-not (Test-Path $sourceFilePath)) { Write-Error "Source file '$sourceFilePath' not found"; exit 1 }
        $subfolderNames = Get-Content $sourceFilePath | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim() }
        $subfolders = $subfolderNames | ForEach-Object {
            $fullPath = Join-Path -Path $sourceFolder -ChildPath $_
            if (Test-Path $fullPath -PathType Container) {
                [PSCustomObject]@{
                    Name = $_
                    LastWriteTime = (Get-Item $fullPath).LastWriteTime
                }
            } else {
                if ($VerbMode) { Write-Host "Warning: '$fullPath' not found, skipping" }
            }
        } | Where-Object { $_ }
    } else {
        $subfolders = Get-ChildItem -Path $sourceFolder -Directory | Select-Object Name, LastWriteTime
    }
    $files = Get-ChildItem -Path $destinationFolder -File -Filter "*.$global:CompressionExtension" | Select-Object Name
    $hashTable = @()
    $maxCount = [Math]::Max($subfolders.Count, $files.Count)
    for ($i = 0; $i -lt $maxCount; $i++) {
        $hashTable += [PSCustomObject]@{
            "Subfolder Name" = if ($i -lt $subfolders.Count) { $subfolders[$i].Name } else { "" }
            "Folder Last Write Date" = if ($i -lt $subfolders.Count) { $subfolders[$i].LastWriteTime } else { "" }
            "File Name" = if ($i -lt $files.Count) { $files[$i].Name } else { "" }
        }
    }
    if ($VerbMode) { Write-Host "Built initialization table with $maxCount entries" }
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
            if ($VerbMode) { Write-Host "Subfolder $($entry.'Subfolder Name') has no existing zip, marked as NeedsZip" }  # Changed from $debugMode
        } else {
            $existingParts = $entry."Zip File Name" -split "_"
            $existingDate = [datetime]::ParseExact($existingParts[-2], $global:PreferredDateFormat, $null)
            if ($existingDate -lt $entry."Folder Last Write Date") {
                $status = "NeedsUpdate"
                if ($VerbMode) { Write-Host "Subfolder $($entry.'Subfolder Name') zip ($($entry.'Zip File Name')) is older than folder, marked as NeedsUpdate" }  # Changed from $debugMode
            } else {
                $status = "NoAction"
                if ($VerbMode) { Write-Host "Subfolder $($entry.'Subfolder Name') zip ($($entry.'Zip File Name')) is current or newer, marked as NoAction" }  # Changed from $debugMode
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
    if ($VerbMode) { Write-Host "Built zip decision table with $($decisionTable.Count) entries" }  # Changed from $debugMode
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
function Create-StubZip {
    param (
        [string]$ZipPath
    )
    if ($debugMode) {
        New-Item -Path $ZipPath -ItemType File -Force | Out-Null
        Write-Host "Created stub zip: $ZipPath (0 KB)"
    }
}
function Move-DuplicateZips {
    param ([string]$SubfolderName, [datetime]$ReferenceDate, [string]$ExpectedZip, [string]$DestinationFolder, [string]$DeletedFolder, [switch]$KeepDuplicates)
    if (-not $KeepDuplicates) {  # Removed $debugMode condition—moves should always happen unless -keepDuplicates
        $platform = Get-PlatformShortName
        $duplicateZips = Get-ChildItem -Path $DestinationFolder -Filter "${SubfolderName}*_${platform}.$global:CompressionExtension" | 
                         Where-Object { $dupDate = Get-FileDateStamp -InputValue $_.Name; $dupDate -and $dupDate -lt $ReferenceDate -and $_.Name -ne $ExpectedZip }
        foreach ($dup in $duplicateZips) {
            $dupPath = $dup.FullName
            $deletedDupPath = Join-Path -Path $DeletedFolder -ChildPath $dup.Name
            Move-Item -Path $dupPath -Destination $deletedDupPath -Force
            if ($VerbMode) { Write-Host "Moved duplicate older zip to: $deletedDupPath" }  # Changed from Write-Host without condition
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
        if ($VerbMode) { Write-Host "Checking $($subfolder.'Subfolder Name'): Size $folderSizeKB KB" }  # Changed from $debugMode
        if ($folderSizeKB -lt $global:sizeLimitKB) {
            if ($VerbMode) { Write-Host "Skipping empty subfolder: $($subfolder.'Subfolder Name') (Size: $folderSizeKB KB)" }  # Changed from $debugMode
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
            "Zip File Name" = if ($matchingZip) { $matchingZip.Name } else { $expectedZip }
        }
    }
    if ($VerbMode) { Write-Host "Built first refined table with $($refinedTable.Count) entries" }  # Changed from $debugMode
    return $refinedTable
}
function Build-CompressTable {
    param ([Parameter(Mandatory=$true)] $zipDecisionTable)
    $platform = Get-PlatformShortName
    $compressTable = $zipDecisionTable | Where-Object { $_.Status -in @("NeedsZip", "NeedsUpdate") } | ForEach-Object {
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
            "Folder Last Write Date" = $_."Folder Last Write Date"  # Add this
            "Expected Zip" = $_."Expected Zip Name"
            "Existing Zip" = $latestZip
            "Old Zips" = $oldZips
            "Status" = $_.Status
        }
    } | Sort-Object "Status", "Subfolder Name"
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
    if (-not (Test-Path -Path $deletedFolder)) { New-Item -Path $deletedFolder -ItemType Directory | Out-Null; if ($VerbMode) { Write-Host "Created deleted folder: $deletedFolder" } }

    foreach ($entry in $decisionTable) {
        $sourcePath = Join-Path -Path $sourceFolder -ChildPath $entry."Subfolder Name"
        $zipPath = Join-Path -Path $destinationFolder -ChildPath $entry."Expected Zip"
        
        # Handle duplicates if needed
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

        if (-not $debugMode) {
            $timer = Measure-Command {
                Compress-Archive -Path $sourcePath -DestinationPath $zipPath -Force -CompressionLevel $CompressionLevel -ErrorAction Stop
                Write-Host "Compressed $($entry.'Subfolder Name') to $zipPath"
                if ($VerbMode) { Write-Host "Compression completed for $($entry.'Subfolder Name')" }
            }
            $roundedTime = [Math]::Round($timer.TotalSeconds, 1)  # Round to 1 decimal place
            Write-Host "Operation for $($entry.'Subfolder Name') took $roundedTime seconds"
        } else {
            New-Item -Path $zipPath -ItemType File -Force | Out-Null
            Write-Host "Created stub zip: $zipPath (0 KB)"
            if ($VerbMode) { Write-Host "Stub created for $($entry.'Subfolder Name')" }
        }
    }
}
# Main execution function

function main {
    Write-Host "Welcome to SteamZipper!" -ForegroundColor Cyan
    Write-Host "This script zips your Steam folders. Ensure the storage device of '$destinationFolder' has enough space!" -ForegroundColor Yellow
    Write-Host "Running on $([System.Environment]::MachineName) - $(Get-Date)" -ForegroundColor Green

    $transcriptPath = Join-Path -Path $global:scriptfolder -ChildPath $global:logBaseName
    try { Start-Transcript -Path $transcriptPath -Force -ErrorAction Stop | Out-Null } catch {}

    # ... existing code ...
    if ($createAnswerFile) {
        $answerData = [PSCustomObject]@{
            sourceFolder = $sourceFolder
            destinationFolder = $destinationFolder
            debugMode = [bool]$debugMode
            VerbMode = [bool]$VerbMode
            keepDuplicates = [bool]$keepDuplicates
            CompressionLevel = $CompressionLevel
        }
        $answerData | ConvertTo-Json | Out-File $createAnswerFile -Force
        Write-Host "Created answer file: $createAnswerFile"
    }

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
    if ($null -eq $compressTable) { Throw "Failed to build CompressTable" }
    Compress-Folders -decisionTable $compressTable -keepDuplicates:$keepDuplicates -CompressionLevel $CompressionLevel

    if ($VerbMode) {
        Write-Host "Initialization Table:"; $global:InitializationTable | Format-Table -AutoSize
        Write-Host "First Refined Table:"; $global:FirstRefinedTable | Format-Table -AutoSize
        Write-Host "Zip Decision Table:"; $global:ZipDecisionTable | Format-Table -AutoSize
        Write-Host "Compress Table:"; $compressTable | Format-Table -AutoSize
    }

    try { Stop-Transcript -ErrorAction Stop | Out-Null } catch {}
}

main