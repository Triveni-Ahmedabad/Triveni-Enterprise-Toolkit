package main

import (
	"context"
	"embed"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"syscall"
)

//go:embed scripts/*
var embeddedScripts embed.FS

// App struct
type App struct {
	ctx     context.Context
	Version string
}

func NewApp() *App {
	return &App{
		Version: "1.14.2",
	}
}

func (a *App) startup(ctx context.Context) {
	a.ctx = ctx
}

// --- Data Structures ---

type Config struct {
	NasBasePath  string     `json:"nas_base_path"`
	SoftwareList []Software `json:"software_list"`
}

type Software struct {
	Name          string   `json:"name"`
	NasPath       string   `json:"nas_path"`
	DownloadUrl   string   `json:"download_url"`
	InstallArgs   []string `json:"install_args"`
	Description   string   `json:"description"`
	Category      string   `json:"category"`
	SubCategory   string   `json:"sub_category"`
	UninstallArgs []string `json:"uninstall_args"`
	IsInstalled   bool     `json:"is_installed"`
	Interactive   bool     `json:"interactive"`
	Version       string   `json:"version"`
	TestArgs      []string `json:"test_args"`
	IsEmbedded    bool     `json:"is_embedded"`
}

type HardwareInfo struct {
	CPU      string `json:"cpu"`
	RAM      string `json:"ram"`
	OS       string `json:"os"`
	Hostname string `json:"hostname"`
	IP       string `json:"ip"`
	Disk     string `json:"disk"`
}

func isSoftwareInstalled(name string) bool {
	// Map of software names to their common installation files (exe)
	softwareFiles := map[string][]string{
		"Google Chrome":   {"Google\\Chrome\\Application\\chrome.exe"},
		"7-Zip":           {"7-Zip\\7zFM.exe", "7-Zip\\7z.exe"},
		"WinRAR":          {"WinRAR\\WinRAR.exe"},
		"Notepad++":       {"Notepad++\\notepad++.exe"},
		"VS Code":         {"Microsoft VS Code\\Code.exe"},
		"VLC Media":       {"VideoLAN\\VLC\\vlc.exe"},
		"Lightshot":       {"Skillbrains\\lightshot\\Lightshot.exe"},
		"Adobe Reader":    {"Adobe\\Acrobat Reader DC\\Reader\\AcroRd32.exe", "Adobe\\Reader\\AcroRd32.exe"},
		"Firefox":         {"Mozilla Firefox\\firefox.exe"},
		"Java JDK":        {"Java\\jdk-17\\bin\\java.exe", "Java\\jdk-23\\bin\\java.exe", "Java\\jdk-23.0.1\\bin\\java.exe"},
		"TightVNC":        {"TightVNC\\tvnserver.exe", "TightVNC\\tvnviewer.exe"},
		"AnyDesk":         {"AnyDesk\\AnyDesk.exe"},
		"Git":             {"Git\\bin\\git.exe"},
		"Node.js":         {"nodejs\\node.exe"},
		"Python 3":        {"Python39\\python.exe", "Python310\\python.exe"},
		"Docker Desktop":  {"Docker\\Docker\\resources\\bin\\docker.exe"},
		"MongoDB":         {"MongoDB\\Server\\7.0\\bin\\mongod.exe"},
		"SQLyog":          {"SQLyog\\SQLyog.exe"},
		"Postman":         {"Postman\\Postman.exe"},
		"RabbitMQ Server": {"RabbitMQ Server\\rabbitmq_server-3.11.3\\sbin\\rabbitmqctl.bat"},
		"ElasticSearch":   {"Elastic\\Elasticsearch\\8.11.1\\bin\\elasticsearch-service.bat"},
	}

	// Service Check Fallback for Middleware
	if name == "RabbitMQ Server" || name == "ElasticSearch" {
		serviceName := "RabbitMQ"
		if name == "ElasticSearch" {
			serviceName = "elasticsearch"
		}
		psCmd := fmt.Sprintf("Get-Service '%s' -ErrorAction SilentlyContinue", serviceName)
		cmd := exec.Command("powershell", "-Command", psCmd)
		cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
		if err := cmd.Run(); err == nil {
			return true
		}
	}

	searchPaths := []string{
		"C:\\Program Files",
		"C:\\Program Files (x86)",
		filepath.Join(os.Getenv("LocalAppData"), "Programs"),
	}

	// Check if we have specific files to look for
	if relativePaths, ok := softwareFiles[name]; ok {
		for _, basePath := range searchPaths {
			for _, relPath := range relativePaths {
				checkPath := filepath.Join(basePath, relPath)
				if _, err := os.Stat(checkPath); err == nil {
					return true
				}
			}
		}
	}

	// Fallback: search for a folder that contains an .exe file (legacy or unknown apps)
	nameLower := strings.ToLower(name)
	for _, p := range searchPaths {
		files, err := os.ReadDir(p)
		if err != nil {
			continue
		}
		for _, f := range files {
			if f.IsDir() && strings.Contains(strings.ToLower(f.Name()), nameLower) {
				// Check if this folder actually contains any .exe files
				folderPath := filepath.Join(p, f.Name())
				if hasExeInFolder(folderPath) {
					return true
				}
			}
		}
	}
	return false
}

