#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build and package TrailerLovers-NoPSN theme for release

.PARAMETER Version
    Version number for the release (e.g., "latest")

.EXAMPLE
    .\build-simple.ps1 -Version "latest"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Version = "latest"
)

$ErrorActionPreference = "Stop"

# Get script directory and theme root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ThemeRoot = Split-Path -Parent $ScriptDir
$ProjectName = "TrailerLovers-NoPSN"

Write-Host "🎮 Building $ProjectName package" -ForegroundColor Cyan
Write-Host "Theme directory: $ThemeRoot" -ForegroundColor Gray
Write-Host ""

# Create releases directory
$OutputPath = Join-Path $ThemeRoot "releases"
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    Write-Host "Created releases directory" -ForegroundColor Green
}

# Package details
$timestamp = Get-Date -Format "yyyy-MM-dd-HHmm"
$packageName = "$ProjectName-$timestamp.pthm"
$packagePath = Join-Path $OutputPath $packageName
$tempDir = Join-Path $ThemeRoot "temp-package"

Write-Host "📦 Creating package: $packageName" -ForegroundColor Yellow

try {
    # Create temporary directory
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    
    # Files/folders to exclude
    $excludePatterns = @(
        ".git*",
        "*.md",
        "LICENSE", 
        "temp-*",
        "scripts",
        ".github",
        "releases"
    )
    
    Push-Location $ThemeRoot
    
    # Copy theme files
    Get-ChildItem -Path "." | Where-Object { 
        $item = $_
        -not ($excludePatterns | Where-Object { $item.Name -like $_ })
    } | Copy-Item -Destination $tempDir -Recurse -Force
    
    # Create .pthm file (ZIP with different extension)
    if (Test-Path $packagePath) {
        Remove-Item $packagePath -Force
    }
    
    $tempFiles = Join-Path $tempDir "*"
    Compress-Archive -Path $tempFiles -DestinationPath $packagePath -CompressionLevel Optimal
    
    Pop-Location
    
    # Get package size
    $packageSize = [math]::Round((Get-Item $packagePath).Length / 1MB, 2)
    
    Write-Host ""
    Write-Host "✅ Package created successfully!" -ForegroundColor Green
    Write-Host "  📁 File: $packageName" -ForegroundColor White
    Write-Host "  📍 Location: $packagePath" -ForegroundColor White  
    Write-Host "  📊 Size: $packageSize MB" -ForegroundColor White
    
} catch {
    Write-Host ""
    Write-Host "❌ Package creation failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    # Clean up temp directory
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force
    }
}

Write-Host ""
Write-Host "🎉 Ready to upload!" -ForegroundColor Green
Write-Host "  1. Go to: https://github.com/DreadHeadHippy/TrailerLovers-NoPSN/releases" -ForegroundColor White
Write-Host "  2. Click 'Create a new release'" -ForegroundColor White
Write-Host "  3. Upload: $packageName" -ForegroundColor White