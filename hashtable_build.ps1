# Define the source directories
$folderPath1 = "C:\Users\keith\Documents\steam temp storage"
$folderPath2 = "C:\Users\keith\Documents\steambackup"

# Validate directories exist
if (!(Test-Path -Path $folderPath1 -PathType Container)) {
    Write-Error "Folder path 1 does not exist: $folderPath1"
    exit
}
if (!(Test-Path -Path $folderPath2 -PathType Container)) {
    Write-Error "Folder path 2 does not exist: $folderPath2"
    exit
}

# Retrieve and independently sort subfolder names by last write date (oldest to newest)
$subfolders = Get-ChildItem -Path $folderPath1 -Directory | 
              Select-Object Name, @{Name='LastWriteTime'; Expression={$_.LastWriteTime}} |
              Sort-Object LastWriteTime

# Retrieve file names and extract date codes, then sort independently (oldest to newest)
$files = Get-ChildItem -Path $folderPath2 -File | 
         Select-Object Name, @{Name='LastWriteTime'; Expression={
            $parts = $_.Name -split "_"
            if ($parts.Count -ge 3) {
                [datetime]::ParseExact($parts[-2], 'MMddyyyy', $null)
            } else {
                $null
            }
         }} |
         Sort-Object LastWriteTime

# Create an ordered hash table
$hashTable = @()

# Get max count for alignment
$maxCount = [Math]::Max($subfolders.Count, $files.Count)

# Iterate and populate the hash table
for ($i = 0; $i -lt $maxCount; $i++) {
    $folderName = if ($i -lt $subfolders.Count) { $subfolders[$i].Name } else { "" }
    $folderDate = if ($i -lt $subfolders.Count) { $subfolders[$i].LastWriteTime } else { "" }
    $fileName = if ($i -lt $files.Count) { $files[$i].Name } else { "" }
    $fileDate = if ($i -lt $files.Count) { $files[$i].LastWriteTime } else { "" }
    
    $hashTable += [PSCustomObject]@{
        "Subfolder Name" = $folderName
        "Folder Last Write Date" = $folderDate
        "File Name" = $fileName
        "File Last Write Date" = $fileDate
    }
}

# Output the hash table
$hashTable | Format-Table -AutoSize