// hasExeInFolder checks if there's any .exe file in the top level or subfolders (shallow)
func hasExeInFolder(path string) bool {
	files, err := os.ReadDir(path)
	if err != nil {
		return false
	}
	for _, f := range files {
		if !f.IsDir() && strings.HasSuffix(strings.ToLower(f.Name()), ".exe") {
			return true
		}
		// Check one level deeper for common "bin" or app folders
		if f.IsDir() && (f.Name() == "bin" || f.Name() == "app" || f.Name() == "Application") {
			subFiles, err := os.ReadDir(filepath.Join(path, f.Name()))
			if err == nil {
				for _, sf := range subFiles {
					if !sf.IsDir() && strings.HasSuffix(strings.ToLower(sf.Name()), ".exe") {
						return true
					}
				}
			}
		}
	}
	return false
}

// Use User's Temp Directory to avoid "Access Denied"
var TempDir = filepath.Join(os.TempDir(), "TriveniInstaller")

// --- Exposed Methods ---

// GetSystemStatus returns checking NAS availability
func (a *App) GetSystemStatus() string {
	// Attempt to load config to get NAS path
	config, err := loadConfig("config.json")
	if err != nil {
		return "⚠️ Config Error: " + err.Error()
	}

	if checkNasAvailability(config.NasBasePath) {
		return fmt.Sprintf("✅ NAS Connected (%s)", config.NasBasePath)
	}
	return "🌍 NAS Offline (Internet Mode)"
}

// ConnectNAS attempts to map the NAS drive with credentials
func (a *App) ConnectNAS(user, pass string) string {
	config, err := loadConfig("config.json")
	if err != nil {
		return "Error: " + err.Error()
	}

	// PowerShell: net use <path> <pass> /user:<user> /persistent:no
	ps := fmt.Sprintf(`net use "%s" "%s" /user:"%s" /persistent:no`, config.NasBasePath, pass, user)
	cmd := exec.Command("powershell", "-Command", ps)
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	output, err := cmd.CombinedOutput()

	if err != nil {
		return "Connection Failed: " + string(output)
	}
	return "✅ Success: NAS Connected."
}

// DisconnectNAS removes the NAS mapping and credentials
func (a *App) DisconnectNAS() string {
	config, err := loadConfig("config.json")
	if err != nil {
		return "Error: " + err.Error()
	}

	// Extract server IP/Name from UNC path (e.g. \\174.156.4.3\...)
	parts := strings.Split(config.NasBasePath, "\\")
	var server string
	if len(parts) >= 3 {
		server = parts[2] // This gets '174.156.4.3' without backslashes for cmdkey
	}

	// PowerShell script to aggressively clear sessions
	// 1. cmdkey /delete:<server> (Removes saved Windows Credentials)
	// 2. net use * /delete /y (Forces close of all network connections)
	psCleanup := fmt.Sprintf(`
		cmdkey /delete:%s 2>$null
		net use * /delete /y 2>$null
	`, server)

	cmd := exec.Command("powershell", "-Command", psCleanup)
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	// We capture output but don't fail immediately on it, as some commands might error if nothing to delete
	output, _ := cmd.CombinedOutput()

	// Double check availability
	if !checkNasAvailability(config.NasBasePath) {
		return "✅ Success: Credentials wiped and disconnected."
	}

	return "Warning: Session persists. Output: " + string(output)
}

