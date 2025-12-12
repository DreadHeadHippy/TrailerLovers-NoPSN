# Simple theme packager for TrailerLovers-NoPSN
param([string]$Version = "latest")

$ProjectName = "TrailerLovers-NoPSN" 
$timestamp = Get-Date -Format "yyyy-MM-dd-HHmm"
$packageName = "$ProjectName-$timestamp.pthm"

Write-Host "🎮 Creating $packageName" -ForegroundColor Green

# Create releases folder
New-Item -Path "releases" -ItemType Directory -Force | Out-Null

# Create temp folder for packaging
$tempDir = "temp-package"
if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

# Copy theme files (exclude docs, scripts, etc)
$exclude = @(".git*", "*.md", "LICENSE", "temp-*", "scripts", ".github", "releases")
Get-ChildItem | Where-Object { 
    $name = $_.Name
    -not ($exclude | Where-Object { $name -like $_ })
} | Copy-Item -Destination $tempDir -Recurse -Force

# Create .pthm package (just a ZIP file)
$zipPath = "releases\$($packageName -replace '\.pthm$', '.zip')"
$packagePath = "releases\$packageName"
Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -Force
Move-Item $zipPath $packagePath -Force

# Cleanup
Remove-Item $tempDir -Recurse -Force

$size = [math]::Round((Get-Item $packagePath).Length / 1MB, 2)
Write-Host "✅ Created $packageName ($size MB)" -ForegroundColor Green
Write-Host "Location: $packagePath" -ForegroundColor Gray