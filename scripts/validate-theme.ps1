#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validate TrailerLovers-Personal theme structure and files

.DESCRIPTION
    This script validates the theme structure, XAML syntax, and metadata files
    to ensure the theme will work correctly in Playnite.

.PARAMETER Fix
    Attempt to fix common issues automatically

.EXAMPLE
    .\validate-theme.ps1
    
.EXAMPLE
    .\validate-theme.ps1 -Fix
#>

param(
    [Parameter(Mandatory = $false)]
    [switch]$Fix = $false
)

$ErrorActionPreference = "Stop"

# Get paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ThemeRoot = Split-Path -Parent $ScriptDir
$ProjectName = "TrailerLovers-NoPSN"

Write-Host "🔍 Validating $ProjectName theme" -ForegroundColor Cyan
Write-Host "Theme directory: $ThemeRoot" -ForegroundColor Gray
Write-Host ""

$errors = @()
$warnings = @()
$fixes = @()

Push-Location $ThemeRoot

try {
    # Check required files
    Write-Host "📁 Checking required files..." -ForegroundColor Yellow
    
    $requiredFiles = @{
        "theme.yaml" = "Theme metadata file"
        "Constants.xaml" = "Theme constants and resources"
    }
    
    foreach ($file in $requiredFiles.Keys) {
        if (Test-Path $file) {
            Write-Host "  ✓ $file - $($requiredFiles[$file])" -ForegroundColor Green
        } else {
            $errors += "Missing required file: $file ($($requiredFiles[$file]))"
        }
    }
    
    # Check recommended files
    $recommendedFiles = @{
        "README.md" = "Project documentation"
        "LICENSE" = "License file"
        "CHANGELOG.md" = "Version history"
    }
    
    foreach ($file in $recommendedFiles.Keys) {
        if (Test-Path $file) {
            Write-Host "  ✓ $file - $($recommendedFiles[$file])" -ForegroundColor Green
        } else {
            $warnings += "Missing recommended file: $file ($($recommendedFiles[$file]))"
        }
    }
    
    # Check required directories
    Write-Host ""
    Write-Host "📂 Checking directory structure..." -ForegroundColor Yellow
    
    $requiredDirs = @{
        "Views" = "Theme view templates"
        "DefaultControls" = "Default control styles"
        "DerivedStyles" = "Custom derived styles"
        "CustomControls" = "Custom control templates"
    }
    
    foreach ($dir in $requiredDirs.Keys) {
        if (Test-Path $dir -PathType Container) {
            $fileCount = (Get-ChildItem $dir -Filter "*.xaml" | Measure-Object).Count
            Write-Host "  ✓ $dir/ - $($requiredDirs[$dir]) ($fileCount XAML files)" -ForegroundColor Green
        } else {
            $errors += "Missing required directory: $dir ($($requiredDirs[$dir]))"
        }
    }
    
    # Validate theme.yaml
    Write-Host ""
    Write-Host "📋 Validating theme.yaml..." -ForegroundColor Yellow
    
    if (Test-Path "theme.yaml") {
        try {
            $themeContent = Get-Content "theme.yaml" -Raw
            
            # Check required fields
            $requiredFields = @{
                "ThemeApiVersion" = "^\s*ThemeApiVersion:\s*[\d\.]+\s*$"
                "Mode" = "^\s*Mode:\s*Fullscreen\s*$"
                "Id" = "^\s*Id:\s*.+\s*$"
                "Name" = "^\s*Name:\s*.+\s*$"
                "Author" = "^\s*Author:\s*.+\s*$"
                "Version" = "^\s*Version:\s*[\d\.]+\s*$"
            }
            
            foreach ($field in $requiredFields.Keys) {
                if ($themeContent -match $requiredFields[$field]) {
                    $value = ($themeContent -split "`n" | Where-Object { $_ -match "^\s*$field:" }).Trim() -replace "^\s*$field:\s*", ""
                    Write-Host "  ✓ $field`: $value" -ForegroundColor Green
                } else {
                    $errors += "Missing or invalid field in theme.yaml: $field"
                }
            }
            
        } catch {
            $errors += "Failed to parse theme.yaml: $($_.Exception.Message)"
        }
    }
    
    # Validate XAML files
    Write-Host ""
    Write-Host "🎨 Validating XAML files..." -ForegroundColor Yellow
    
    $xamlFiles = Get-ChildItem -Path "." -Filter "*.xaml" -Recurse
    $validXaml = 0
    $invalidXaml = 0
    
    foreach ($file in $xamlFiles) {
        try {
            [xml]$xmlContent = Get-Content $file.FullName -Raw -Encoding UTF8
            $validXaml++
            
            # Check for common issues
            if ($xmlContent.OuterXml -match 'xmlns="[^"]*"') {
                Write-Host "  ✓ $($file.Name)" -ForegroundColor Green
            } else {
                $warnings += "XAML file may be missing namespace declaration: $($file.Name)"
            }
            
        } catch {
            $invalidXaml++
            $errors += "Invalid XAML in $($file.Name): $($_.Exception.Message)"
        }
    }
    
    Write-Host "  📊 $validXaml valid, $invalidXaml invalid XAML files" -ForegroundColor Gray
    
    # Check for screenshots
    Write-Host ""
    Write-Host "📸 Checking screenshots..." -ForegroundColor Yellow
    
    $screenshots = Get-ChildItem -Path "." -Name "Screenshot*.png", "screenshot*.png" | Sort-Object
    if ($screenshots.Count -gt 0) {
        foreach ($screenshot in $screenshots) {
            $size = [math]::Round((Get-Item $screenshot).Length / 1MB, 2)
            Write-Host "  ✓ $screenshot ($size MB)" -ForegroundColor Green
        }
    } else {
        $warnings += "No screenshots found - consider adding Screenshot-*.png files for documentation"
    }
    
    # Check image resources
    Write-Host ""
    Write-Host "🖼️ Checking image resources..." -ForegroundColor Yellow
    
    if (Test-Path "Images" -PathType Container) {
        $imageFiles = Get-ChildItem "Images" -Filter "*.png" | Measure-Object
        Write-Host "  ✓ Images/ directory ($($imageFiles.Count) PNG files)" -ForegroundColor Green
    } else {
        $warnings += "No Images/ directory found"
    }
    
    if (Test-Path "Media" -PathType Container) {
        $mediaFiles = Get-ChildItem "Media" | Measure-Object
        Write-Host "  ✓ Media/ directory ($($mediaFiles.Count) files)" -ForegroundColor Green
    }
    
    # Apply fixes if requested
    if ($Fix -and $fixes.Count -gt 0) {
        Write-Host ""
        Write-Host "🔧 Applying fixes..." -ForegroundColor Yellow
        foreach ($fix in $fixes) {
            Write-Host "  ⚡ $fix" -ForegroundColor Cyan
        }
    }
    
} finally {
    Pop-Location
}

# Report results
Write-Host ""
Write-Host "📋 Validation Results:" -ForegroundColor Cyan
Write-Host ""

if ($errors.Count -eq 0) {
    Write-Host "✅ Theme validation passed!" -ForegroundColor Green
} else {
    Write-Host "❌ Theme validation failed with $($errors.Count) error(s):" -ForegroundColor Red
    foreach ($error in $errors) {
        Write-Host "  • $error" -ForegroundColor Red
    }
}

if ($warnings.Count -gt 0) {
    Write-Host ""
    Write-Host "⚠️  $($warnings.Count) warning(s):" -ForegroundColor Yellow
    foreach ($warning in $warnings) {
        Write-Host "  • $warning" -ForegroundColor Yellow
    }
}

Write-Host ""
if ($errors.Count -eq 0) {
    Write-Host "🎉 Your theme is ready for packaging and distribution!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Please fix the errors above before packaging the theme." -ForegroundColor Red
    exit 1
}