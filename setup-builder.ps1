# Triveni Toolkit - Automated Build & Setup Script
# Usage: powershell -ExecutionPolicy Bypass -File setup-builder.ps1

$RepoUrl = "https://github.com/Triveni-Ahmedabad/Triveni-SysAdmin-Toolkit.git"
$ProjectDir = "Triveni-Control-Center"
$BuildDir = "Triveni-Build-Source"

Write-Host "`n[ TRIVENI AUTOMATED BUILD SYSTEM ]" -ForegroundColor Cyan

# 1. Dependency Check
Write-Host "Checking Dependencies..." -ForegroundColor Yellow
$deps = @{ "Go" = "go version"; "Node" = "node -v"; "Wails" = "wails version" }
foreach ($d in $deps.Keys) {
    try { Invoke-Expression $deps[$d] | Out-Null; Write-Host "  OK: $d found." -ForegroundColor Green }
    catch { Write-Host "  ERROR: $d is NOT installed! Please install $d first." -ForegroundColor Red; exit }
}

# 2. Clone/Update Source
if (Test-Path $BuildDir) {
    Write-Host "Updating source code..." -ForegroundColor Yellow
    Set-Location $BuildDir
    git pull origin main
}
else {
    Write-Host "Cloning repository..." -ForegroundColor Yellow
    git clone $RepoUrl $BuildDir
    Set-Location $BuildDir
}

# 3. Build Process
Set-Location $ProjectDir
Write-Host "Starting Wails Build (v1.13.0)..." -ForegroundColor Cyan
wails build -o Triveni-Enterprise-v1.13.0.exe

# 4. Packaging
Write-Host "Packaging Final Binaries..." -ForegroundColor Yellow
$BinDir = "build\bin"
if (Test-Path $BinDir) {
    copy config.json "$BinDir\"
    copy Triveni.png "$BinDir\"
    Write-Host "`nSUCCESS! Build ready in: $(Get-Location)\$BinDir" -ForegroundColor Green
    Write-Host "Executable: Triveni-Enterprise-v1.13.0.exe" -ForegroundColor White
}
