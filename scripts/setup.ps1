# .SYNOPSIS
#   Triveni Office Software Setup Toolkit (RabbitMQ & ElasticSearch)
# .DESCRIPTION
#   Automated installation and repair for RabbitMQ and ElasticSearch.

Param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("Install-RabbitMQ", "Install-ElasticSearch", "Uninstall-RabbitMQ", "Uninstall-ElasticSearch", "Get-RabbitMQStatus", "Get-ElasticSearchStatus", "Repair-ElasticSearch", "Test")]
    [string]$Action
)

# Force TLS 1.2 for all web requests
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# -------------------------------------------------------------------------
# CLI Parameter Support Handle
# -------------------------------------------------------------------------
if ($Action) {
    # We define functions later, so we need to be careful. 
    # Actually, in PS, functions must be defined before use if in a script.
    # So I will place the Action handling AFTER function definitions but BEFORE the menu loop.
}

# -------------------------------------------------------------------------
# Helper functions
# -------------------------------------------------------------------------
function Show-Header {
    Clear-Host
    $width = 70
    $line = "=" * $width
    
    Write-Host "`n  +$line+" -ForegroundColor Cyan
    Write-Host "  |   _____       _     _     _ _      _____ _           _   _          |" -ForegroundColor Magenta
    Write-Host "  |  |  __ \     | |   | |   (_) |    |  ___| |         | | (_)         |" -ForegroundColor Magenta
    Write-Host "  |  | |__) |__ _| |__ | |__  _| |_   | |__ | | __ _ ___| |_ _  ___      |" -ForegroundColor Cyan
    Write-Host "  |  |  _  // _' | '_ \| '_ \| | __|  |  __|| |/ _' / __| __| |/ __|     |" -ForegroundColor Cyan
    Write-Host "  |  | | \ \ (_| | |_) | |_) | | |_   | |___| | (_| \__ \ |_| | (__      |" -ForegroundColor Blue
    Write-Host "  |  |_|  \_\__,_|_.__/|_.__/|_|\__|  \____/|_|\__,_|___/\__|_|\___|     |" -ForegroundColor Blue
    Write-Host "  +$line+" -ForegroundColor Cyan
    Write-Host "  |" -NoNewline -ForegroundColor Cyan
    Write-Host "            Triveni Office Automation: RabbitMQ & Elastic           " -NoNewline -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host "|" -ForegroundColor Cyan
    Write-Host "  +$line+" -ForegroundColor Cyan
    Write-Host ""
}

function Download-Or-Copy-Ops {
    param($FileNames, $NasSources, $WebUrl)
    
    # $FileNames can be a single string or an array of possible names
    $FileList = @($FileNames)
    $SourceList = @($NasSources)
    
    foreach ($Source in $SourceList) {
        foreach ($Name in $FileList) {
            $NasFile = Join-Path $Source $Name
            $Dest = Join-Path $env:TEMP $Name
            
            Write-Host "   Checking: $NasFile ..." -ForegroundColor Gray
            if (Test-Path $NasFile) {
                Write-Host "   [MATCH] Found $Name on NAS ($Source). Copying..." -ForegroundColor Green
                try { 
                    Copy-Item -Path $NasFile -Destination $Dest -Force
                    return $Dest 
                }
                catch { 
                    Write-Host "   [ERROR] Failed to copy $Name from NAS: $($_.Exception.Message)" -ForegroundColor Red 
                }
            }
            else {
                Write-Host "   [MISSING] $Name not found at this location." -ForegroundColor DarkGray
            }
        }
    }
    
    # Web Fallback if NAS fails
    $PrimaryName = $FileList[0]
    $Dest = Join-Path $env:TEMP $PrimaryName
    Write-Host "   Downloading $PrimaryName from Web..." -ForegroundColor Yellow
    try { Invoke-WebRequest -Uri $WebUrl -OutFile $Dest; return $Dest }
    catch { throw "Failed to download $PrimaryName from web." }
}