// GetSoftwareList reads the config.json and returns the list
func (a *App) GetSoftwareList() []Software {
	config, err := loadConfig("config.json")
	if err != nil {
		return []Software{}
	}

	for i := range config.SoftwareList {
		config.SoftwareList[i].IsInstalled = isSoftwareInstalled(config.SoftwareList[i].Name)
	}

	return config.SoftwareList
}

// GetHardwareInfo returns detailed system stats without flashing windows
func (a *App) GetHardwareInfo() HardwareInfo {
	hostname, _ := os.Hostname()

	info := HardwareInfo{
		OS:       runtime.GOOS + " " + runtime.GOARCH,
		Hostname: hostname,
		CPU:      "Detecting...",
		RAM:      "Detecting...",
		IP:       "Detecting...",
		Disk:     "Detecting...",
	}

	if runtime.GOOS == "windows" {
		// Combine all queries into one PowerShell script to minimize process spawning
		psScript := `
			$cpu = (Get-CimInstance Win32_Processor).Name
			$ram = [Math]::Round((Get-CimInstance Win32_PhysicalMemory | Measure-Object Capacity -Sum).Sum / 1GB, 2)
			$ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'Ethernet', 'Wi-Fi' | Select-Object -First 1).IPAddress
			$c = Get-PSDrive C
			$disk = [Math]::Round(($c.Used / ($c.Used + $c.Free)) * 100, 1)
			"$cpu|$ram GB|$ip|$disk% Used"
		`
		cmd := exec.Command("powershell", "-Command", psScript)
		cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}

		out, err := cmd.Output()
		if err == nil {
			parts := strings.Split(strings.TrimSpace(string(out)), "|")
			if len(parts) == 4 {
				info.CPU = parts[0]
				info.RAM = parts[1]
				info.IP = parts[2]
				info.Disk = parts[3]
			}
		}
	} else {
		info.CPU = "Unknown"
		info.RAM = "Unknown"
		info.IP = "127.0.0.1"
		info.Disk = "Unknown"
	}

	return info
}

// InstallSoftware handles the logic for a specific software
func (a *App) InstallSoftware(name string) string {
	config, err := loadConfig("config.json")
	if err != nil {
		return "Error loading config"
	}

	var targetSw Software
	found := false
	for _, sw := range config.SoftwareList {
		if sw.Name == name {
			targetSw = sw
			found = true
			break
		}
	}

	if !found {
		return "Software not found in config"
	}

	os.MkdirAll(TempDir, 0755)

	// Detect file extension from NAS path
	fileExt := filepath.Ext(targetSw.NasPath)
	if fileExt == "" {
		fileExt = ".exe" // Default to .exe if no extension found
	}
	destPath := filepath.Join(TempDir, targetSw.Name+fileExt)

	// Logic: Embedded -> NAS -> Internet
	installerPath := ""

	if targetSw.IsEmbedded {
		// Extract from binary to temp folder
		installerPath = extractEmbeddedScript(targetSw.NasPath)
	}

	if installerPath == "" {
		// Try multiple NAS search roots for better reliability
		nasRoots := []string{
			config.NasBasePath,
			"\\\\174.156.4.3\\fjt\\Automations-Priyanshu",
			"\\\\174.156.4.3\\fjt\\Automations-Priyanshu\\Basic sw",
			"\\\\174.156.4.3\\fjt\\Required softwares\\Automation Software\\Automations-Priyanshu",
		}

		for _, root := range nasRoots {
			if root == "" {
				continue
			}
			if checkNasAvailability(root) {
				fullNasPath := filepath.Join(root, targetSw.NasPath)
				if fileExists(fullNasPath) {
					err := copyFile(fullNasPath, destPath)
					if err == nil {
						installerPath = destPath
						break
					}
				}
			}
		}
	}

	if installerPath == "" {
		// Local Fallback: Check if file exists in the current directory or a relative path
		if fileExists(targetSw.NasPath) {
			installerPath = targetSw.NasPath
		} else {
			// Fallback to Internet
			if targetSw.DownloadUrl == "" {
				return "❌ Error: Not found on NAS and no Download URL provided for " + targetSw.Name
			}
			err := downloadFile(targetSw.DownloadUrl, destPath)
			if err != nil {
				return "Download Failed: " + err.Error()
			}
			installerPath = destPath
		}
	}

	// Install
	err = runInstaller(installerPath, targetSw.InstallArgs, targetSw.Interactive)
	if err != nil {
		return "Installation Error: " + err.Error()
	}

	return "✅ Success: " + targetSw.Name + " Installed."
}

