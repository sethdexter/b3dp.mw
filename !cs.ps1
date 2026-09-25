# Define the output file name
$OutputFile = "project_complete_context.txt"

# Target extensions to scrape
$Extensions = @("*.gd", "*.cs", "*.tscn", "*.tres")

# Header instructions for the AI
$Header = @"
# GODOT PROJECT COMPLETE SOURCE CONTEXT
# This file contains the complete script, structure, scene data, and text resources for this Godot project.

"@

# Write the fresh header to the file (using UTF8 for compatibility)
Set-Content -Path $OutputFile -Value $Header -Encoding UTF8

Write-Host "⚙️ Generating directory tree..." -ForegroundColor Cyan

# Append directory structure section header
Add-Content -Path $OutputFile -Value "=== PROJECT DIRECTORY STRUCTURE ==="
Add-Content -Path $OutputFile -Value "."

# Function to build the ASCII tree structure (excluding .godot, addons, and output file)
function Get-DirectoryTree {
    param (
        [string]$Path,
        [string]$Indent = ""
    )
    $items = Get-ChildItem -Path $Path | Where-Object { 
        $_.Name -ne ".godot" -and $_.Name -ne "addons" -and $_.Name -ne $OutputFile 
    }
    $count = $items.Count
    $index = 0

    foreach ($item in $items) {
        $index++
        $isLast = ($index -eq $count)
        $connector = if ($isLast) { "└── " } else { "├── " }
        
        Add-Content -Path $OutputFile -Value "$Indent$connector$($item.Name)"

        if ($item.PSIsContainer) {
            $subIndent = if ($isLast) { "$Indent    " } else { "$Indent│   " }
            Get-DirectoryTree -Path $item.FullName -Indent $subIndent
        }
    }
}

Get-DirectoryTree -Path "."

Add-Content -Path $OutputFile -Value "`n=================================================="
Add-Content -Path $OutputFile -Value "=== FILE CONTENTS ==="
Add-Content -Path $OutputFile -Value "==================================================`n"

Write-Host "⚙️ Aggregating complete project context..." -ForegroundColor Cyan

# Find all matching files while ignoring .godot, addons, and the output file
Get-ChildItem -Path . -Recurse -Include $Extensions | 
    Where-Object { 
        $_.FullName -notlike "*\.godot\*" -and 
        $_.FullName -notlike "*/.godot/*" -and 
        $_.FullName -notlike "*\addons\*" -and 
        $_.FullName -notlike "*/addons/*" -and 
        $_.Name -ne $OutputFile 
    } | 
    ForEach-Object {
        # Convert absolute path to a clean relative path (e.g., ./path/to/file.gd)
        $RelativePath = $_.FullName.Replace((Get-Location).Path, ".") -replace '\\', '/'
        
        Write-Host "Processing: $RelativePath" -ForegroundColor Gray
        
        # Append the structured content blocks to our output file
        Add-Content -Path $OutputFile -Value $RelativePath
        Add-Content -Path $OutputFile -Value "--- CONTENT START ---"
        Add-Content -Path $OutputFile -Value (Get-Content -Path $_.FullName -Raw)
        Add-Content -Path $OutputFile -Value "--- CONTENT END ---`n"
    }

Write-Host "✅ SUCCESS: Project context compiled into $OutputFile" -ForegroundColor Green