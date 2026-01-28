# .SYNOPSIS
#   Lightshot Silent Installation Script
# .DESCRIPTION
#   Installs Lightshot silently and prevents the browser from opening the "Thank You" page.

$Installer = "setup-lightshot.exe"
$NasPaths = @(
    "\\174.156.4.3\fjt\Automations-Priyanshu\Basic sw",
    "\\174.156.4.3\fjt\Automations-Priyanshu",
    "\\174.156.4.3\fjt\Required softwares\Automation Software\Automations-Priyanshu\Basic sw"
)
$DownloadUrl = "https://app.prntscr.com/build/setup-lightshot.exe"

function Download-Or-Copy {
    param($FileName, $Sources, $Url)
    foreach ($Source in $Sources) {
        $NasFile = Join-Path $Source $FileName
        if (Test-Path $NasFile) {
            $Dest = Join-Path $env:TEMP $FileName
            Copy-Item -Path $NasFile -Destination $Dest -Force
            return $Dest
        }
    }
    $Dest = Join-Path $env:TEMP $FileName
    Invoke-WebRequest -Uri $Url -OutFile $Dest
    return $Dest
}

Write-Host ">>> Installing Lightshot Silently..." -ForegroundColor Cyan
$LocalPath = Download-Or-Copy -FileName $Installer -Sources $NasPaths -Url $DownloadUrl

# Run installer silently
Write-Host ">>> Starting Installer Process..." -ForegroundColor Cyan
$p = Start-Process -FilePath $LocalPath -ArgumentList "/VERYSILENT", "/NORESTART", "/SUPPRESSMSGBOXES", "/SP-" -PassThru

# Wait for installer to finish (max 2 seconds as requested)
$timeout = 2
$elapsed = 0
while (-not $p.HasExited -and $elapsed -lt $timeout) {
    Start-Sleep -Seconds 2
    $elapsed += 2
}

if (-not $p.HasExited) {
    Write-Host "WARN: Installer timed out, killing process." -ForegroundColor Yellow
    Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
}

# Cleanup browser popups and Lightshot auto-start
Write-Host ">>> Cleaning up popups..." -ForegroundColor Cyan
Start-Sleep -Seconds 3

# Kill browser pages with "Lightshot" in title and the Lightshot app itself if it started
$targets = @("Lightshot", "chrome", "msedge", "firefox", "iexplore")
foreach ($t in $targets) {
    Get-Process -Name $t -ErrorAction SilentlyContinue | Where-Object { 
        $_.MainWindowTitle -like "*Lightshot*" -or $_.Name -eq "Lightshot" 
    } | Stop-Process -Force -ErrorAction SilentlyContinue
}

Write-Host "✅ Lightshot installation sequence finished." -ForegroundColor Green