// BulkInstall processes multiple softwares in one go
func (a *App) BulkInstall(names []string) []string {
	var results []string
	for _, name := range names {
		res := a.InstallSoftware(name)
		results = append(results, res)
	}
	return results
}

// UninstallSoftware handles the removal logic for a specific software
func (a *App) UninstallSoftware(name string) string {
	config, err := loadConfig("config.json")
	if err != nil {
		return "Error loading config"
	}

	var targetSw Software
	found := false
	for _, sw := range config.SoftwareList {
		if sw.Name == name {
			targetSw = sw
			found = true
			break
		}
	}

	if !found {
		return "Software not found in config"
	}

	if len(targetSw.UninstallArgs) == 0 {
		return "❌ Error: No uninstall command defined for " + targetSw.Name
	}

	// Check if this is an MSI installer
	if strings.HasSuffix(strings.ToLower(targetSw.NasPath), ".msi") {
		// For MSI files, use the installer path to uninstall
		// Try NAS first, then temp directory
		var installerPath string

		// Check if NAS is available and file exists
		useNas := checkNasAvailability(config.NasBasePath)
		if useNas {
			fullNasPath := filepath.Join(config.NasBasePath, targetSw.NasPath)
			if fileExists(fullNasPath) {
				installerPath = fullNasPath
			}
		}

		// Fallback to temp directory
		if installerPath == "" {
			fileExt := filepath.Ext(targetSw.NasPath)
			tempPath := filepath.Join(TempDir, targetSw.Name+fileExt)
			if fileExists(tempPath) {
				installerPath = tempPath
			}
		}

		if installerPath != "" {
			// Use msiexec /x with the installer file
			// Combine /x, installer path, and additional args (like /qn)
			msiArgs := []string{"/x", installerPath}
			msiArgs = append(msiArgs, targetSw.UninstallArgs...)

			cmd := exec.Command("msiexec", msiArgs...)
			cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: !targetSw.Interactive}
			output, err := cmd.CombinedOutput()

			if err != nil {
				return "Uninstallation Error: " + string(output) + " " + err.Error()
			}

			return "✅ Success: " + targetSw.Name + " Removed."
		}

		return "❌ Error: MSI installer file not found for uninstallation"
	}

	// For non-MSI files (regular exe uninstallers), run directly
	// Expand environment variables and handle quoting
	if len(targetSw.UninstallArgs) > 0 {
		if targetSw.IsEmbedded {
			// Embedded scripts are always handled via PowerShell
			extractedPath := extractEmbeddedScript(targetSw.NasPath)
			if extractedPath == "" {
				return "❌ Error: Failed to extract embedded script for uninstallation"
			}

			// Construct powershell command for the extracted script
			psArgs := []string{"-NoExit", "-ExecutionPolicy", "Bypass", "-File", extractedPath}
			psArgs = append(psArgs, targetSw.UninstallArgs...)
			psCmd := fmt.Sprintf("Start-Process powershell.exe -ArgumentList '%s' -Wait", strings.Join(psArgs, "','"))
			cmd := exec.Command("powershell", "-NoProfile", "-Command", psCmd)
			err := cmd.Run()
			if err != nil {
				return "Uninstallation Error: " + err.Error()
			}
			return "✅ Success: " + targetSw.Name + " Removal Finished."
		}

		expandedCmd := os.ExpandEnv(strings.Join(targetSw.UninstallArgs, " "))

		var exePath string
		var args []string

		// Basic parser for quoted paths
		if strings.HasPrefix(expandedCmd, "\"") {
			endQuote := strings.Index(expandedCmd[1:], "\"")
			if endQuote > 0 {
				exePath = expandedCmd[1 : endQuote+1]
				remaining := strings.TrimSpace(expandedCmd[endQuote+2:])
				if remaining != "" {
					args = strings.Fields(remaining)
				}
			}
		} else {
			parts := strings.Fields(expandedCmd)
			if len(parts) > 0 {
				exePath = parts[0]
				if len(parts) > 1 {
					args = parts[1:]
				}
			}
		}

		if exePath != "" {
			if targetSw.Interactive {
				// Launch in a visible PowerShell window using Start-Process
				// This ensures a new console window is created specifically for this task
				var psCmd string
				if strings.HasSuffix(strings.ToLower(exePath), ".ps1") {
					psArgs := []string{"-NoExit", "-ExecutionPolicy", "Bypass", "-File", exePath}
					psArgs = append(psArgs, args...)
					psCmd = fmt.Sprintf("Start-Process powershell.exe -ArgumentList '%s' -Wait", strings.Join(psArgs, "','"))
				} else {
					// For regular EXEs, only pass ArgumentList if there are actually arguments
					if len(args) > 0 {
						psCmd = fmt.Sprintf("Start-Process '%s' -ArgumentList '%s' -Wait", exePath, strings.Join(args, "','"))
					} else {
						psCmd = fmt.Sprintf("Start-Process '%s' -Wait", exePath)
					}
				}
				cmd := exec.Command("powershell", "-NoProfile", "-NoExit", "-Command", psCmd)
				err := cmd.Run()
				if err != nil {
					return "Uninstallation Error: " + err.Error()
				}
				return "✅ Success: " + targetSw.Name + " Removed."
			}

			cmd := exec.Command(exePath, args...)
			// Hide the console window of the process itself (if it's a console-linked exe)
			// But for GUI uninstallers (like VLC), it will show its own window.
			cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}

			// We don't use CombinedOutput here because we want the GUI to show up
			// and potentially keep running.
			err := cmd.Start()
			if err != nil {
				return "Uninstallation Launch Error: " + err.Error()
			}

			return "✅ Success: " + targetSw.Name + " Removal Started."
		}
	}

	return "❌ Error: Invalid uninstall configuration for " + targetSw.Name
}

