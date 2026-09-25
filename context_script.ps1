# Define the output file name
$OutputFile = "project_complete_context.txt"

# Target extensions to scrape
$Extensions = @("*.gd", "*.cs", "*.tscn", "*.tres")

# Exclude patterns (e.g., Godot cache, git folder, heavy third-party addons)
$ExcludeDirs = @("\.godot\", "\.git\")

# Header instructions for the AI
$Header = @"
# GODOT PROJECT COMPLETE SOURCE CONTEXT
# This file contains the complete script, structure, scene data, and text resources for this Godot project.

"@

Write-Host "⚙️ Aggregating complete project context..." -ForegroundColor Cyan

# Initialize a StringBuilder for fast in-memory aggregation
$StringBuilder = [System.Text.StringBuilder]::new()
[void]$StringBuilder.AppendLine($Header)

$CurrentPath = (Get-Location).Path

# Find matching files
$Files = Get-ChildItem -Path . -Recurse -Include $Extensions | Where-Object {
    $filePath = $_.FullName
    $isExcluded = $false
    
    # Check against excluded directories
    foreach ($dir in $ExcludeDirs) {
        if ($filePath -like "*$dir*") {
            $isExcluded = $true
            break
        }
    }
    
    # Ensure it's not the output file itself and not excluded
    -not $isExcluded -and $_.Name -ne $OutputFile
}

foreach ($File in $Files) {
    # Convert absolute path to a clean relative path (e.g., ./path/to/file.gd)
    $RelativePath = $File.FullName.Replace($CurrentPath, ".") -replace '\\', '/'
    
    Write-Host "Processing: $RelativePath" -ForegroundColor Gray
    
    # Append content block
    [void]$StringBuilder.AppendLine($RelativePath)
    [void]$StringBuilder.AppendLine("--- CONTENT START ---")
    [void]$StringBuilder.AppendLine((Get-Content -Path $File.FullName -Raw -Encoding UTF8))
    [void]$StringBuilder.AppendLine("--- CONTENT END ---`n")
}

# Write out the entire string buffer using UTF8 without BOM
[System.IO.File]::WriteAllText((Join-Path $CurrentPath $OutputFile), $StringBuilder.ToString(), [System.Text.Encoding]::UTF8)

Write-Host "✅ SUCCESS: Project context compiled into $OutputFile" -ForegroundColor Green