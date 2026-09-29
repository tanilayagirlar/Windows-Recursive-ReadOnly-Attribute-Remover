# Windows Recursive ReadOnly Remover

A PowerShell script that removes the **ReadOnly** file attribute from a target folder, including all nested folders and files.

The script processes items one at a time, making it suitable for large directory trees without holding the entire file list in memory. It writes successful changes and errors to a timestamped CSV log file.

> This tool changes only the Windows `ReadOnly` attribute. It does not modify NTFS permissions or network-share permissions.

## Features

- Removes the `ReadOnly` attribute recursively
- Includes the target folder, subfolders, and files
- Supports hidden and system items
- Processes items sequentially to minimize memory usage
- Creates a timestamped CSV log
- Logs file-system and access errors
- Displays an operation summary when complete

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- Permission to modify attributes on the target files and folders
- Permission to write the log file locally

## Usage

1. Download or clone this repository.

2. Open `Remove-ReadOnly-Recursive.ps1` in a text editor.

3. Set the target directory:

```powershell
$root = "E:\SharedFolder\TargetFolder"
