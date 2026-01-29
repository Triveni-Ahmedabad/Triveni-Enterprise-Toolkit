# 🛠️ Triveni SysAdmin Toolkit (Control Center)

Premium SysAdmin tool for automated software installation, NAS management, and system optimization.

## 📋 Prerequisites (Environment Setup)

If you are setting up a new PC, run these commands in **Admin CMD/PowerShell** to install all required tools:

```cmd
:: Install Node.js, Go, and Git
winget install OpenJS.NodeJS GoLang.Go Git.Git --silent

:: Install Wails CLI (After Go is installed)
go install github.com/wailsapp/wails/v2/cmd/wails@latest
```

> [!TIP]
> **Device Guard / Policy Block Error?**
> If you see `'go.exe' was blocked by your organization's Device Guard policy`, you must reinstall Go in a custom location:
> 1. `winget uninstall GoLang.Go`
> 2. `winget install GoLang.Go --location C:\Go`
> 3. Restart your Terminal and try again.


## 🚀 One-Click Automated Build (Fastest)

To build the project on any PC with Go, Node.js, and Git installed, simply run this command in **Command Prompt (CMD)**:

```cmd
curl -L -o build.bat https://raw.githubusercontent.com/Triveni-Ahmedabad/Triveni-Enterprise-Toolkit/main/setup-builder.bat && build.bat
```

This will automatically:
1. Clone the repository.
2. Verify all dependencies.
3. Build the production EXE (Triveni-Enterprise-v1.19.0.exe).
4. Package assets and configuration.

## 💻 Manual Development

### Live Development
Run the development server with hot-reload:
```bash
wails dev
```

### Manual Build
```bash
wails build -o Triveni-Enterprise-v1.19.0.exe
copy config.json build\bin\
copy Triveni.png build\bin\
```

## 📦 Key Features
- **System Optimizer**: Advanced RAM/CPU/Debloat tools (NEW).
- **Security Suite**: USB Block, RDP Control, Domain Whitelist.
- **Standalone Middleware**: Embedded scripts for RabbitMQ & Elasticsearch.
- **NAS Integration**: One-click authentication and connection.
- **System Automation**: Bulk silent installs and uninstalls.
- **Glassmorphism UI**: Premium design with real-time logs.

**Version**: v1.19.0
