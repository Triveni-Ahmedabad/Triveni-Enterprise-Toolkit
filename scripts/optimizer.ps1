Param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("TestRAM", "InstallService", "StopCaching", "UltimateCPU", "VisualsOff", "AnimsOff", "Restore")]
    [string]$Action
)

# --- C# UTILITIES For MEMORY CONTROL ---
if (-not ("MemoryCleaner" -as [type])) {
    $code = @"
using System; using System.Runtime.InteropServices; using System.Diagnostics;
public class MemoryCleaner {
    [DllImport("psapi.dll")] public static extern bool EmptyWorkingSet(IntPtr hProcess);
    [DllImport("ntdll.dll")] public static extern int NtSetSystemInformation(int InfoClass, IntPtr Info, int Length);
    public static void TrimProcess(int pid) { try { Process p = Process.GetProcessById(pid); EmptyWorkingSet(p.Handle); } catch { } }
    public static void FlushStandbyList() {
        try {
            int sysInfoClass = 80; int command = 4; int size = Marshal.SizeOf(command);
            IntPtr p = Marshal.AllocHGlobal(size);
            Marshal.WriteInt32(p, command);
            NtSetSystemInformation(sysInfoClass, p, size);
            Marshal.FreeHGlobal(p);
        } catch {}
    }
}
"@
    Add-Type -TypeDefinition $code
}

$Exclusions = @("Idle", "System", "Registry", "smss", "csrss", "wininit", "services", "lsass", "winlogon", "fontdrvhost", "dwm", "Memory Compression", "MsMpEng", "taskmgr")

switch ($Action) {
    "TestRAM" {
        Write-Host "=== LIVE RAM OPTIMIZER TEST ===" -ForegroundColor Green
        Write-Host "Trimming processes > 100MB and lowering CPU priority..." -ForegroundColor Cyan
        while ($true) {
            $total = 0
            $targets = Get-Process -EA SilentlyContinue | Where-Object { $_.WorkingSet -gt 100MB -and $_.ProcessName -notin $Exclusions }
            foreach ($p in $targets) {
                [MemoryCleaner]::TrimProcess($p.Id)
                try { if ($p.PriorityClass -eq "Normal") { $p.PriorityClass = "BelowNormal" } } catch {}
            }
            Start-Sleep -Seconds 3
        }
    }
    "InstallService" {
        $InstallDir = "C:\ProgramData\TGS_System_Booster"
        if (!(Test-Path $InstallDir)) { New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null }
        $AgentScript = "$InstallDir\TGS_Booster_SVC.ps1"
        
        $ScriptBody = @"
        while (`$true) {
            try {
                `$targets = Get-Process -EA SilentlyContinue | Where-Object { `$_.WorkingSet -gt 100MB -and `$_.ProcessName -notin @('Idle','System','Registry','smss','csrss','wininit','services','lsass','winlogon','fontdrvhost','dwm','Memory Compression','MsMpEng') }
                foreach (`$p in `$targets) { [MemoryCleaner]::TrimProcess(`$p.Id); try { if (`$p.PriorityClass -eq 'Normal') { `$p.PriorityClass = 'BelowNormal' } } catch {} }
            } catch {}
            Start-Sleep -Seconds 10
        }
"@
        # Re-include the C# class in the service script
        $FullScript = "Add-Type -TypeDefinition `"$code`"`n" + $ScriptBody
        $FullScript | Set-Content $AgentScript -Force

        $TaskName = "TGS_Booster_Service"
        $ActionCmd = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$AgentScript`""
        $Trigger = New-ScheduledTaskTrigger -AtLogon
        $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Days 365) -Priority 1
        $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

        Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
        Register-ScheduledTask -TaskName $TaskName -Action $ActionCmd -Trigger $Trigger -Principal $Principal -Settings $Settings -Description "TGS Global RAM Optimizer" | Out-Null
        Start-ScheduledTask -TaskName $TaskName
        Write-Host "SUCCESS: Permanent service installed and started."
    }
    "StopCaching" {
        Set-Service -Name "SysMain" -StartupType Disabled -Status Stopped -ErrorAction SilentlyContinue
        Write-Host "SUCCESS: SysMain (Superfetch) disabled."
    }
    "UltimateCPU" {
        cmd /c "powercfg /s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
        cmd /c "powercfg -setacvalueindex scheme_current sub_processor 0cc5b647-c1df-4637-891a-dec35c318583 100"
        cmd /c "powercfg -setdcvalueindex scheme_current sub_processor 0cc5b647-c1df-4637-891a-dec35c318583 100"
        cmd /c "powercfg -setactive scheme_current"
        Write-Host "SUCCESS: Ultimate CPU performance enabled."
    }
    "VisualsOff" {
        $k = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        if (Test-Path $k) { Set-ItemProperty $k "EnableTransparency" 0 -Type DWord -Force }
        Write-Host "SUCCESS: Transparency disabled."
    }
    "AnimsOff" {
        $k1 = "HKCU:\Control Panel\Desktop\WindowMetrics"; if (Test-Path $k1) { Set-ItemProperty $k1 "MinAnimate" "0" -Type String -Force }
        $k2 = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"; if (Test-Path $k2) { Set-ItemProperty $k2 "VisualFXSetting" 2 -Type DWord -Force }
        $k3 = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; if (Test-Path $k3) { Set-ItemProperty $k3 "TaskbarAnimations" 0 -Type DWord -Force }
        Write-Host "SUCCESS: Animations disabled. Restart required for full effect."
    }
    "Restore" {
        Set-Service -Name "SysMain" -StartupType Automatic -Status Running -ErrorAction SilentlyContinue
        cmd /c "powercfg /s 381b4222-f694-41f0-9685-ff5bb260df2e"
        $k = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"; if (Test-Path $k) { Set-ItemProperty $k "EnableTransparency" 1 -Type DWord -Force }
        $k1 = "HKCU:\Control Panel\Desktop\WindowMetrics"; if (Test-Path $k1) { Set-ItemProperty $k1 "MinAnimate" "1" -Type String -Force }
        $k2 = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"; if (Test-Path $k2) { Set-ItemProperty $k2 "VisualFXSetting" 1 -Type DWord -Force }
        $k3 = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; if (Test-Path $k3) { Set-ItemProperty $k3 "TaskbarAnimations" 1 -Type DWord -Force }
        Write-Host "SUCCESS: System defaults restored."
    }
}
