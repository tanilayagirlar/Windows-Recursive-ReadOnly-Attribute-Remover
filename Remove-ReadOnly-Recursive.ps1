# Top-level folder to process.
# Use a local drive path when running the script on the file server.
$root = "E:\SharedFolder\TargetFolder"


# Folder where CSV logs will be saved.
# The following command creates it if it does not exist.
$logFolder = "C:\Temp"
New-Item -ItemType Directory -Path $logFolder -Force | Out-Null

# Creates a separate timestamped CSV log for each execution.
$logPath = Join-Path $logFolder "remove-readonly-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"

# Opens the log file. UTF-8 BOM helps Excel display non-ASCII characters correctly.
$writer = [System.IO.StreamWriter]::new(
    $logPath,
    $false,
    [System.Text.UTF8Encoding]::new($true)
)


# Counters displayed in the final console summary.
$counts = @{
    Changed            = 0
    AlreadyNotReadOnly = 0
    Errors             = 0
}


function Convert-CsvField {
    param([object]$Value)

    # Escapes double quotes to preserve valid CSV formatting.
    '"' + ([string]$Value).Replace('"', '""') + '"'
}


function Write-Log {
    param(
        [string]$Status,
        [string]$Type,
        [string]$Path,
        [string]$PreviousAttributes,
        [string]$Error
    )

    # Writes each record directly to the CSV file.
    # Results are not collected in memory, making this safe for large folders.
    $fields = @(
        (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),
        $Status,
        $Type,
        $Path,
        $PreviousAttributes,
        $Error
    )

    $writer.WriteLine(
        ($fields | ForEach-Object { Convert-CsvField $_ }) -join ","
    )
}


function Process-Item {
    param($Item)

    # Saves the file or directory's existing attributes.
    # For example: Archive, Hidden, Directory, ReadOnly.
    $oldAttributes = $Item.Attributes

    # Checks whether the ReadOnly attribute is present.
    $isReadOnly = [bool](
        $oldAttributes -band [IO.FileAttributes]::ReadOnly
    )

    # Determines the item type for the log.
    $itemType = if ($Item.PSIsContainer) { "Directory" } else { "File" }

    # Skips items that are already not ReadOnly.
    if (-not $isReadOnly) {
        $counts.AlreadyNotReadOnly++
        return
    }

    try {
        # Removes only the ReadOnly attribute.
        # Other attributes, such as Hidden and Archive, are preserved.
        $Item.Attributes = $oldAttributes -band (
            -bnot [IO.FileAttributes]::ReadOnly
        )

        # Logs successful changes.
        Write-Log `
            -Status "ReadOnly removed" `
            -Type $itemType `
            -Path $Item.FullName `
            -PreviousAttributes $oldAttributes `
            -Error ""

        $counts.Changed++
    }
    catch {
        # Logs permission, locked-file, or file-system errors.
        Write-Log `
            -Status "ERROR" `
            -Type $itemType `
            -Path $Item.FullName `
            -PreviousAttributes $oldAttributes `
            -Error $_.Exception.Message

        $counts.Errors++
    }
}


try {
    # CSV column headers.
    $writer.WriteLine(
        '"Date","Status","Type","Path","Previous Attributes","Error"'
    )

    # Get-ChildItem does not include the root directory itself,
    # so it is processed separately.
    try {
        Process-Item (
            Get-Item -LiteralPath $root -Force -ErrorAction Stop
        )
    }
    catch {
        Write-Log `
            -Status "ROOT DIRECTORY ERROR" `
            -Type "Directory" `
            -Path $root `
            -PreviousAttributes "" `
            -Error $_.Exception.Message

        $counts.Errors++
    }

    # -Recurse: scans every nested folder and file.
    # -Force: includes hidden and system items.
    # 2>&1: captures scan errors and writes them to the CSV log.
    #
    # Items are processed one at a time and are not stored
    # as a full list in memory.
    Get-ChildItem -LiteralPath $root -Force -Recurse -ErrorAction Continue 2>&1 |
        ForEach-Object {
            if ($_ -is [System.Management.Automation.ErrorRecord]) {
                # Logs scan errors, such as inaccessible directories.
                Write-Log `
                    -Status "SCAN ERROR" `
                    -Type "" `
                    -Path "" `
                    -PreviousAttributes "" `
                    -Error $_.ToString()

                $counts.Errors++
            }
            else {
                # Processes the current file or directory.
                Process-Item $_
            }
        }
}
finally {
    # Ensures that the log file is closed even if the script fails.
    $writer.Flush()
    $writer.Dispose()
}


# Displays the operation summary and log location.
Write-Host ""
Write-Host "Completed."
Write-Host "ReadOnly removed:       $($counts.Changed)"
Write-Host "Already not ReadOnly:   $($counts.AlreadyNotReadOnly)"
Write-Host "Errors:                 $($counts.Errors)"
Write-Host "Log: $logPath"