// TestSoftware runs diagnostic checks for a software
func (a *App) TestSoftware(name string) string {
	config, err := loadConfig("config.json")
	if err != nil {
		return "Error loading config"
	}

	var targetSw Software
	found := false
	for _, sw := range config.SoftwareList {
		if sw.Name == name {
			targetSw = sw
			found = true
			break
		}
	}

	if !found {
		return "Software not found in config"
	}

	if len(targetSw.TestArgs) == 0 {
		return "ℹ️ No test diagnostics defined for " + targetSw.Name
	}

	// For test scripts, we ALWAYS want a visible window so the user can see the result
	var cmd *exec.Cmd
	if targetSw.IsEmbedded {
		extractedPath := extractEmbeddedScript(targetSw.NasPath)
		if extractedPath == "" {
			return "❌ Error: Failed to extract embedded script for testing"
		}

		// Use Start-Process for visible interactive tests
		var testArgsJoined string
		if len(targetSw.TestArgs) > 0 {
			testArgsJoined = "'" + strings.Join(targetSw.TestArgs, "','") + "'"
		}

		psCmd := fmt.Sprintf("Start-Process powershell.exe -ArgumentList '-NoExit','-ExecutionPolicy','Bypass','-File','%s',%s -Wait", extractedPath, testArgsJoined)
		// Clean up if no args
		if len(targetSw.TestArgs) == 0 {
			psCmd = fmt.Sprintf("Start-Process powershell.exe -ArgumentList '-NoExit','-ExecutionPolicy','Bypass','-File','%s' -Wait", extractedPath)
		}

		cmd = exec.Command("powershell", "-NoProfile", "-Command", psCmd)
	} else {
		expandedCmd := os.ExpandEnv(strings.Join(targetSw.TestArgs, " "))
		// Launch in a visible PowerShell window that stays open (-NoExit)
		// Using Start-Process here too for consistency
		psCmd := fmt.Sprintf("Start-Process powershell.exe -ArgumentList '-NoExit','-NoProfile','-Command','%s' -Wait", expandedCmd)
		cmd = exec.Command("powershell", "-NoProfile", "-Command", psCmd)
	}

	err = cmd.Start()
	if err != nil {
		return "Test Launch Error: " + err.Error()
	}

	return "🔍 Diagnostics launched for " + targetSw.Name
}

