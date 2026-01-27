import React, { useState, useEffect, useMemo } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
    LayoutDashboard,
    Package,
    Search,
    Terminal,
    Settings,
    Download,
    CheckCircle2,
    AlertCircle,
    Cpu,
    HardDrive,
    Monitor,
    Activity,
    Globe,
    Database,
    ShieldCheck,
    Mail,
    FileCode,
    Wrench,
    Server,
    Network,
    Image as ImageIcon,
    RotateCcw,
    Clock,
    Zap,
    MousePointer2,
    Lock,
    X,
    Sun,
    Moon,
    RefreshCcw
} from 'lucide-react';
import './App.css';
import {
    GetSystemStatus,
    GetSoftwareList,
    InstallSoftware,
    GetHardwareInfo,
    RenamePC,
    SetStaticIP,
    SetWallpaper,
    SetBrandedWallpaper,
    SyncTime,
    ShowThisPCIcon,
    SetSleepMode,
    ConnectNAS,
    DisconnectNAS,
    AllowPing,
    UninstallSoftware,
    TestSoftware
} from "../wailsjs/go/main/App";

interface Software {
    name: string;
    description: string;
    nas_path: string;
    download_url: string;
    category: string;
    sub_category: string;
    is_installed: boolean;
    uninstall_args: string[];
    interactive: boolean;
    version: string;
    test_args: string[];
}

interface HardwareInfo {
    cpu: string;
    ram: string;
    os: string;
    hostname: string;
    ip: string;
    disk: string;
}

