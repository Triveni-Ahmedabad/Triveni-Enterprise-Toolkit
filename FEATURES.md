# Triveni SysAdmin Toolkit - Technical Documentation

**Current Version**: `v1.18.0`  
**Latest Update**: Advanced Security Suite (USB Storage / RDP / Domain Whitelisting)

---

## 🚀 Key Modules & Features

### 1. Advanced Security Suite (NEW in v1.18.0)
Located under the **Security check** tab, this module allows rapid enforcement of company security policies:
- **USB Storage Block**: Prevents unauthorized data transfer by disabling mass storage devices via Registry.
- **RDP Management**: One-click toggle for Remote Desktop access. Automatically configures `fDenyTSConnections` and enables/disables the **Remote Desktop** firewall group.
- **Domain Whitelisting**: Restricts browser (Chrome/Edge) access to a specific list of domains.
    - *Usage*: Enter comma-separated values (e.g., `google.com, triveni.com`).
    - *Reset*: Clears all blocks and restores full internet access.

### 2. System Setup & Identity
Essential tools for preparing a new workstation:
- **PC Renaming**: Intelligent hostname update with automated reboot trigger.
- **Temporal Sync**: Synchronizes system clock with Indian Standard Time (IST) 12-hour format.
- **Visuals**: 
    - Apply custom wallpaper via URL.
    - **TGS Branding**: One-click application of the corporate wallpaper.
    - **This PC Icon**: Instant visibility of 'This PC' on the desktop.
- **Power Management**: Set sleep timeouts (1hr, 3hr, or NEVER).
- **Network Module**: Configure Static IP, Subnet, Gateway, and DNS. Also includes a toggle for **Firewall Ping Allowance**.

### 3. Software Installation & Configuration
- **Smart Category Filtering**: Softwares are grouped into categories (Basic, Q2C, Middleware) with sub-category nesting.
- **Bulk Operations**: Multi-select apps and click **INSTALL ALL** or **REMOVE ALL** via the floating action button.
- **NAS + HTTP Fallback**: 
    - Prioritizes high-speed local NAS (174.156.4.3) for zero-bandwidth internal deployments.
    - Automatically falls back to Internet download if NAS is offline.
- **Real-Time Progress**: 
    - Byte-by-byte progress reporting for long downloads and file copies.
    - Visual status pulsars inside the install buttons.

### 4. System Audit
Complete hardware overview:
- CPU Architecture & Speed
- RAM Capacity
- OS Distribution and Version
- Network Status (Hostname & Primary IP)
- Disk Usage (Visual breakdown of C: drive)

---

## 🛠 Project Configuration & Architecture

### `config.json`
The heart of the toolkit. Defines the software list, arguments, and deployment paths.
- **`nas_path`**: Relative path from the NAS base.
- **`download_url`**: Fallback Internet source.
- **`install_args`**: Silent switches (e.g., `/S`, `/verysilent`).
- **`is_embedded`**: Boolean to determine if the script is baked into the Go binary.

### `app.go` (Backend)
High-performance Go implementation handling:
- Windows Registry manipulations.
- PowerShell script execution with `SysProcAttr{HideWindow: true}`.
- Real-time event emitting to the React frontend.

---

## 📜 Version History

| Version | Feature Highlights |
| :--- | :--- |
| **v1.18.0** | USB/RDP Block, Domain Whitelisting, FEATURES.md documentation. |
| **v1.17.3** | UI Cleanup: Removed redundant sidebar items, centralized NAS in Header. |
| **v1.17.2** | Header NAS Status (vibrant color indicators) and Quick Login portal. |
| **v1.17.1** | Hotfix: Corrected `downloadFile` arguments and build sync. |
| **v1.17.0** | **Real-Time Progress Bar** for NAS file operations. |
| **v1.16.0** | Implementation of NAS Fallback logic & Multi-Tasking support. |
| **v1.0.0** | Initial Release with Basic Software Suite. |

---

## 📦 Deployment
Run `local-build.bat` to generate the production executable.
> [!IMPORTANT]
> The resulting `Triveni-Control-Center.exe` must be run as **Administrator** for Security and Network modules to function correctly.