# -------------------------------------------------------------------------
# RabbitMQ Functions
# -------------------------------------------------------------------------
function Install-RabbitMQ {
    Write-Host "`n [ RABBITMQ INSTALLATION ]" -ForegroundColor Cyan
    $ErrorActionPreference = "Stop"

    # Parameters
    $NasPaths = @(
        "\\174.156.4.3\fjt\Automations-Priyanshu\rabbitmq,elastic",
        "\\174.156.4.3\fjt\Automations-Priyanshu",
        "\\174.156.4.3\fjt\Required softwares\Automation Software\Automations-Priyanshu\rabbitmq,elastic",
        "\\174.156.4.3\fjt\Required softwares\Automation Software\Automations-Priyanshu"
    )

    $ErlangExe = "otp_win64_25.1.2.exe"
    $ErlangUrl = "https://github.com/erlang/otp/releases/download/OTP-25.1.2/otp_win64_25.1.2.exe"
    $RabbitExes = @("rabbitmq-server-3.11.3.exe", "RabbitMQ Latest.exe")
    $RabbitUrl = "https://github.com/rabbitmq/rabbitmq-server/releases/download/v3.11.3/rabbitmq-server-3.11.3.exe"
    $RabbitVersion = "3.11.3"
    try {
        # Check Exists
        $RabbitSbin = "C:\Program Files\RabbitMQ Server\rabbitmq_server-$RabbitVersion\sbin"
        if (Test-Path "$RabbitSbin\rabbitmqctl.bat" -ErrorAction SilentlyContinue) {
            Write-Host "OK: RabbitMQ detected. Skipping install steps." -ForegroundColor Green
        }
        else {
            Write-Host ">>> Getting Installers..." -ForegroundColor Yellow
            $LocalErlang = Download-Or-Copy-Ops $ErlangExe $NasPaths $ErlangUrl
            $LocalRabbit = Download-Or-Copy-Ops $RabbitExes $NasPaths $RabbitUrl

            Write-Host "RUN: Installing Erlang (Interactive)..." -ForegroundColor Yellow
            Write-Host "... Trying Silent Install..." -ForegroundColor Gray
            $erlProc = Start-Process -FilePath $LocalErlang -ArgumentList "/S" -Verb RunAs -PassThru -WindowStyle Hidden
            $erlProc.WaitForExit()
            if ($erlProc.ExitCode -ne 0) {
                Write-Host "WARN: Silent install failed. Opening interactive installer..." -ForegroundColor Yellow
                Start-Process -FilePath $LocalErlang -Verb RunAs -Wait
            }
            
            # ERLANG_HOME Fix
            $ErlangBase = "C:\Program Files"
            $ErlangDir = Get-ChildItem -Path $ErlangBase -Filter "erl*" -Directory | Sort-Object Name -Descending | Select-Object -First 1
            if ($ErlangDir) { 
                [System.Environment]::SetEnvironmentVariable("ERLANG_HOME", $ErlangDir.FullName, "Machine")
                $env:ERLANG_HOME = $ErlangDir.FullName
                Write-Host "   Set ERLANG_HOME (Persistent): $($ErlangDir.FullName)" -ForegroundColor Gray 
            }
            
            Write-Host "RUN: Installing RabbitMQ (Interactive)..." -ForegroundColor Yellow
            Write-Host "... Trying Silent Install..." -ForegroundColor Gray
            $rbProc = Start-Process -FilePath $LocalRabbit -ArgumentList "/S" -Verb RunAs -PassThru -WindowStyle Hidden
            $rbProc.WaitForExit()
            if ($rbProc.ExitCode -ne 0) {
                Write-Host "WARN: Silent install failed. Opening interactive installer..." -ForegroundColor Yellow
                Start-Process -FilePath $LocalRabbit -Verb RunAs -Wait
            }
        }

        # Path & Env
        if (Test-Path $RabbitSbin) {
            $CurrentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
            if ($CurrentPath -notlike "*$RabbitSbin*") {
                [Environment]::SetEnvironmentVariable("Path", "$CurrentPath;$RabbitSbin", "Machine")
                $env:Path += ";$RabbitSbin"
                Write-Host "   Added RabbitMQ to PATH." -ForegroundColor Gray
            }
        }

        # Plugins
        if (Test-Path "$RabbitSbin\rabbitmq-plugins.bat") {
            Write-Host "INFO: Enabling Plugins..." -ForegroundColor Cyan
            Push-Location $RabbitSbin
            & .\rabbitmq-plugins.bat enable rabbitmq_management
            & .\rabbitmq-plugins.bat enable rabbitmq_shovel
            & .\rabbitmq-plugins.bat enable rabbitmq_shovel_management
            Pop-Location
        }

        # Firewall
        Write-Host "SEC: Configuring Firewall..." -ForegroundColor Cyan
        $FirewallRules = @(@{Name = "RabbitMQ-AMQP"; Port = 5672 }, @{Name = "RabbitMQ-Mgmt"; Port = 15672 }, @{Name = "RabbitMQ-EPMD"; Port = 4369 }, @{Name = "RabbitMQ-Dist"; Port = 25672 })
        foreach ($Rule in $FirewallRules) {
            if (-not (Get-NetFirewallRule -DisplayName $Rule.Name -ErrorAction SilentlyContinue)) {
                New-NetFirewallRule -DisplayName $Rule.Name -Direction Inbound -LocalPort $Rule.Port -Protocol TCP -Action Allow | Out-Null
            }
        }

        # Admin User (Default: guest/guest)
        Write-Host "USER: Configuring Default User (guest/guest)..." -ForegroundColor Cyan
        $CtlPath = "$RabbitSbin\rabbitmqctl.bat"
        if (Test-Path $CtlPath) {
            Write-Host "   Waiting for RabbitMQ to start..." -ForegroundColor Gray
            Start-Sleep -Seconds 10
            
            # Ensure guest user exists and has correct password/tags/permissions
            Write-Host "   Setting password for 'guest'..." -ForegroundColor Gray
            & $CtlPath add_user guest guest 2>&1 | Out-Null
            & $CtlPath change_password guest guest 2>&1 | Out-Null
            
            Write-Host "   Setting administrator tags..." -ForegroundColor Gray
            & $CtlPath set_user_tags guest administrator 2>&1 | Out-Null
            
            Write-Host "   Setting full permissions..." -ForegroundColor Gray
            & $CtlPath set_permissions -p / guest ".*" ".*" ".*" 2>&1 | Out-Null
        }

        # Auto-Start
        Set-Service -Name "RabbitMQ" -StartupType Automatic -ErrorAction SilentlyContinue
        Write-Host "   Service Start Mode set to Automatic." -ForegroundColor Gray

        Write-Host "OK: RabbitMQ Setup Complete." -ForegroundColor Green
        
        # Verify Login
        Start-Sleep -Seconds 5
        Test-RabbitMQLogin
    }
    catch {
        Write-Host "ERROR: RabbitMQ Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Get-RabbitMQStatus {
    Write-Host "`n [ RABBITMQ STATUS CHECK ]" -ForegroundColor Cyan
    $service = Get-Service -Name "RabbitMQ" -ErrorAction SilentlyContinue
    if ($service) {
        $statusColor = if ($service.Status -eq 'Running') { "Green" } else { "Red" }
        Write-Host "   Service: " -NoNewline
        Write-Host "$($service.Status)" -ForegroundColor $statusColor
    }
    else {
        Write-Host "   Service: " -NoNewline
        Write-Host "Not Installed / Not Found" -ForegroundColor Red
    }

    Write-Host "`n   Checking Ports:" -ForegroundColor Gray
    $ports = @(
        @{ Port = 5672; Name = "AMQP" },
        @{ Port = 15672; Name = "Management" },
        @{ Port = 4369; Name = "Erlang Mapper" },
        @{ Port = 25672; Name = "Distribution" }
    )

    foreach ($p in $ports) {
        $msg = "   - Port $($p.Port) ($($p.Name))..."
        if ($msg.Length -lt 40) { $msg = $msg + " " * (40 - $msg.Length) }
        Write-Host $msg -NoNewline -ForegroundColor Gray
        if (Get-NetTCPConnection -LocalPort $p.Port -State Listen -ErrorAction SilentlyContinue) {
            Write-Host "OK: LISTENING" -ForegroundColor Green
        }
        else {
            Write-Host "ERROR: CLOSED / UNUSED" -ForegroundColor DarkGray
        }
    }
    
    if ($service.Status -eq 'Running') {
        Test-RabbitMQLogin
    }
    Write-Host ""
}

function Test-RabbitMQLogin {
    param(
        $User = "guest",
        $Pass = "guest",
        $Port = 15672
    )
    
    Write-Host "`n KEY: Testing Management API Login ($User)..." -ForegroundColor Cyan
    $Url = "http://localhost:$Port/api/whoami"
    $Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($User):$($Pass)"))
    $Headers = @{ Authorization = "Basic $Auth" }
    
    try {
        $Response = Invoke-RestMethod -Uri $Url -Headers $Headers -Method Get -TimeoutSec 5 -ErrorAction Stop
        if ($Response.name -eq $User) {
            Write-Host "   OK: Login Successful! User: $($Response.name), Tags: $($Response.tags)" -ForegroundColor Green
            return $true
        }
    }
    catch {
        Write-Host "   ERROR: Login Failed: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.Message -like "*401*") {
            Write-Host "      (Tip: Invalid credentials or user does not exist)" -ForegroundColor Yellow
        }
        elseif ($_.Exception.Message -like "*Unable to connect*") {
            Write-Host "      (Tip: Management plugin might not be fully started yet)" -ForegroundColor Yellow
        }
    }
    return $false
}