function App() {
    const [systemStatus, setSystemStatus] = useState("Checking...");
    const [softwares, setSoftwares] = useState<Software[]>([]);
    const [hwInfo, setHwInfo] = useState<HardwareInfo>({ cpu: "...", ram: "...", os: "...", hostname: "...", ip: "...", disk: "..." });
    const [installLog, setInstallLog] = useState("");
    const [loading, setLoading] = useState(false);
    const [activeTab, setActiveTab] = useState("System setup");
    const [selectedApps, setSelectedApps] = useState<string[]>([]);
    const [progress, setProgress] = useState(0);
    const [searchQuery, setSearchQuery] = useState("");
    const [activeSubTab, setActiveSubTab] = useState("All");
    const [isDarkMode, setIsDarkMode] = useState(true);
    const [isRefreshing, setIsRefreshing] = useState(false);

    // System Setup States
    const [newName, setNewName] = useState("");
    const [ipConfig, setIpConfig] = useState({ ip: "", subnet: "255.255.252.0", gateway: "", dns: "8.8.8.8, 8.8.4.4" });
    const [wallpaperUrl, setWallpaperUrl] = useState("");
    const [nasUser, setNasUser] = useState("");
    const [nasPass, setNasPass] = useState("");
    const [showNasLogin, setShowNasLogin] = useState(false);
    const [installProgress, setInstallProgress] = useState<Record<string, number>>({});
    const [installSource, setInstallSource] = useState<Record<string, string>>({});

    const refreshData = () => {
        setIsRefreshing(true);
        Promise.all([
            GetSystemStatus(),
            GetSoftwareList(),
            GetHardwareInfo()
        ]).then(([status, list, hw]) => {
            setSystemStatus(status);
            setSoftwares(list);
            setHwInfo(hw);
            setTimeout(() => setIsRefreshing(false), 1000);
        });
    }

    const toggleTheme = () => {
        const newTheme = !isDarkMode;
        setIsDarkMode(newTheme);
        document.documentElement.setAttribute('data-theme', newTheme ? 'dark' : 'light');
    }

    useEffect(() => {
        refreshData();
        const interval = setInterval(refreshData, 30000);
        return () => clearInterval(interval);
    }, []);

    const toggleSelection = (name: string) => {
        if (loading) return;
        setSelectedApps(prev =>
            prev.includes(name) ? prev.filter(a => a !== name) : [...prev, name]
        );
    }

    const handleTest = async (name: string) => {
        setLoading(true);
        try {
            const result = await TestSoftware(name);
            setInstallLog(result);
            setTimeout(() => setInstallLog(""), 5000);
        } catch (err: any) {
            setInstallLog("Test Failed: " + err);
            setTimeout(() => setInstallLog(""), 5000);
        } finally {
            setLoading(false);
        }
    };

    const handleAction = (promise: Promise<string>, softwareName?: string) => {
        setLoading(true);
        setInstallLog("Executing Module Task...");

        if (softwareName) {
            setInstallProgress(prev => ({ ...prev, [softwareName]: 0 }));
            setInstallSource(prev => ({ ...prev, [softwareName]: "Checking..." }));

            const progressInterval = setInterval(() => {
                setInstallProgress(prev => {
                    const current = prev[softwareName] || 0;
                    if (current >= 90) {
                        clearInterval(progressInterval);
                        return prev;
                    }
                    return { ...prev, [softwareName]: Math.min(current + 10, 90) };
                });
            }, 300);

            promise.then((result) => {
                clearInterval(progressInterval);
                setInstallProgress(prev => ({ ...prev, [softwareName]: 100 }));

                if (result.includes("NAS")) {
                    setInstallSource(prev => ({ ...prev, [softwareName]: "📁 NAS" }));
                } else if (result.includes("Download")) {
                    setInstallSource(prev => ({ ...prev, [softwareName]: "🌐 Online" }));
                }

                setInstallLog(result);
                setLoading(false);
                refreshData();

                setTimeout(() => {
                    setInstallLog("");
                    setInstallProgress(prev => {
                        const updated = { ...prev };
                        delete updated[softwareName];
                        return updated;
                    });
                    setInstallSource(prev => {
                        const updated = { ...prev };
                        delete updated[softwareName];
                        return updated;
                    });
                }, 5000);
            });
        } else {
            promise.then((result) => {
                setInstallLog(result);
                setLoading(false);
                refreshData();
                setTimeout(() => setInstallLog(""), 5000);
            });
        }
    }

    const handleBulkAction = () => {
        if (selectedApps.length === 0) return;
        setLoading(true);
        setProgress(0);
        let completed = 0;
        const total = selectedApps.length;
        const processNext = (index: number) => {
            if (index >= total) {
                setInstallLog(`Tasks Finished: ${completed}/${total} Successful.`);
                setLoading(false);
                setSelectedApps([]);
                refreshData();
                setTimeout(() => setProgress(0), 10000);
                return;
            }
            const appName = selectedApps[index];
            setInstallLog(`Installing (${index + 1}/${total}): ${appName}...`);
            InstallSoftware(appName).then((result) => {
                if (result.includes("Success")) completed++;
                setProgress(((index + 1) / total) * 100);
                processNext(index + 1);
            });
        };
        processNext(0);
    }

    const selectAllInCategory = () => {
        const appsInSubCategory = filteredSoftwares.map(sw => sw.name);
        setSelectedApps(prev => Array.from(new Set([...prev, ...appsInSubCategory])));
    }

    const filteredSoftwares = useMemo(() => {
        if (activeTab === "All installed script status") return softwares.filter(sw => sw.is_installed);
        return softwares.filter(sw => {
            const matchesTab = sw.category === activeTab;
            const matchesSubTab = activeSubTab === "All" || sw.sub_category === activeSubTab;
            const matchesSearch = sw.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
                sw.description.toLowerCase().includes(searchQuery.toLowerCase());
            return matchesTab && matchesSubTab && matchesSearch;
        });
    }, [softwares, activeTab, activeSubTab, searchQuery]);

    const sidebarCategories = [
        { name: "System setup", icon: <Wrench size={18} /> },
        { name: "Software install", icon: <Package size={18} /> },
        { name: "Software config", icon: <Settings size={18} /> },
        { name: "Security check", icon: <ShieldCheck size={18} /> },
        { name: "Gmail Policy check", icon: <Mail size={18} /> },
        { name: "All installed script status", icon: <FileCode size={18} /> },
    ];

    return (
        <div id="app">
            {/* Sidebar */}
            <aside className="sidebar">
                <div className="brand">
                    <img src="logo.png" alt="Triveni Logo" style={{ width: '32px', height: '32px', objectFit: 'contain', filter: 'drop-shadow(0 0 8px var(--accent-primary))' }} />
                    <div style={{ display: 'flex', flexDirection: 'column' }}>
                        <span>TRIVENI TOOLKIT</span>
                        <span style={{ fontSize: '0.65rem', color: 'var(--accent-primary)', letterSpacing: '1px', marginTop: '-4px' }}>VERSION 1.13.1</span>
                    </div>
                </div>

                <div className="nav-section">
                    <p className="nav-label">Management</p>
                    {sidebarCategories.map(cat => (
                        <React.Fragment key={cat.name}>
                            <div
                                className={`nav-item ${activeTab === cat.name ? 'active' : ''}`}
                                onClick={() => {
                                    setActiveTab(cat.name);
                                    setActiveSubTab("All");
                                }}
                            >
                                {cat.icon}
                                <span>{cat.name}</span>
                            </div>

                            {/* Nested Sub-Categories for Software install */}
                            {activeTab === cat.name && cat.name === "Software install" && (
                                <motion.div
                                    className="nav-sub-section"
                                    initial={{ height: 0, opacity: 0 }}
                                    animate={{ height: 'auto', opacity: 1 }}
                                >
                                    {["All", ...Array.from(new Set(softwares
                                        .filter(sw => sw.category === "Software install")
                                        .map(sw => sw.sub_category)
                                        .filter(Boolean)
                                    ))].map(sub => (
                                        <div
                                            key={sub}
                                            className={`nav-sub-item ${activeSubTab === sub ? 'active' : ''}`}
                                            onClick={() => setActiveSubTab(sub)}
                                        >
                                            <div className="sub-indicator" />
                                            <span>{sub}</span>
                                        </div>
                                    ))}
                                </motion.div>
                            )}
                        </React.Fragment>
                    ))}
                    <div className={`nav-item ${activeTab === "System Audit" ? 'active' : ''}`} onClick={() => setActiveTab("System Audit")}>
                        <Activity size={18} />
                        <span>System Audit</span>
                    </div>
                </div>

                <div className="nav-section">
                    <p className="nav-label">Status</p>
                    <div className={`status-pill clickable ${showNasLogin ? 'active' : ''}`} onClick={() => setShowNasLogin(!showNasLogin)}>
                        <div className={`indicator ${systemStatus.includes("✅") ? 'online' : 'offline'}`}></div>
                        <span style={{ fontSize: '0.75rem', color: 'var(--text-secondary)' }}>
                            {systemStatus.includes("✅") ? "NAS Online" : "NAS Offline"}
                        </span>
                    </div>
                </div>

                <div className="nav-section" style={{ marginTop: 'auto' }}>
                    <button className="install-btn" onClick={handleBulkAction} disabled={loading || selectedApps.length === 0}>
                        <Download size={18} />
                        Run Selected ({selectedApps.length})
                    </button>
                    <AnimatePresence>
                        {loading && (
                            <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} className="progress-track">
                                <motion.div className="progress-fill" initial={{ width: 0 }} animate={{ width: `${progress}%` }} />
                            </motion.div>
                        )}
                    </AnimatePresence>
                </div>
            </aside>

            {/* Main Content */}
            <main className="main-content">
                <header className="top-bar">
                    <motion.div initial={{ opacity: 0, x: -20 }} animate={{ opacity: 1, x: 0 }}>
                        <h1 style={{ color: 'var(--text-primary)', fontSize: '2rem' }}>{activeTab}</h1>
                        <p style={{ color: 'var(--text-secondary)' }}>Automated workflows for Triveni Group.</p>
                    </motion.div>

                    <div className="search-container">
                        <Search size={18} color="var(--text-muted)" />
                        <input placeholder="Find task..." value={searchQuery} onChange={(e) => setSearchQuery(e.target.value)} />
                    </div>

                    <div className="header-actions">
                        <button
                            className={`action-icon-btn ${isRefreshing ? 'spinning' : ''}`}
                            onClick={refreshData}
                            title="Refresh Data"
                        >
                            <RefreshCcw size={18} />
                        </button>
                        <button
                            className="action-icon-btn"
                            onClick={toggleTheme}
                            title={isDarkMode ? "Switch to Light Mode" : "Switch to Dark Mode"}
                        >
                            {isDarkMode ? <Sun size={18} /> : <Moon size={18} />}
                        </button>
                    </div>
                </header>

                {(activeTab === "Software install" || activeTab === "Software config" || activeTab === "Security check" || activeTab === "Gmail Policy check") && (
                    <div className="bulk-actions-bar" style={{ display: 'flex', gap: '15px', marginBottom: '20px', alignItems: 'center' }}>
                        <button className="text-btn" onClick={selectAllInCategory}>
                            SELECT ALL IN {activeSubTab.toUpperCase()}
                        </button>
                        <button className="text-btn" onClick={() => setSelectedApps([])} disabled={selectedApps.length === 0}>
                            CLEAR SELECTION
                        </button>
                        {selectedApps.length > 0 && (
                            <>
                                <div className="selection-count">
                                    {selectedApps.length} TASKS SELECTED
                                </div>
                                <button
                                    className="install-btn"
                                    style={{ padding: '0.4rem 1.2rem', fontSize: '0.75rem', marginLeft: '10px' }}
                                    onClick={handleBulkAction}
                                    disabled={loading}
                                >
                                    <Download size={14} style={{ marginRight: '6px' }} />
                                    INSTALL ALL SELECTED
                                </button>
                            </>
                        )}
                    </div>
                )}

                {/* NAS Authentication Modal */}
                <AnimatePresence>
                    {showNasLogin && (
                        <motion.div
                            initial={{ opacity: 0 }}
                            animate={{ opacity: 1 }}
                            exit={{ opacity: 0 }}
                            className="modal-overlay"
                            onClick={() => setShowNasLogin(false)}
                        >
                            <motion.div
                                initial={{ scale: 0.9, opacity: 0 }}
                                animate={{ scale: 1, opacity: 1 }}
                                exit={{ scale: 0.9, opacity: 0 }}
                                className="software-card modal-content"
                                style={{ width: '450px', border: '1px solid var(--accent-primary)', background: 'var(--bg-card)' }}
                                onClick={(e) => e.stopPropagation()}
                            >
                                <div className="card-header">
                                    <span className="category-badge">NAS AUTHENTICATION</span>
                                    <div style={{ display: 'flex', gap: '10px', alignItems: 'center' }}>
                                        <Lock size={18} />
                                        <X
                                            size={20}
                                            className="clickable"
                                            onClick={() => setShowNasLogin(false)}
                                            style={{ color: 'var(--text-muted)' }}
                                        />
                                    </div>
                                </div>

                                {systemStatus.includes("✅") ? (
                                    <div style={{ textAlign: 'center', padding: '20px' }}>
                                        <Database size={40} color="var(--accent-primary)" style={{ marginBottom: '15px' }} />
                                        <p style={{ color: 'var(--accent-primary)', marginBottom: '20px', fontWeight: 600 }}>{systemStatus}</p>
                                        <button
                                            className="install-btn"
                                            style={{ background: 'var(--accent-warning)', border: 'none', width: '100%' }}
                                            onClick={() => {
                                                handleAction(DisconnectNAS());
                                                setShowNasLogin(false);
                                            }}
                                        >
                                            REMOVE CREDENTIALS & DISCONNECT
                                        </button>
                                    </div>
                                ) : (
                                    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px', padding: '10px' }}>
                                        <p style={{ fontSize: '0.9rem', color: 'var(--text-secondary)' }}>
                                            Enter credentials to mount the network drives.
                                        </p>
                                        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                                            <div className="search-container" style={{ width: '100%', margin: 0 }}>
                                                <input
                                                    className="setup-input"
                                                    style={{ width: '100%', margin: 0 }}
                                                    placeholder="NAS Username (e.g. USERNAME)"
                                                    value={nasUser}
                                                    onChange={e => setNasUser(e.target.value)}
                                                />
                                            </div>
                                            <div className="search-container" style={{ width: '100%', margin: 0 }}>
                                                <input
                                                    className="setup-input"
                                                    type="password"
                                                    style={{ width: '100%', margin: 0 }}
                                                    placeholder="Password"
                                                    value={nasPass}
                                                    onChange={e => setNasPass(e.target.value)}
                                                />
                                            </div>
                                        </div>
                                        <button
                                            className="install-btn"
                                            style={{ width: '100%' }}
                                            disabled={loading || !nasUser || !nasPass}
                                            onClick={() => {
                                                handleAction(ConnectNAS(nasUser, nasPass));
                                                setShowNasLogin(false);
                                            }}
                                        >
                                            CONNECT TO NAS
                                        </button>
                                    </div>
                                )}
                            </motion.div>
                        </motion.div>
                    )}
                </AnimatePresence>

                {activeTab === "System setup" ? (
                    <motion.div className="setup-view software-grid" initial={{ opacity: 0 }} animate={{ opacity: 1 }}>

                        {/* [ IDENTITY_MODULE ] */}
                        <div className="software-card" style={{ gridColumn: 'span 2' }}>
                            <div className="card-header"><span className="category-badge">[ IDENTITY_MODULE ]</span><RotateCcw size={18} /></div>
                            <div style={{ display: 'flex', alignItems: 'center', gap: '15px' }}>
                                <span style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', fontWeight: 600 }}>PC NAME :</span>
                                <input
                                    className="setup-input"
                                    placeholder="e.g. TGS-PC01"
                                    value={newName}
                                    style={{ marginBottom: 0, flex: 1 }}
                                    onChange={e => setNewName(e.target.value)}
                                />
                                <button className="install-btn" style={{ padding: '0.6rem 1.2rem' }} onClick={() => handleAction(RenamePC(newName))} disabled={loading || !newName}>
                                    APPLY NAME
                                </button>
                            </div>
                        </div>

                        {/* [ TEMPORAL_SYNC ] */}
                        <div className="software-card" style={{ gridColumn: 'span 2' }}>
                            <div className="card-header"><span className="category-badge">[ TEMPORAL_SYNC ]</span><Clock size={18} /></div>
                            <div style={{ display: 'flex', alignItems: 'center', gap: '15px' }}>
                                <span style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', fontWeight: 600 }}>ZONE : INDIA (12HR)</span>
                                <div style={{ flex: 1 }}></div>
                                <button className="install-btn" style={{ padding: '0.6rem 1.2rem' }} onClick={() => handleAction(SyncTime())} disabled={loading}>
                                    SYNC TIME
                                </button>
                            </div>
                        </div>

                        {/* [ DESKTOP__POWER ] */}
                        <div className="software-card" style={{ gridColumn: 'span 2' }}>
                            <div className="card-header"><span className="category-badge">[ DESKTOP__POWER ]</span><Zap size={18} /></div>

                            <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
                                <div style={{ display: 'flex', alignItems: 'center', gap: '15px' }}>
                                    <span style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', fontWeight: 600 }}>VISUALS :</span>
                                    <div style={{ display: 'flex', gap: '10px', flex: 1 }}>
                                        <input
                                            className="setup-input"
                                            placeholder="Wallpaper URL..."
                                            value={wallpaperUrl}
                                            style={{ marginBottom: 0 }}
                                            onChange={e => setWallpaperUrl(e.target.value)}
                                        />
                                        <button className="install-btn" style={{ padding: '0.6rem 1.2rem', whiteSpace: 'nowrap' }} onClick={() => handleAction(SetWallpaper(wallpaperUrl))} disabled={loading || !wallpaperUrl}>
                                            APPLY URL
                                        </button>
                                        <button className="install-btn" style={{ padding: '0.6rem 1.2rem', whiteSpace: 'nowrap', background: 'var(--accent-primary)', color: 'white' }} onClick={() => handleAction(SetBrandedWallpaper())} disabled={loading}>
                                            TGS BRANDING
                                        </button>
                                        <button className="install-btn" style={{ padding: '0.6rem 1.2rem', whiteSpace: 'nowrap' }} onClick={() => handleAction(ShowThisPCIcon())} disabled={loading}>
                                            THIS PC ICON
                                        </button>
                                    </div>
                                </div>

                                <div style={{ display: 'flex', alignItems: 'center', gap: '15px' }}>
                                    <span style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', fontWeight: 600 }}>SLEEP MODE :</span>
                                    <div style={{ display: 'flex', gap: '10px' }}>
                                        <button className="install-btn" style={{ padding: '0.5rem 1.5rem', background: 'transparent', border: '1px solid var(--accent-primary)' }} onClick={() => handleAction(SetSleepMode(60))} disabled={loading}>1 HR</button>
                                        <button className="install-btn" style={{ padding: '0.5rem 1.5rem', background: 'transparent', border: '1px solid var(--accent-primary)' }} onClick={() => handleAction(SetSleepMode(180))} disabled={loading}>3 HR</button>
                                        <button className="install-btn" style={{ padding: '0.5rem 1.5rem', background: 'transparent', border: '1px solid var(--accent-warning)', color: 'var(--accent-warning)' }} onClick={() => handleAction(SetSleepMode(0))} disabled={loading}>NEVER</button>
                                    </div>
                                </div>
                            </div>
                        </div>

                        {/* [ NETWORK_MODULE ] */}
                        <div className="software-card" style={{ gridColumn: 'span 2' }}>
                            <div className="card-header"><span className="category-badge">[ NETWORK_MODULE ]</span><Network size={18} /></div>
                            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr 1fr', gap: '10px', marginTop: '10px' }}>
                                <input className="setup-input" placeholder="IP" value={ipConfig.ip} onChange={e => setIpConfig({ ...ipConfig, ip: e.target.value })} />
                                <input className="setup-input" placeholder="Subnet" value={ipConfig.subnet} onChange={e => setIpConfig({ ...ipConfig, subnet: e.target.value })} />
                                <input className="setup-input" placeholder="Gateway" value={ipConfig.gateway} onChange={e => setIpConfig({ ...ipConfig, gateway: e.target.value })} />
                                <input className="setup-input" placeholder="DNS" value={ipConfig.dns} onChange={e => setIpConfig({ ...ipConfig, dns: e.target.value })} />
                            </div>
                            <div style={{ display: 'flex', gap: '10px', marginTop: '15px' }}>
                                <button className="install-btn" style={{ flex: 1 }} onClick={() => handleAction(SetStaticIP(ipConfig.ip, ipConfig.subnet, ipConfig.gateway, ipConfig.dns))} disabled={loading || !ipConfig.ip}>
                                    APPLY NETWORK CONFIG
                                </button>
                                <button className="install-btn" style={{ padding: '0.6rem 1.5rem', background: 'transparent', border: '1px solid var(--accent-primary)' }} onClick={() => handleAction(AllowPing())} disabled={loading}>
                                    ALLOW PING
                                </button>
                            </div>
                        </div>

                    </motion.div>
                ) : activeTab === "System Audit" ? (
                    <motion.div className="audit-view" initial={{ opacity: 0, scale: 0.98 }} animate={{ opacity: 1, scale: 1 }}>
                        <div className="stats-grid">
                            <div className="stat-card">
                                <div className="stat-icon"><Cpu size={24} /></div>
                                <div className="stat-info"><h4>Processor</h4><p>{hwInfo.cpu || "Detecting..."}</p></div>
                            </div>
                            <div className="stat-card">
                                <div className="stat-icon"><Database size={24} /></div>
                                <div className="stat-info"><h4>System RAM</h4><p>{hwInfo.ram || "Detecting..."}</p></div>
                            </div>
                            <div className="stat-card">
                                <div className="stat-icon"><Monitor size={24} /></div>
                                <div className="stat-info"><h4>OS Details</h4><p>{hwInfo.os || "Detecting..."}</p></div>
                            </div>
                            <div className="stat-card">
                                <div className="stat-icon"><Server size={24} /></div>
                                <div className="stat-info"><h4>Hostname</h4><p>{hwInfo.hostname || "Detecting..."}</p></div>
                            </div>
                            <div className="stat-card">
                                <div className="stat-icon"><Network size={24} /></div>
                                <div className="stat-info"><h4>IP Address</h4><p style={{ color: 'var(--accent-primary)', fontWeight: 700 }}>{hwInfo.ip || "Detecting..."}</p></div>
                            </div>
                            <div className="stat-card">
                                <div className="stat-icon"><HardDrive size={24} /></div>
                                <div className="stat-info"><h4>Disk Usage (C:)</h4><p>{hwInfo.disk || "Detecting..."}</p></div>
                            </div>
                        </div>
                    </motion.div>
                ) : (
                    <div className="software-grid-container">
                        {Object.entries(
                            filteredSoftwares.reduce((acc, sw) => {
                                const sub = sw.sub_category || "General";
                                if (!acc[sub]) acc[sub] = [];
                                acc[sub].push(sw);
                                return acc;
                            }, {} as Record<string, Software[]>)
                        ).map(([subCategory, apps]) => (
                            <div key={subCategory} className="software-section-group">
                                {activeTab === "Software install" && (
                                    <h2 className="section-divider">{subCategory.toUpperCase()}</h2>
                                )}
                                <div className="software-grid">
                                    <AnimatePresence mode="popLayout">
                                        {apps.map((sw) => (
                                            <motion.div
                                                key={sw.name} layout initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, scale: 0.95 }}
                                                className={`software-card ${selectedApps.includes(sw.name) ? 'selected' : ''} ${sw.is_installed ? 'installed' : ''}`}
                                                onClick={() => toggleSelection(sw.name)}
                                            >
                                                <div className="card-header">
                                                    <span className="category-badge">{sw.category}</span>
                                                    {sw.is_installed ? <CheckCircle2 color="var(--accent-success)" size={20} /> : <div className="checkbox-dummy" />}
                                                </div>
                                                <h3>{sw.name}</h3>
                                                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '8px' }}>
                                                    {sw.version && <span className="version-tag">{sw.version}</span>}
                                                    {installSource[sw.name] && (
                                                        <span style={{ fontSize: '0.75rem', color: 'var(--accent-primary)' }}>
                                                            {installSource[sw.name]}
                                                        </span>
                                                    )}
                                                </div>
                                                <div style={{ display: 'flex', gap: '8px', width: '100%', marginTop: 'auto' }}>
                                                    <button
                                                        onClick={(e) => { e.stopPropagation(); handleAction(InstallSoftware(sw.name), sw.name); }}
                                                        disabled={loading}
                                                        className="install-btn"
                                                        style={{
                                                            flex: 2,
                                                            position: 'relative',
                                                            overflow: 'hidden'
                                                        }}
                                                    >
                                                        {installProgress[sw.name] !== undefined && (
                                                            <div
                                                                className="button-progress-fill"
                                                                style={{
                                                                    width: `${installProgress[sw.name]}%`,
                                                                    position: 'absolute',
                                                                    left: 0,
                                                                    top: 0,
                                                                    bottom: 0,
                                                                    background: 'rgba(255, 255, 255, 0.2)',
                                                                    transition: 'width 0.3s ease',
                                                                    zIndex: 0
                                                                }}
                                                            />
                                                        )}
                                                        <span style={{ position: 'relative', zIndex: 1 }}>
                                                            {installProgress[sw.name] !== undefined
                                                                ? `Installing ${installProgress[sw.name]}%`
                                                                : (sw.is_installed ? "Already Installed" : "Install")}
                                                        </span>
                                                    </button>
                                                    {sw.is_installed && sw.uninstall_args?.length > 0 && (
                                                        <button
                                                            onClick={(e) => { e.stopPropagation(); handleAction(UninstallSoftware(sw.name), sw.name + "_uninstall"); }}
                                                            disabled={loading}
                                                            className="install-btn"
                                                            style={{
                                                                flex: 1,
                                                                background: 'rgba(239, 68, 68, 0.1)',
                                                                color: 'var(--accent-warning)',
                                                                border: '1px solid rgba(239, 68, 68, 0.2)',
                                                                position: 'relative',
                                                                overflow: 'hidden'
                                                            }}
                                                        >
                                                            {installProgress[sw.name + "_uninstall"] !== undefined && (
                                                                <div
                                                                    className="button-progress-fill"
                                                                    style={{
                                                                        width: `${installProgress[sw.name + "_uninstall"]}%`,
                                                                        position: 'absolute',
                                                                        left: 0,
                                                                        top: 0,
                                                                        bottom: 0,
                                                                        background: 'rgba(239, 68, 68, 0.3)',
                                                                        transition: 'width 0.3s ease',
                                                                        zIndex: 0
                                                                    }}
                                                                />
                                                            )}
                                                            <span style={{ position: 'relative', zIndex: 1 }}>
                                                                {installProgress[sw.name + "_uninstall"] !== undefined
                                                                    ? `Removing ${installProgress[sw.name + "_uninstall"]}%`
                                                                    : "REMOVE"}
                                                            </span>
                                                        </button>
                                                    )}
                                                    {sw.test_args && sw.test_args.length > 0 && (
                                                        <button
                                                            onClick={(e) => { e.stopPropagation(); handleTest(sw.name); }}
                                                            disabled={loading}
                                                            className="test-btn"
                                                            style={{
                                                                flex: 1,
                                                                background: 'rgba(56, 189, 248, 0.1)',
                                                                border: '1px solid rgba(56, 189, 248, 0.2)',
                                                                color: '#38bdf8',
                                                                padding: '10px',
                                                                borderRadius: '8px',
                                                                fontSize: '0.85rem',
                                                                fontWeight: '600',
                                                                cursor: 'pointer',
                                                                transition: 'all 0.2s',
                                                            }}
                                                        >
                                                            TEST
                                                        </button>
                                                    )}
                                                </div>
                                            </motion.div>
                                        ))}
                                    </AnimatePresence>
                                </div>
                            </div>
                        ))}
                        {filteredSoftwares.length === 0 && (
                            <motion.div className="empty-state" initial={{ opacity: 0 }} animate={{ opacity: 1 }} style={{ textAlign: 'center', padding: '4rem', color: 'var(--text-muted)' }}>
                                <AlertCircle size={48} style={{ marginBottom: '1rem', opacity: 0.5 }} />
                                <p>No tasks found in this category.</p>
                            </motion.div>
                        )}
                    </div>
                )}

                {/* Notifications */}
                <AnimatePresence>
                    {installLog && (
                        <motion.div className="notification-area" initial={{ opacity: 0, y: 50 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, scale: 0.95 }}>
                            <div className="toast">
                                {installLog.includes("Success") ? <CheckCircle2 size={20} color="var(--accent-success)" /> : <Activity size={20} className="brand-icon" />}
                                <span>{installLog}</span>
                            </div>
                        </motion.div>
                    )}
                </AnimatePresence>

                {/* Please Wait Overlay */}
                <AnimatePresence>
                    {loading && (
                        <motion.div
                            initial={{ opacity: 0 }}
                            animate={{ opacity: 1 }}
                            exit={{ opacity: 0 }}
                            style={{
                                position: 'fixed',
                                top: 0,
                                left: 0,
                                right: 0,
                                bottom: 0,
                                background: 'rgba(0, 0, 0, 0.7)',
                                backdropFilter: 'blur(8px)',
                                display: 'flex',
                                alignItems: 'center',
                                justifyContent: 'center',
                                zIndex: 9999,
                                flexDirection: 'column',
                                gap: '1.5rem'
                            }}
                        >
                            <motion.div
                                animate={{ rotate: 360 }}
                                transition={{ duration: 2, repeat: Infinity, ease: 'linear' }}
                            >
                                <Activity size={64} color="var(--accent-primary)" />
                            </motion.div>
                            <motion.h2
                                style={{
                                    color: 'var(--text-primary)',
                                    fontSize: '1.5rem',
                                    fontWeight: 600,
                                    letterSpacing: '1px'
                                }}
                                animate={{ opacity: [0.5, 1, 0.5] }}
                                transition={{ duration: 1.5, repeat: Infinity }}
                            >
                                Please Wait...
                            </motion.h2>
                            <p style={{ color: 'var(--text-secondary)', fontSize: '0.9rem' }}>
                                {installLog || "Processing your request..."}
                            </p>
                        </motion.div>
                    )}
                </AnimatePresence>

                {/* Floating Action Button for Bulk Install */}
                <AnimatePresence>
                    {selectedApps.length > 0 && (
                        <motion.div
                            className="fab-container"
                            initial={{ scale: 0, opacity: 0, y: 50 }}
                            animate={{ scale: 1, opacity: 1, y: 0 }}
                            exit={{ scale: 0, opacity: 0, y: 50 }}
                        >
                            <button className="fab-button" onClick={handleBulkAction} disabled={loading}>
                                <div className="fab-content">
                                    <Download size={24} />
                                    <div className="fab-text">
                                        <span>INSTALL SELECTED</span>
                                        <small>{selectedApps.length} Software Selected</small>
                                    </div>
                                </div>
                            </button>
                        </motion.div>
                    )}
                </AnimatePresence>
            </main>
        </div>
    )
}

export default App
