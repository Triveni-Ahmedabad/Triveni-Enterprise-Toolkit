Param(
    [Parameter(Mandatory = $true)]
    [string]$NewVersion
)

$ErrorActionPreference = "Stop"

$Root = $PSScriptRoot
if ($Root -like "*scripts") { $Root = Split-Path $Root }

Write-Host ">>> Updating project version to: $NewVersion" -ForegroundColor Cyan

# 1. Update app.go
$AppGoPath = Join-Path $Root "app.go"
if (Test-Path $AppGoPath) {
    $content = Get-Content $AppGoPath -Raw
    $newContent = $content -replace 'Version:\s*".*?"(,|)', "Version: `"$NewVersion`","
    $newContent | Set-Content $AppGoPath
    Write-Host "   [DONE] app.go updated." -ForegroundColor Green
}

# 2. Update frontend/src/App.tsx
$AppTsxPath = Join-Path $Root "frontend\src\App.tsx"
if (Test-Path $AppTsxPath) {
    $content = Get-Content $AppTsxPath -Raw
    $newContent = $content -replace 'VERSION \d+\.\d+\.\d+', "VERSION $NewVersion"
    $newContent | Set-Content $AppTsxPath
    Write-Host "   [DONE] App.tsx updated." -ForegroundColor Green
}

# 3. Update wails.json (Add version if not exists)
$WailsJsonPath = Join-Path $Root "wails.json"
if (Test-Path $WailsJsonPath) {
    $json = Get-Content $WailsJsonPath | ConvertFrom-Json
    $json | Add-Member -MemberType NoteProperty -Name "version" -Value $NewVersion -Force
    $json | ConvertTo-Json -Depth 10 | Set-Content $WailsJsonPath
    Write-Host "   [DONE] wails.json updated." -ForegroundColor Green
}

# 4. Update local-build.bat
$BatPath = Join-Path $Root "local-build.bat"
if (Test-Path $BatPath) {
    $content = Get-Content $BatPath -Raw
    $newContent = $content -replace 'v\d+\.\d+\.\d+', "v$NewVersion"
    $newContent = $newContent -replace 'v1\.\d+\.\d+', "v$NewVersion"
    $newContent = $newContent -replace 'Enterprise-v\d+\.\d+\.\d+', "Enterprise-v$NewVersion"
    $newContent | Set-Content $BatPath
    Write-Host "   [DONE] local-build.bat updated." -ForegroundColor Green
}

Write-Host "`n✅ VERSION UPDATE COMPLETE!" -ForegroundColor Yellow
Write-Host "Next Step: git commit -m 'Bump version to $NewVersion' && git tag v$NewVersion" -ForegroundColor Gray