// RenamePC renames the computer and requires a restart
func (a *App) RenamePC(newName string) string {
	if !isAdmin() {
		return "⚠️ Error: Administrative privileges required to rename PC."
	}
	if newName == "" {
		return "Error: Name cannot be empty."
	}
	if len(newName) > 15 {
		return "Error: PC Name too long (Max 15 characters)."
	}
	// Check for illegal characters (RFC 1123 / Windows restrictions)
	invalidChars := []string{" ", ".", ",", "@", "#", "$", "%", "^", "&", "*", "(", ")", "+", "=", "[", "]", "{", "}", "|", "\\", ":", ";", "\"", "'", "<", ">", "?", "/"}
	for _, char := range invalidChars {
		if strings.Contains(newName, char) {
			return "Error: PC Name contains illegal character: " + char
		}
	}

	hostname, _ := os.Hostname()
	if strings.EqualFold(hostname, newName) {
		return "ℹ️ PC is already named " + newName
	}

	// Use ErrorAction Stop to ensure errors are caught by Go
	ps := fmt.Sprintf("Rename-Computer -NewName '%s' -Force -ErrorAction Stop", newName)
	cmd := exec.Command("powershell", "-Command", ps)
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}

	output, err := cmd.CombinedOutput()
	if err != nil {
		return "PowerShell Error: " + string(output) + " " + err.Error()
	}
	return "✅ Success: PC Renamed to " + newName + ". Restart required."
}

// SetStaticIP configures the network adapter
func (a *App) SetStaticIP(ip, subnet, gateway, dns string) string {
	if !isAdmin() {
		return "⚠️ Error: Administrative privileges required for network changes."
	}
	ps := fmt.Sprintf(`
		$adapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
		if ($adapter) {
			New-NetIPAddress -InterfaceAlias $adapter.Name -IPAddress '%s' -PrefixLength %s -DefaultGateway '%s' -Force -ErrorAction Stop
			Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ServerAddresses ('%s') -ErrorAction Stop
		} else {
			throw 'No active network adapter found'
		}
	`, ip, subnet, gateway, dns)

	cmd := exec.Command("powershell", "-Command", ps)
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "Network Error: " + string(output) + " " + err.Error()
	}
	return "✅ Success: Static IP and DNS applied."
}

// SetWallpaper sets the desktop wallpaper via PowerShell
func (a *App) SetWallpaper(url string) string {
	dest := filepath.Join(TempDir, "wallpaper.jpg")
	os.MkdirAll(TempDir, 0755)

	err := downloadFile(url, dest)
	if err != nil {
		return "Download Error: " + err.Error()
	}

	ps := fmt.Sprintf(`
		$code = @'
		using System.Runtime.InteropServices;
		public class Wallpaper {
			[DllImport("user32.dll", CharSet = CharSet.Auto)]
			public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
		}
'@
		Add-Type $code
		[Wallpaper]::SystemParametersInfo(20, 0, '%s', 3)
	`, dest)

	cmd := exec.Command("powershell", "-Command", ps)
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "Wallpaper Error: " + string(output) + " " + err.Error()
	}
	return "✅ Success: Wallpaper updated."
}

