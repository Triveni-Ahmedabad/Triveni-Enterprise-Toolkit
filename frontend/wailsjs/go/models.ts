export namespace main {
	
	export class HardwareInfo {
	    cpu: string;
	    ram: string;
	    os: string;
	    hostname: string;
	    ip: string;
	    disk: string;
	
	    static createFrom(source: any = {}) {
	        return new HardwareInfo(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.cpu = source["cpu"];
	        this.ram = source["ram"];
	        this.os = source["os"];
	        this.hostname = source["hostname"];
	        this.ip = source["ip"];
	        this.disk = source["disk"];
	    }
	}
	export class Software {
	    name: string;
	    nas_path: string;
	    download_url: string;
	    install_args: string[];
	    description: string;
	    category: string;
	    sub_category: string;
	    uninstall_args: string[];
	    is_installed: boolean;
	    interactive: boolean;
	    version: string;
	    test_args: string[];
	    is_embedded: boolean;
	
	    static createFrom(source: any = {}) {
	        return new Software(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.name = source["name"];
	        this.nas_path = source["nas_path"];
	        this.download_url = source["download_url"];
	        this.install_args = source["install_args"];
	        this.description = source["description"];
	        this.category = source["category"];
	        this.sub_category = source["sub_category"];
	        this.uninstall_args = source["uninstall_args"];
	        this.is_installed = source["is_installed"];
	        this.interactive = source["interactive"];
	        this.version = source["version"];
	        this.test_args = source["test_args"];
	        this.is_embedded = source["is_embedded"];
	    }
	}

}

