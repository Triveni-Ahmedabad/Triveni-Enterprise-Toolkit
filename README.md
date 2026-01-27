# 🛠️ Triveni SysAdmin Toolkit (Control Center)

Premium SysAdmin tool for automated software installation, NAS management, and system optimization.

## 🚀 One-Click Automated Build (Fastest)

To build the project on any PC with Go, Node.js, and Git installed, simply run this command in **Command Prompt (CMD)**:

```cmd
curl -L -o build.bat https://raw.githubusercontent.com/Triveni-Ahmedabad/Triveni-SysAdmin-Toolkit/main/Triveni-Control-Center/setup-builder.bat && build.bat
```

This will automatically:
1. Clone the repository.
2. Verify all dependencies.
3. Build the production EXE (Triveni-Enterprise-v1.13.0.exe).
4. Package assets and configuration.

## 💻 Manual Development

### Live Development
Run the development server with hot-reload:
```bash
wails dev
```

### Manual Build
```bash
wails build -o Triveni-Enterprise-v1.13.0.exe
copy config.json build\bin\
copy Triveni.png build\bin\
```

## 📦 Key Features
- **Standalone Middleware**: Embedded scripts for RabbitMQ & Elasticsearch.
- **NAS Integration**: One-click authentication and connection.
- **System Automation**: Bulk silent installs and uninstalls.
- **Glassmorphism UI**: Premium design with real-time logs.

**Version**: v1.13.0