// SetBrandedWallpaper sets the local tgs.png as wallpaper
func (a *App) SetBrandedWallpaper() string {
	// Find the file in the executable directory
	exe, _ := os.Executable()
	exeDir := filepath.Dir(exe)
	localPath := filepath.Join(exeDir, "tgs.png")

	// Fallback to current working directory if exe path is weird
	if _, err := os.Stat(localPath); os.IsNotExist(err) {
		localPath = "tgs.png"
	}

	if _, err := os.Stat(localPath); os.IsNotExist(err) {
		return "Error: Branding file 'tgs.png' not found in application folder."
	}

	ps := fmt.Sprintf(`
		$code = @'
		using System.Runtime.InteropServices;
		public class Wallpaper {
			[DllImport("user32.dll", CharSet = CharSet.Auto)]
			public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
		}
'@
		Add-Type $code
		[Wallpaper]::SystemParametersInfo(20, 0, '%s', 3)
	`, localPath)

	cmd := exec.Command("powershell", "-Command", ps)
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "Branding Error: " + string(output) + " " + err.Error()
	}
	return "✅ Success: TGS Branding Applied!"
}

// SyncTime sets timezone to India and syncs with NTP
func (a *App) SyncTime() string {
	if !isAdmin() {
		return "⚠️ Error: Administrative privileges required to sync time."
	}
	ps := `
		Set-TimeZone -Id "India Standard Time" -ErrorAction Stop
		net start w32time ; w32tm /resync /force
		Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name "sShortTime" -Value "HH:mm" -Force
		Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name "sTimeFormat" -Value "HH:mm:ss" -Force
	`
	cmd := exec.Command("powershell", "-Command", ps)
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "Time Sync Error: " + string(output) + " " + err.Error()
	}
	return "✅ Success: Time synced to India (12HR format set)."
}

// ShowThisPCIcon adds 'This PC' to desktop via registry
func (a *App) ShowThisPCIcon() string {
	ps := `
		$path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"
		if (!(Test-Path $path)) { New-Item -Path $path -Force -ErrorAction Stop }
		Set-ItemProperty -Path $path -Name "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" -Value 0 -Force -ErrorAction Stop
	`
	cmd := exec.Command("powershell", "-Command", ps)
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "Registry Error: " + string(output) + " " + err.Error()
	}
	return "✅ Success: 'This PC' icon enabled."
}

// SetSleepMode configures AC sleep timeout (0 = Never)
func (a *App) SetSleepMode(minutes int) string {
	var cmdStr string
	if minutes == 0 {
		cmdStr = "powercfg /change monitor-timeout-ac 0; powercfg /change standby-timeout-ac 0"
	} else {
		cmdStr = fmt.Sprintf("powercfg /change monitor-timeout-ac %d; powercfg /change standby-timeout-ac %d", minutes, minutes)
	}

	cmd := exec.Command("powershell", "-Command", cmdStr)
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "Power Error: " + string(output) + " " + err.Error()
	}
	status := fmt.Sprintf("%d Min", minutes)
	if minutes == 0 {
		status = "Never"
	}
	return "✅ Success: Sleep Mode set to " + status
}

// AllowPing enables ICMP Echo Request through Windows Firewall
func (a *App) AllowPing() string {
	if !isAdmin() {
		return "⚠️ Error: Administrative privileges required to modify firewall."
	}

	// PowerShell command to enable ICMPv4 Echo Request rule
	// We try to enable the built-in rule first, if not we create a new one
	ps := `
		$ruleName = "Allow ICMPv4-In"
		$rule = Get-NetFirewallRule -DisplayName "File and Printer Sharing (Echo Request - ICMPv4-In)" -ErrorAction SilentlyContinue
		if ($rule) {
			Enable-NetFirewallRule -DisplayName "File and Printer Sharing (Echo Request - ICMPv4-In)" -ErrorAction Stop
			return "✅ Success: Standard Ping rule enabled."
		} else {
			netsh advfirewall firewall add rule name="Allow ICMPv4 Ping" protocol=icmpv4:8,any dir=in action=allow
			return "✅ Success: custom Ping rule created."
		}
	`
	cmd := exec.Command("powershell", "-Command", ps)
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "Firewall Error: " + string(output) + " " + err.Error()
	}
	return string(output)
}

