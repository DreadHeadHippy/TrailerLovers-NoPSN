#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Install TrailerLovers-Personal theme locally for testing

.DESCRIPTION
    This script installs the theme directly into Playnite's theme directory for local testing.
    It will backup any existing installation and create symlinks for easy development.

.PARAMETER Mode
    Installation mode: 'copy' (default) or 'link'
    - copy: Copies files to Playnite directory
    - link: Creates symbolic links (requires admin rights, better for development)

.PARAMETER Force
    Force installation even if theme already exists

.EXAMPLE
    .\install-local.ps1
    
.EXAMPLE
    .\install-local.ps1 -Mode link -Force
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("copy", "link")]
    [string]$Mode = "copy",
    
    [Parameter(Mandatory = $false)]
    [switch]$Force = $false
)

$ErrorActionPreference = "Stop"

# Get paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ThemeRoot = Split-Path -Parent $ScriptDir
$ProjectName = "TrailerLovers-NoPSN"

# Determine Playnite directory
$PlayniteDataDir = Join-Path $env:APPDATA "Playnite"
$ThemesDir = Join-Path $PlayniteDataDir "Themes\Fullscreen"
$InstallDir = Join-Path $ThemesDir $ProjectName

Write-Host "🎮 Installing $ProjectName for local testing" -ForegroundColor Cyan
Write-Host ""
Write-Host "Source: $ThemeRoot" -ForegroundColor Gray
Write-Host "Target: $InstallDir" -ForegroundColor Gray
Write-Host "Mode: $Mode" -ForegroundColor Gray
Write-Host ""

# Check if Playnite directory exists
if (-not (Test-Path $PlayniteDataDir)) {
    throw "Playnite data directory not found: $PlayniteDataDir`nPlease ensure Playnite is installed and has been run at least once."
}

# Create themes directory if it doesn't exist
if (-not (Test-Path $ThemesDir)) {
    New-Item -ItemType Directory -Path $ThemesDir -Force | Out-Null
    Write-Host "Created themes directory: $ThemesDir" -ForegroundColor Green
}

# Check if theme already exists
if (Test-Path $InstallDir) {
    if (-not $Force) {
        $choice = Read-Host "Theme already installed. Replace it? (y/N)"
        if ($choice -ne 'y' -and $choice -ne 'Y') {
            Write-Host "Installation cancelled." -ForegroundColor Yellow
            return
        }
    }
    
    Write-Host "Removing existing installation..." -ForegroundColor Yellow
    Remove-Item $InstallDir -Recurse -Force
}

# Files to exclude from installation
$excludePatterns = @(
    ".git*",
    "*.md",
    "LICENSE", 
    "temp-*",
    "scripts",
    ".github",
    "releases"
)

try {
    if ($Mode -eq "link") {
        # Check for admin rights
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
        
        if (-not $isAdmin) {
            throw "Symbolic link mode requires administrator privileges. Please run as administrator or use -Mode copy"
        }
        
        Write-Host "Creating symbolic link..." -ForegroundColor Yellow
        New-Item -ItemType SymbolicLink -Path $InstallDir -Target $ThemeRoot | Out-Null
        Write-Host "✓ Symbolic link created" -ForegroundColor Green
        
    } else {
        Write-Host "Copying theme files..." -ForegroundColor Yellow
        
        # Create target directory
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
        
        Push-Location $ThemeRoot
        
        try {
            # Copy files excluding patterns
            Get-ChildItem -Path "." | Where-Object { 
                $item = $_
                -not ($excludePatterns | Where-Object { $item.Name -like $_ })
            } | Copy-Item -Destination $InstallDir -Recurse -Force
            
            Write-Host "✓ Theme files copied" -ForegroundColor Green
        }
        finally {
            Pop-Location
        }
    }
    
    Write-Host ""
    Write-Host "🎉 Installation completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Launch Playnite" -ForegroundColor White
    Write-Host "  2. Press F4 to enter Fullscreen mode" -ForegroundColor White
    Write-Host "  3. Go to Settings (gear icon) → General → Theme" -ForegroundColor White
    Write-Host "  4. Select '$ProjectName' from the dropdown" -ForegroundColor White
    Write-Host "  5. Apply and enjoy!" -ForegroundColor White
    
    if ($Mode -eq "link") {
        Write-Host ""
        Write-Host "💡 Development tip:" -ForegroundColor Cyan
        Write-Host "   Changes to source files will be reflected immediately in Playnite!" -ForegroundColor White
    }
    
} catch {
    Write-Host ""
    Write-Host "❌ Installation failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}