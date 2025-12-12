#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build and package TrailerLovers-Personal theme for release

.DESCRIPTION
    This script creates a distributable .pthm package file for the TrailerLovers-Personal theme.
    It validates the theme structure, updates version numbers, and creates a package ready for distribution.

.PARAMETER Version
    Version number for the release (e.g., "1.0.3")

.PARAMETER OutputDir
    Directory where the package file will be created (default: "./releases")

.PARAMETER Validate
    Validate theme structure before packaging (default: true)

.EXAMPLE
    .\build-release.ps1 -Version "1.0.4"
    
.EXAMPLE
    .\build-release.ps1 -Version "1.0.4" -OutputDir "C:\Releases" -Validate:$false
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputDir = "./releases",
    
    [Parameter(Mandatory = $false)]
    [switch]$Validate = $true
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Get script directory and theme root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ThemeRoot = Split-Path -Parent $ScriptDir
$ProjectName = "TrailerLovers-NoPSN"

Write-Host "🎮 Building $ProjectName v$Version" -ForegroundColor Cyan
Write-Host "Theme directory: $ThemeRoot" -ForegroundColor Gray
Write-Host ""

# Validate version format
if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    throw "Version must be in format X.Y.Z (e.g., 1.0.3)"
}

# Create output directory
$OutputPath = Join-Path $ThemeRoot $OutputDir
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    Write-Host "Created output directory: $OutputPath" -ForegroundColor Green
}

# Validation step
if ($Validate) {
    Write-Host "🔍 Validating theme structure..." -ForegroundColor Yellow
    
    $requiredFiles = @(
        "theme.yaml",
        "Constants.xaml",
        "README.md"
    )
    
    $requiredDirs = @(
        "Views",
        "DefaultControls",
        "DerivedStyles",
        "CustomControls"
    )
    
    Push-Location $ThemeRoot
    
    try {
        foreach ($file in $requiredFiles) {
            if (-not (Test-Path $file)) {
                throw "Missing required file: $file"
            }
            Write-Host "  ✓ $file" -ForegroundColor Green
        }
        
        foreach ($dir in $requiredDirs) {
            if (-not (Test-Path $dir -PathType Container)) {
                throw "Missing required directory: $dir"
            }
            Write-Host "  ✓ $dir/" -ForegroundColor Green
        }
        
        # Validate XAML files
        $xamlFiles = Get-ChildItem -Path "." -Filter "*.xaml" -Recurse
        foreach ($file in $xamlFiles) {
            try {
                [xml]$xmlContent = Get-Content $file.FullName -Raw
            } catch {
                throw "Invalid XAML in $($file.Name): $($_.Exception.Message)"
            }
        }
        
        Write-Host "  ✓ All XAML files valid" -ForegroundColor Green
        Write-Host ""
    }
    finally {
        Pop-Location
    }
}

# Update version in theme files
Write-Host "📝 Updating version to $Version..." -ForegroundColor Yellow

Push-Location $ThemeRoot

try {
    # Update theme.yaml
    $themeYamlPath = Join-Path $ThemeRoot "theme.yaml"
    if (Test-Path $themeYamlPath) {
        $themeContent = Get-Content $themeYamlPath -Raw
        $themeContent = $themeContent -replace "Version:\s*[\d\.]+", "Version: $Version"
        Set-Content $themeYamlPath -Value $themeContent -NoNewline
        Write-Host "  ✓ Updated theme.yaml" -ForegroundColor Green
    }
    
    # Update InstallerManifest.yaml
    $manifestPath = Join-Path $ThemeRoot "InstallerManifest.yaml"
    if (Test-Path $manifestPath) {
        $manifestContent = Get-Content $manifestPath -Raw
        $today = Get-Date -Format "yyyy-MM-dd"
        
        # Add new version entry at the top of packages
        $versionBlock = @"
  - Version: $Version
    RequiredApiVersion: 2.3.0
    ReleaseDate: $today
    PackageUrl: https://github.com/DreadHeadHippy/TrailerLovers-NoPSN/releases/download/v$Version/TrailerLovers-NoPSN-v$Version.pthm
    Changelog:
      - Version $Version release
      - See CHANGELOG.md for detailed changes
"@
        
        # Insert new version after "Packages:" line
        $manifestContent = $manifestContent -replace "(Packages:\r?\n)", "`$1$versionBlock`r`n"
        Set-Content $manifestPath -Value $manifestContent -NoNewline
        Write-Host "  ✓ Updated InstallerManifest.yaml" -ForegroundColor Green
    }
    
    # Update CHANGELOG.md
    $changelogPath = Join-Path $ThemeRoot "CHANGELOG.md"
    if (Test-Path $changelogPath) {
        $changelogContent = Get-Content $changelogPath -Raw
        $today = Get-Date -Format "yyyy-MM-dd"
        
        $newEntry = @"
## [$Version] - $today

### Added
- Version $Version improvements
- Enhanced packaging and distribution

### Changed
- Updated release process

### Fixed
- Various bug fixes and improvements

"@
        
        # Insert after "## [Unreleased]" section
        $changelogContent = $changelogContent -replace "(## \[Unreleased\].*?\r?\n\r?\n)", "`$1$newEntry`r`n"
        Set-Content $changelogPath -Value $changelogContent -NoNewline
        Write-Host "  ✓ Updated CHANGELOG.md" -ForegroundColor Green
    }
    
    Write-Host ""
}
finally {
    Pop-Location
}

# Create package
Write-Host "📦 Creating theme package..." -ForegroundColor Yellow

$tempDir = Join-Path $ThemeRoot "temp-package-$Version"
$packageName = "$ProjectName-v$Version.pthm"
$packagePath = Join-Path $OutputPath $packageName

try {
    # Create temporary directory
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    
    # Define files/folders to exclude from package
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
    
    # Copy theme files to temp directory
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
    
    Write-Host "  ✓ Created: $packageName" -ForegroundColor Green
    Write-Host "  📍 Location: $packagePath" -ForegroundColor Gray
    
    # Get package size
    $packageSize = [math]::Round((Get-Item $packagePath).Length / 1MB, 2)
    Write-Host "  📊 Size: $packageSize MB" -ForegroundColor Gray
    
}
finally {
    # Clean up temp directory
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force
    }
    Pop-Location
}

Write-Host ""
Write-Host "🎉 Package build completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Next steps:" -ForegroundColor Cyan
Write-Host "  1. Test the .pthm file by installing it in Playnite" -ForegroundColor White
Write-Host "  2. Commit your version changes to git" -ForegroundColor White
Write-Host "  3. Create a git tag: git tag v$Version" -ForegroundColor White
Write-Host "  4. Push to GitHub: git push origin v$Version" -ForegroundColor White
Write-Host "  5. The GitHub Actions workflow will create the release automatically" -ForegroundColor White
Write-Host ""

# Optionally open the output directory
if ($IsWindows) {
    $choice = Read-Host "Open output directory? (y/N)"
    if ($choice -eq 'y' -or $choice -eq 'Y') {
        Start-Process $OutputPath
    }
}