// --- Helpers ---

func loadConfig(path string) (*Config, error) {
	// Try looking in current dir or one level up (for dev mode)
	if !fileExists(path) {
		if fileExists("../" + path) {
			path = "../" + path
		}
	}

	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()
	bytes, _ := io.ReadAll(file)
	var config Config
	json.Unmarshal(bytes, &config)
	return &config, nil
}

func checkNasAvailability(path string) bool {
	if runtime.GOOS != "windows" {
		return false
	}
	_, err := os.Stat(path)
	return err == nil
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func copyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer out.Close()
	_, err = io.Copy(out, in)
	return err
}

func downloadFile(url, filepath string) error {
	resp, err := http.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	out, err := os.Create(filepath)
	if err != nil {
		return err
	}
	defer out.Close()
	_, err = io.Copy(out, resp.Body)
	return err
}

func isAdmin() bool {
	_, err := os.Open("\\\\.\\PHYSICALDRIVE0")
	return err == nil
}

func runInstaller(path string, args []string, interactive bool) error {
	if interactive {
		// For interactive mode, we rely on PowerShell's Start-Process to create a visible window
		var psCmd string
		if strings.HasSuffix(strings.ToLower(path), ".ps1") {
			// -NoExit ensures the user can see the output even if the script finishes or crashes
			psArgs := []string{"-NoExit", "-ExecutionPolicy", "Bypass", "-File", path}
			psArgs = append(psArgs, args...)
			psCmd = fmt.Sprintf("Start-Process powershell.exe -ArgumentList '%s' -Wait", strings.Join(psArgs, "','"))
		} else if strings.HasSuffix(strings.ToLower(path), ".msi") {
			msiArgs := []string{"/i", path}
			msiArgs = append(msiArgs, args...)
			psCmd = fmt.Sprintf("Start-Process msiexec.exe -ArgumentList '%s' -Wait", strings.Join(msiArgs, "','"))
		} else {
			psArgs := []string{path}
			psArgs = append(psArgs, args...)
			psCmd = fmt.Sprintf("Start-Process '%s' -ArgumentList '%s' -Wait", psArgs[0], strings.Join(psArgs[1:], "','"))
			// Special case for exe with no args
			if len(args) == 0 {
				psCmd = fmt.Sprintf("Start-Process '%s' -Wait", path)
			}
		}
		cmd := exec.Command("powershell", "-NoProfile", "-Command", psCmd)
		return cmd.Run()
	}

	// Hidden mode (for silent installers like Chrome, 7-zip etc)
	if strings.HasSuffix(strings.ToLower(path), ".ps1") {
		psArgs := []string{"-NoProfile", "-ExecutionPolicy", "Bypass", "-File", path}
		psArgs = append(psArgs, args...)
		cmd := exec.Command("powershell", psArgs...)
		if runtime.GOOS == "windows" {
			cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
		}
		return cmd.Run()
	}

	if strings.HasSuffix(strings.ToLower(path), ".msi") {
		msiArgs := append([]string{"/i", path}, args...)
		cmd := exec.Command("msiexec", msiArgs...)
		if runtime.GOOS == "windows" {
			cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
		}
		return cmd.Run()
	}

	cmd := exec.Command(path, args...)
	if runtime.GOOS == "windows" {
		cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	}
	return cmd.Run()
}

func extractEmbeddedScript(scriptName string) string {
	os.MkdirAll(TempDir, 0755)
	destPath := filepath.Join(TempDir, scriptName)

	data, err := embeddedScripts.ReadFile("scripts/" + scriptName)
	if err != nil {
		fmt.Printf("Error reading embedded script %s: %v\n", scriptName, err)
		return ""
	}

	err = os.WriteFile(destPath, data, 0755)
	if err != nil {
		fmt.Printf("Error writing script to disk %s: %v\n", destPath, err)
		return ""
	}

	return destPath
}
