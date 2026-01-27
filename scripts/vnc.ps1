# .SYNOPSIS
#   Advanced TightVNC Server Automation Tool
# .DESCRIPTION
#   Sets Admin/Viewer passwords, IP Filtering, and applies Registry settings.

$TightVNC_Registry = "HKLM:\SOFTWARE\TightVNC\Server"

# Helper for TightVNC DES Password Encryption
function Get-VncEncryptedBytes {
    param([string]$password)
    
    $keyBytes = [byte[]](0x17, 0x52, 0x6B, 0x06, 0x23, 0x4E, 0x58, 0x07)
    $passBytes = [System.Text.Encoding]::ASCII.GetBytes($password.PadRight(8, "`0").Substring(0, 8))
    
    $des = [System.Security.Cryptography.DESCryptoServiceProvider]::Create()
    $des.Mode = [System.Security.Cryptography.CipherMode]::ECB
    $des.Padding = [System.Security.Cryptography.PaddingMode]::None
    $des.Key = $keyBytes
    
    $encryptor = $des.CreateEncryptor()
    $result = $encryptor.TransformFinalBlock($passBytes, 0, 8)
    return $result
}

function Set-TightVNCConfig {
    param(
        [string]$AdminPass = "afl@123",
        [string]$ViewerPass = "tgs#321",
        [string]$IPAccessStr = "192.168.1.1-192.168.1.254:0,174.156.5.1-174.156.5.254:0"
    )

    Write-Host "`n[ TRIVENI TIGHTVNC AUTOMATION ]" -ForegroundColor Cyan

    if (-not (Test-Path $TightVNC_Registry)) {
        New-Item -Path $TightVNC_Registry -Force | Out-Null
    }

    Write-Host "   Processing Passwords..." -ForegroundColor Yellow
    $AdminHash = Get-VncEncryptedBytes -password $AdminPass
    $ViewerHash = Get-VncEncryptedBytes -password $ViewerPass

    Write-Host "   Applying Registry Settings..." -ForegroundColor Yellow
    
    # Primary Password (Admin)
    Set-ItemProperty -Path $TightVNC_Registry -Name "Password" -Value $AdminHash -Type Binary -Force
    Set-ItemProperty -Path $TightVNC_Registry -Name "ControlPassword" -Value $AdminHash -Type Binary -Force
    
    # Read-Only Password (Viewer)
    Set-ItemProperty -Path $TightVNC_Registry -Name "PasswordViewOnly" -Value $ViewerHash -Type Binary -Force
    
    # IP Access Control
    # TightVNC 2.x uses AccessControlConfig as a string
    Set-ItemProperty -Path $TightVNC_Registry -Name "AccessControlConfig" -Value $IPAccessStr -Type String -Force
    
    # Standard Ports & Defaults
    Set-ItemProperty -Path $TightVNC_Registry -Name "RfbPort" -Value 5900 -Type DWord -Force
    Set-ItemProperty -Path $TightVNC_Registry -Name "AcceptPointerEvents" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $TightVNC_Registry -Name "AcceptKeyboardEvents" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $TightVNC_Registry -Name "AllowLoopback" -Value 1 -Type DWord -Force

    Write-Host "   Restarting VNC Service..." -ForegroundColor Cyan
    $Service = Get-Service -Name "tvnserver" -ErrorAction SilentlyContinue
    if ($Service) {
        Restart-Service -Name "tvnserver" -Force
        Write-Host "OK: VNC Security Configuration Applied Successfully." -ForegroundColor Green
    }
    else {
        Write-Host "WARN: tvnserver service not found. Settings saved (Registry)." -ForegroundColor Yellow
    }
}

# Run with User defined parameters
Set-TightVNCConfig