function Repair-RabbitMQ {
    Write-Host "`n [ REPAIRING RABBITMQ ]" -ForegroundColor Yellow
    $ErrorActionPreference = "SilentlyContinue"
    $RabbitVersion = "3.11.3"
    $RabbitSbin = "C:\Program Files\RabbitMQ Server\rabbitmq_server-$RabbitVersion\sbin"

    if (-not (Test-Path $RabbitSbin)) {
        Write-Host "   ERROR: RabbitMQ sbin directory not found at: $RabbitSbin" -ForegroundColor Red
        return
    }

    if (Test-Path "$RabbitSbin\rabbitmq-plugins.bat") {
        Write-Host "INFO: Re-enabling Plugins..." -ForegroundColor Cyan
        Push-Location $RabbitSbin
        & .\rabbitmq-plugins.bat enable rabbitmq_management
        & .\rabbitmq-plugins.bat enable rabbitmq_shovel
        & .\rabbitmq-plugins.bat enable rabbitmq_shovel_management
        Pop-Location
    }

    Write-Host "SEC: Refreshing Firewall Rules..." -ForegroundColor Cyan
    $FirewallRules = @(@{Name = "RabbitMQ-AMQP"; Port = 5672 }, @{Name = "RabbitMQ-Mgmt"; Port = 15672 }, @{Name = "RabbitMQ-EPMD"; Port = 4369 }, @{Name = "RabbitMQ-Dist"; Port = 25672 })
    foreach ($Rule in $FirewallRules) {
        if (-not (Get-NetFirewallRule -DisplayName $Rule.Name -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule -DisplayName $Rule.Name -Direction Inbound -LocalPort $Rule.Port -Protocol TCP -Action Allow | Out-Null
        }
    }

    Write-Host "USER: Resetting Default User (guest/guest)..." -ForegroundColor Cyan
    $CtlPath = "$RabbitSbin\rabbitmqctl.bat"
    if (Test-Path $CtlPath) {
        Write-Host "   Stopping app for reset..." -ForegroundColor Gray
        & $CtlPath stop_app 2>&1 | Out-Null
        
        Write-Host "   Resetting 'guest' user..." -ForegroundColor Gray
        & $CtlPath delete_user guest 2>&1 | Out-Null
        & $CtlPath add_user guest guest 2>&1 | Out-Null
        & $CtlPath set_user_tags guest administrator 2>&1 | Out-Null
        & $CtlPath set_permissions -p / guest ".*" ".*" ".*" 2>&1 | Out-Null
        
        Write-Host "   Starting app..." -ForegroundColor Gray
        & $CtlPath start_app 2>&1 | Out-Null
    }

    Write-Host "RUN: Restarting RabbitMQ Service..." -ForegroundColor Cyan
    $service = Get-Service -Name "RabbitMQ" -ErrorAction SilentlyContinue
    if ($service) {
        Set-Service -Name "RabbitMQ" -StartupType Automatic
        Restart-Service -Name "RabbitMQ" -Force
        Write-Host "OK: Service Restarted and Set to Automatic." -ForegroundColor Green
        
        # Verify Login
        Start-Sleep -Seconds 10
        Test-RabbitMQLogin
    }
}

# -------------------------------------------------------------------------
# ElasticSearch Functions
# -------------------------------------------------------------------------
function Install-ElasticSearch {
    Write-Host "`n [ ELASTICSEARCH INSTALLATION ]" -ForegroundColor Cyan
    $ErrorActionPreference = "Stop"

    $ElasticVersion = "8.11.1"
    $ZipName = "elasticsearch-8.11.1-windows-x86_64.zip"
    $NasPaths = @(
        "\\174.156.4.3\fjt\Automations-Priyanshu\rabbitmq,elastic",
        "\\174.156.4.3\fjt\Automations-Priyanshu",
        "\\174.156.4.3\fjt\Required softwares\Automation Software\Automations-Priyanshu\rabbitmq,elastic",
        "\\174.156.4.3\fjt\Required softwares\Automation Software\Automations-Priyanshu"
    )
    $WebUrl = "https://artifacts.elastic.co/downloads/elasticsearch/$ZipName"
    
    $InstallDirRoot = "C:\Program Files\Elastic\Elasticsearch"
    $ElasticInstallDir = "$InstallDirRoot\$ElasticVersion"
    $ProgramDataDir = "C:\ProgramData\Elastic\Elasticsearch"
    $JavaHome = "C:\Program Files\Java\jdk-17"
    $NetworkJdkPaths = @(
        "\\174.156.4.3\fjt\Automations-Priyanshu\rabbitmq,elastic\jdk-17.0.6_windows-x64_bin.exe",
        "\\174.156.4.3\fjt\Automations-Priyanshu\jdk-17.0.6_windows-x64_bin.exe",
        "\\174.156.4.3\fjt\Required softwares\Update - Dev System\jdk-17.0.6_windows-x64_bin.exe",
        "\\174.156.4.3\fjt\Required softwares\Automation Software\Automations-Priyanshu\rabbitmq,elastic\jdk-17.0.6_windows-x64_bin.exe"
    )

    try {
        if (Test-Path "$ElasticInstallDir\bin\elasticsearch-service.bat") {
            Write-Host "OK: ElasticSearch detected. Skipping install." -ForegroundColor Green
        }
        else {
            if (-not (Test-Path $InstallDirRoot)) { New-Item -Path $InstallDirRoot -ItemType Directory -Force | Out-Null }
            $LocalZipPath = Join-Path $env:TEMP $ZipName
            $FileReady = $false

            foreach ($NasPath in $NasPaths) {
                $NasZipPath = Join-Path $NasPath $ZipName
                if (Test-Path $NasZipPath) {
                    Write-Host "   Found ZIP on NAS ($NasPath). Copying..." -ForegroundColor Green
                    try { 
                        Copy-Item -Path $NasZipPath -Destination $LocalZipPath -Force
                        $FileReady = $true
                        break
                    }
                    catch {
                        Write-Host "   Failed to copy from NAS ($NasPath): $($_.Exception.Message)" -ForegroundColor Yellow
                    }
                }
            }

            if (-not $FileReady) {
                Write-Host "   INFO: Downloading ZIP from Web..." -ForegroundColor Yellow
                Invoke-WebRequest -Uri $WebUrl -OutFile $LocalZipPath
            }

            Write-Host "UNZIP: Extracting..." -ForegroundColor Yellow
            Expand-Archive -Path $LocalZipPath -DestinationPath $InstallDirRoot -Force
            $ExtractedFolder = "$InstallDirRoot\elasticsearch-$ElasticVersion"
            if (Test-Path $ExtractedFolder) { Rename-Item -Path $ExtractedFolder -NewName $ElasticVersion }
        }

        if (-not (Test-Path "$JavaHome\bin\java.exe")) {
            Write-Host "JDK: Installing JDK (Interactive)..." -ForegroundColor Yellow
            $LocalJdkPath = "$env:TEMP\jdk-17-installer.exe"
            $JdkReady = $false
            foreach ($NetPath in $NetworkJdkPaths) {
                if (Test-Path $NetPath) {
                    Write-Host "   Found JDK on NAS ($NetPath). Copying..." -ForegroundColor Green
                    try { 
                        Copy-Item -Path $NetPath -Destination $LocalJdkPath -Force
                        $JdkReady = $true
                        break
                    }
                    catch {}
                }
            }
            if ($JdkReady) { Start-Process -FilePath $LocalJdkPath -Wait }
            else { 
                Write-Host "   WARN: JDK not found on NAS. Skipping JDK install." -ForegroundColor Red 
            }
        }

        [System.Environment]::SetEnvironmentVariable("JAVA_HOME", $null, "User")
        [System.Environment]::SetEnvironmentVariable("ES_JAVA_HOME", $JavaHome, "Machine")
        [System.Environment]::SetEnvironmentVariable("ES_HOME", $ElasticInstallDir, "Machine")
        [System.Environment]::SetEnvironmentVariable("ES_PATH_CONF", "$ProgramDataDir\config", "Machine")
        [System.Environment]::SetEnvironmentVariable("ELASTIC_CLIENT_APIVERSIONING", "true", "Machine")

        Write-Host "SET: Configuring..." -ForegroundColor Cyan
        New-Item -Path "$ProgramDataDir\config" -ItemType Directory -Force | Out-Null
        New-Item -Path "$ProgramDataDir\data" -ItemType Directory -Force | Out-Null
        New-Item -Path "$ProgramDataDir\logs" -ItemType Directory -Force | Out-Null

        $SourceConfig = "$ElasticInstallDir\config"
        if (Test-Path "$SourceConfig\elasticsearch.yml") { Copy-Item -Path "$SourceConfig\*" -Destination "$ProgramDataDir\config" -Recurse -Force }

        $ConfigContent = @"
bootstrap.memory_lock: false
cluster.name : elasticsearch
http.port: 9200
node.attr.data: true
node.name : $env:COMPUTERNAME
path.data: C:\ProgramData\Elastic\Elasticsearch\data
path.logs: C:\ProgramData\Elastic\Elasticsearch\logs
path.repo: C:\ProgramData\Elastic\Elasticsearch\backup
transport.port: 9300
xpack.license.self_generated.type: basic
xpack.security.enabled: true
action.auto_create_index: .monitoring*,.watches,.triggered_watches,.watcher-history*,.ml*
"@
        $ConfigContent | Set-Content -Path "$ProgramDataDir\config\elasticsearch.yml"
        if (Test-Path "$ProgramDataDir\config\jvm.options") { Copy-Item -Path "$ProgramDataDir\config\jvm.options" -Destination "$ProgramDataDir\config\jvm.options.d" -Force }

        $FwRules = @(@{Name = "ElasticSearch-HTTP"; Port = 9200 }, @{Name = "ElasticSearch-Trans"; Port = 9300 })
        foreach ($Rule in $FwRules) {
            if (-not (Get-NetFirewallRule -DisplayName $Rule.Name -ErrorAction SilentlyContinue)) {
                New-NetFirewallRule -DisplayName $Rule.Name -Direction Inbound -LocalPort $Rule.Port -Protocol TCP -Action Allow | Out-Null
            }
        }

        $ServiceBat = "$ElasticInstallDir\bin\elasticsearch-service.bat"
        $EsService = Get-Service "elasticsearch" -ErrorAction SilentlyContinue
        if (-not $EsService) {
            if (Test-Path $ServiceBat) { 
                Start-Process -FilePath $ServiceBat -ArgumentList "install elasticsearch" -Wait
                Set-Service -Name "elasticsearch" -StartupType Automatic
                Start-Service "elasticsearch" 
            }
        }
        else { 
            Set-Service -Name "elasticsearch" -StartupType Automatic
            if ($EsService.Status -ne "Running") { Start-Service "elasticsearch" } 
        }
        
        Write-Host "USER: Setting Up Admin (tgs@123)..." -ForegroundColor Cyan
        Start-Sleep -Seconds 15
        
        $UsersTool = "$ElasticInstallDir\bin\elasticsearch-users.bat"
        if (Test-Path $UsersTool) {
            $P = Start-Process -FilePath $UsersTool -ArgumentList "useradd admin -p tgs@123 -r superuser" -Wait -PassThru -NoNewWindow
            if ($P.ExitCode -ne 0) { Start-Process -FilePath $UsersTool -ArgumentList "passwd admin -p tgs@123" -Wait -NoNewWindow }
        }

        Write-Host "OK: ElasticSearch Setup Complete. Login: admin/tgs@123" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ ElasticSearch Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Repair-ElasticSearch {
    Write-Host "`n [ REPAIRING ELASTICSEARCH ]" -ForegroundColor Yellow
    $ErrorActionPreference = "SilentlyContinue"
    $ElasticVersion = "8.11.1"
    $InstallDirRoot = "C:\Program Files\Elastic\Elasticsearch"
    $ElasticInstallDir = "$InstallDirRoot\$ElasticVersion"
    $UsersTool = "$ElasticInstallDir\bin\elasticsearch-users.bat"

    if (-not (Test-Path $UsersTool)) {
        Write-Host "❌ ElasticSearch tool not found at: $UsersTool" -ForegroundColor Red
        return
    }

    Write-Host "USER: Resetting Admin User (admin/tgs@123)..." -ForegroundColor Cyan
    $P = Start-Process -FilePath $UsersTool -ArgumentList "useradd admin -p tgs@123 -r superuser" -Wait -PassThru -NoNewWindow
    if ($P.ExitCode -ne 0) {
        Start-Process -FilePath $UsersTool -ArgumentList "passwd admin -p tgs@123" -Wait -NoNewWindow
    }

    $FwRules = @(@{Name = "ElasticSearch-HTTP"; Port = 9200 }, @{Name = "ElasticSearch-Trans"; Port = 9300 })
    foreach ($Rule in $FwRules) {
        if (-not (Get-NetFirewallRule -DisplayName $Rule.Name -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule -DisplayName $Rule.Name -Direction Inbound -LocalPort $Rule.Port -Protocol TCP -Action Allow | Out-Null
        }
    }

    $service = Get-Service -Name "elasticsearch" -ErrorAction SilentlyContinue
    if ($service) {
        Set-Service -Name "elasticsearch" -StartupType Automatic
        Restart-Service -Name "elasticsearch" -Force
        Write-Host "OK: Service Restarted and Set to Automatic." -ForegroundColor Green
    }
}

function Get-ElasticSearchStatus {
    Write-Host "`n[ ELASTICSEARCH STATUS CHECK ]" -ForegroundColor Cyan
    $EsService = Get-Service "elasticsearch" -ErrorAction SilentlyContinue
    if ($EsService) {
        $statusColor = if ($EsService.Status -eq 'Running') { "Green" } else { "Red" }
        Write-Host "   Service: " -NoNewline
        Write-Host "$($EsService.Status)" -ForegroundColor $statusColor
        
        Write-Host "   Checking Port 9200 (HTTP)..." -NoNewline -ForegroundColor Gray
        if (Get-NetTCPConnection -LocalPort 9200 -State Listen -ErrorAction SilentlyContinue) {
            Write-Host " OK: LISTENING" -ForegroundColor Green
        }
        else {
            Write-Host " ERROR: CLOSED" -ForegroundColor Red
        }
    }
    else {
        Write-Host "   Service: " -NoNewline
        Write-Host "Not Installed / Not Found" -ForegroundColor Red
    }
}

# -------------------------------------------------------------------------
# Uninstall System
# -------------------------------------------------------------------------
# -------------------------------------------------------------------------
# Uninstall System
# -------------------------------------------------------------------------
function Uninstall-ElasticSearch {
    param($Silent = $false)
    if (-not $Silent) {
        Write-Host "`n [ UNINSTALL ELASTICSEARCH ]" -ForegroundColor Red
        $confirm = Read-Host " Are you sure? (Type 'YES' to confirm)"
        if ($confirm -ne 'YES') { return }
    }

    $ErrorActionPreference = "SilentlyContinue"
    Write-Host "`nREMOVE: Removing ElasticSearch..." -ForegroundColor Cyan
    
    $EsService = Get-Service "elasticsearch" -ErrorAction SilentlyContinue
    if ($EsService) {
        Write-Host "   Stopping service..." -ForegroundColor Gray
        Stop-Service "elasticsearch" -Force
        
        $EsPath = [System.Environment]::GetEnvironmentVariable("ES_HOME", "Machine")
        if ($EsPath -and (Test-Path "$EsPath\bin\elasticsearch-service.bat")) {
            Write-Host "   Running service uninstaller..." -ForegroundColor Gray
            & "$EsPath\bin\elasticsearch-service.bat" remove elasticsearch | Out-Null
        }
    }
    
    Write-Host "   Cleaning folders & registry..." -ForegroundColor Gray
    $EsFolders = @("C:\Program Files\Elastic", "C:\ProgramData\Elastic")
    foreach ($f in $EsFolders) { if (Test-Path $f) { Remove-Item -Path $f -Recurse -Force } }
    
    $EsEnv = @("ES_JAVA_HOME", "ES_HOME", "ES_PATH_CONF", "ELASTIC_CLIENT_APIVERSIONING")
    foreach ($e in $EsEnv) { [System.Environment]::SetEnvironmentVariable($e, $null, "Machine") }
    
    Get-NetFirewallRule -DisplayName "ElasticSearch-*" | Remove-NetFirewallRule
    
    Get-ChildItem $env:TEMP -Filter "elasticsearch-*.zip" | Remove-Item -Force
    
    Write-Host "OK: ElasticSearch removed." -ForegroundColor Green
    if (-not $Silent) { Pause }
}

function Uninstall-RabbitMQ {
    param($Silent = $false)
    if (-not $Silent) {
        Write-Host "`n [ UNINSTALL RABBITMQ & ERLANG ]" -ForegroundColor Red
        $confirm = Read-Host " Are you sure? (Type 'YES' to confirm)"
        if ($confirm -ne 'YES') { return }
    }

    $ErrorActionPreference = "SilentlyContinue"
    
    # 1. RabbitMQ
    Write-Host "`nREMOVE: Removing RabbitMQ..." -ForegroundColor Cyan
    $RbService = Get-Service "RabbitMQ" -ErrorAction SilentlyContinue
    if ($RbService) {
        Write-Host "   Stopping service..." -ForegroundColor Gray
        Stop-Service "RabbitMQ" -Force
        
        $uninstaller = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | 
        Where-Object { $_.GetValue("DisplayName") -like "*RabbitMQ Server*" } | 
        Select-Object -First 1
        if ($uninstaller) {
            $uninstallString = $uninstaller.GetValue("UninstallString")
            if ($uninstallString) {
                Write-Host "   Launching RabbitMQ Uninstaller..." -ForegroundColor Gray
                Start-Process -FilePath $uninstallString -ArgumentList "/S" -Wait
            }
        }
    }
    
    Write-Host "   Cleaning folders & Path..." -ForegroundColor Gray
    $RbFolders = @("C:\Program Files\RabbitMQ Server", "$env:AppData\RabbitMQ", "$env:AppData\RabbitMQ Server")
    foreach ($f in $RbFolders) { if (Test-Path $f) { Remove-Item -Path $f -Recurse -Force } }
    
    $path = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($path -like "*RabbitMQ Server*") {
        $newPath = ($path -split ';' | Where-Object { $_ -notlike "*RabbitMQ Server*" }) -join ';'
        [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
        $env:Path = $newPath
    }
    Get-NetFirewallRule -DisplayName "RabbitMQ-*" | Remove-NetFirewallRule

    # 2. Erlang
    Write-Host "`nREMOVE: Removing Erlang OTP..." -ForegroundColor Cyan
    $erlUninstaller = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | 
    Where-Object { $_.GetValue("DisplayName") -like "*Erlang OTP*" } | 
    Select-Object -First 1
    if ($erlUninstaller) {
        $uninstallString = $erlUninstaller.GetValue("UninstallString")
        if ($uninstallString) {
            Write-Host "   Launching Erlang Uninstaller..." -ForegroundColor Gray
            Start-Process -FilePath $uninstallString -ArgumentList "/S" -Wait
        }
    }
    
    $erlFolders = Get-ChildItem "C:\Program Files" -Filter "erl*" | Select-Object -ExpandProperty FullName
    foreach ($f in $erlFolders) { Remove-Item -Path $f -Recurse -Force }
    [System.Environment]::SetEnvironmentVariable("ERLANG_HOME", $null, "Machine")

    Get-ChildItem $env:TEMP -Filter "otp_win64_*.exe" | Remove-Item -Force
    Get-ChildItem $env:TEMP -Filter "rabbitmq-server-*.exe" | Remove-Item -Force

    Write-Host "OK: RabbitMQ and Erlang removed." -ForegroundColor Green
    if (-not $Silent) { Pause }
}

function Uninstall-Everything {
    Write-Host "`n [ COMPLETE UNINSTALLATION ]" -ForegroundColor Red -BackgroundColor Black
    Write-Host "WARN: This will remove EVERYTHING (Rabbit, Erlang, Elastic)." -ForegroundColor Yellow
    $confirm = Read-Host "`n Type 'YES' to confirm"
    if ($confirm -ne 'YES') { return }

    Uninstall-RabbitMQ -Silent $true
    Uninstall-ElasticSearch -Silent $true

    Write-Host "`n*** SYSTEM CLEANED! ***" -ForegroundColor Green
    Pause
}

# -------------------------------------------------------------------------
# CLI Parameter Support
# -------------------------------------------------------------------------
if ($Action) {
    Show-Header
    switch ($Action) {
        "Install-RabbitMQ" { Install-RabbitMQ }
        "Install-ElasticSearch" { Install-ElasticSearch }
        "Uninstall-RabbitMQ" { Uninstall-RabbitMQ -Silent $true }
        "Uninstall-ElasticSearch" { Uninstall-ElasticSearch -Silent $true }
        "Get-RabbitMQStatus" { Get-RabbitMQStatus }
        "Get-ElasticSearchStatus" { Get-ElasticSearchStatus }
        "Repair-ElasticSearch" { Repair-ElasticSearch }
        "Test" { 
            Write-Host "`n[ RUNNING DIAGNOSTICS ]" -ForegroundColor Yellow
            Get-RabbitMQStatus
            Get-ElasticSearchStatus
        }
    }
    Write-Host "`n[ FINISHED ] - Press any key to close..." -ForegroundColor Gray
    $null = [System.Console]::ReadKey()
    exit
}

# --- Original Menu Loop ---
while ($true) {
    Show-Header
    Write-Host "   [ INSTALLATION ]" -ForegroundColor Yellow
    Write-Host "   [1] Install RabbitMQ"
    Write-Host "   [2] Install ElasticSearch"
    
    Write-Host "`n   [ MAINTENANCE ]" -ForegroundColor Yellow
    Write-Host "   [3] Check RabbitMQ Status"
    Write-Host "   [4] Repair RabbitMQ (Reset User/Firewall)"
    Write-Host "   [5] Repair ElasticSearch (Reset Admin/Firewall)"
    
    Write-Host "`n   [ UNINSTALLATION ]" -ForegroundColor Yellow
    Write-Host "   [6] Uninstall RabbitMQ & Erlang" -ForegroundColor Red
    Write-Host "   [7] Uninstall ElasticSearch" -ForegroundColor Red
    Write-Host "   [8] COMPLETE UNINSTALL (Remove All)" -ForegroundColor Red
    
    Write-Host "`n   [Q] Quit"
    Write-Host ""
    
    $choice = Read-Host "   Select an option"
    
    switch ($choice) {
        "1" { Install-RabbitMQ }
        "2" { Install-ElasticSearch }
        "3" { Get-RabbitMQStatus }
        "4" { Repair-RabbitMQ }
        "5" { Repair-ElasticSearch }
        "6" { Uninstall-RabbitMQ }
        "7" { Uninstall-ElasticSearch }
        "8" { Uninstall-Everything }
        "q" { exit }
        "Q" { exit }
        default { Write-Host "Invalid choice!" -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
    
    if ($choice -match '^[1-5]$') {
        Write-Host "`n Press Enter to continue..." -ForegroundColor Yellow
        $null = Read-Host
    }
}
