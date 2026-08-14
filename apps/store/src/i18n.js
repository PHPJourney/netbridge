/** Store landing i18n — zh / en, persisted via localStorage */
export const LANG_KEY = "nbvpn-store-lang";

const dict = {
  zh: {
    "meta.title": "网桥 VPN — 自建节点，自行掌控",
    "meta.description": "网桥 VPN — 自建节点，自行掌控。无官方服务器，配置由你导入。",
    "skip": "跳到主要内容",
    "brand.home": "网桥 VPN 首页",
    "brand.name": "网桥 VPN",
    "nav.menu": "菜单",
    "nav.steps": "使用步骤",
    "nav.clients": "客户端",
    "nav.servers": "服务端",
    "nav.help": "使用帮助",
    "nav.responsibility": "责任说明",
    "lang.switch": "English",
    "lang.aria": "切换到 English",
    "hero.brand": "网桥 VPN",
    "hero.headline": "自建节点，自行掌控。",
    "hero.support": "无官方服务器，配置由你导入。",
    "hero.ctaClients": "下载客户端",
    "hero.ctaServers": "部署服务端",
    "steps.title": "三步开始",
    "steps.lead": "安装节点 → 拿到连接信息 → 客户端添加，无需账号。",
    "steps.1": "在 store 下载并安装服务端（Debian / Ubuntu / CentOS / RHEL）",
    "steps.2": "服务器执行安装后运行 <code>nbvpn show</code>，复制 URI 或扫终端二维码",
    "steps.3": "打开客户端添加服务器并连接",
    "clients.title": "下载客户端",
    "clients.lead": "Windows、Android 可下载；macOS 源码本机运行（暂不分发）；iOS 暂无签名包。版本与 SHA256 来自发布清单。",
    "servers.title": "部署服务端",
    "servers.lead":
      "Linux 四系与 Windows Server 安装入口。Rocky / Alma 使用 CentOS / RHEL 同一系说明。",
    "servers.secretTitle": "密钥提示",
    "servers.secretBody":
      "<code>nbvpn show</code> 给出的 URI / 二维码 / 配置文件等同于密钥，请勿公开发布。",
    "help.title": "使用帮助",
    "help.lead": "从零搭好节点到客户端连上：按下面顺序做即可，无需注册账号。",
    "help.toc.what": "是什么",
    "help.toc.flow": "三步流程",
    "help.toc.install": "安装服务端",
    "help.toc.commands": "常用命令",
    "help.toc.import": "导入客户端",
    "help.toc.network": "端口与网络",
    "help.toc.duty": "责任说明",
    "help.what.title": "网桥 VPN 是什么",
    "help.what.p1":
      "网桥 VPN（NetBridge）是<strong>去中心化</strong>的自建 VPN：节点跑在<strong>您自己的服务器</strong>上，用 WireGuard 隧道把手机/电脑接到该节点。",
    "help.what.li1":
      "<strong>没有官方公共节点</strong>——本站不提供「一键连公共服务器」。",
    "help.what.li2":
      "<strong>没有账号体系</strong>——不注册、不登录；连接信息由您在服务器上生成并导入客户端。",
    "help.what.li3": "下载页只提供客户端与服务端安装入口；密钥与配置始终由您掌控。",
    "help.flow.title": "三步流程（必读）",
    "help.flow.li1":
      "<strong>装服务端</strong>：在本页 <a href=\"#servers\">部署服务端</a> 选 Debian / Ubuntu / CentOS / RHEL，按一键命令安装。",
    "help.flow.li2":
      "<strong>拿连接信息</strong>：服务器上执行 <code>sudo nbvpn show</code>，得到 URI、终端二维码或配置文件（等同密钥，勿公开发布）。",
    "help.flow.li3":
      "<strong>客户端添加并连接</strong>：在手机/电脑安装 <a href=\"#clients\">客户端</a>，用 URI / 扫码 / 文件导入后连接。",
    "help.flow.note": "页顶「使用步骤」是同一流程的摘要；本区有更细的安装与排错说明。",
    "help.install.title": "安装服务端",
    "help.install.intro": "当前正式支持的服务端系统：",
    "help.install.li1": "<strong>Debian</strong> / <strong>Ubuntu</strong>（deb 系一键脚本）",
    "help.install.li2": "<strong>CentOS</strong> / <strong>RHEL</strong>（含 Rocky / Alma 等同系）",
    "help.install.li3":
      "<strong>Windows Server</strong>（推荐下载 <code>Setup.exe</code>；高级可用 PowerShell 一键 / <code>install.ps1</code>）",
    "help.install.body":
      "到 <a href=\"#servers\">部署服务端</a>：Linux 复制一键命令以 root / <code>sudo</code> 执行；Windows 优先下载 Setup.exe 并以管理员运行（高级折叠内有 PowerShell 一键）。安装完成后会配置首个客户端 peer，并尽量启用服务。",
    "help.install.winTitle": "Windows 服务端 MVP",
    "help.install.winBody":
      "在 <a href=\"#servers\">部署服务端</a> 的 Windows 卡片：大多数用户只下载 <strong>Setup.exe</strong>，右键「以管理员身份运行」。无 GUI / Server 2012 展开「高级」用 PowerShell 一键（<code>bootstrap.ps1</code>）或手动链接。请安装 <a href=\"https://www.wireguard.com/install/\" rel=\"noopener noreferrer\">WireGuard for Windows</a> 后再开真隧道。数据目录：<code>explorer %ProgramData%\\nbvpn</code>。详见 <code>WINDOWS.md</code>。",
    "help.commands.title": "nbvpn 常用命令",
    "help.commands.intro": "安装完成后，在服务器终端执行（多数环境需 <code>sudo</code>）：",
    "help.commands.d1": "首次安装 / 修复配置，生成节点与首个客户端配置并尽量启用服务。",
    "help.commands.d2":
      "显示连接信息（默认 URI + 二维码 + 文件）。也可用 <code>nbvpn show --uri</code> / <code>--qr</code> / <code>--file</code>。",
    "help.commands.d3": "查看服务 / 隧道是否在运行。",
    "help.commands.d4": "启动 WireGuard 服务。",
    "help.commands.d5": "停止服务。",
    "help.commands.d6":
      "为另一台设备再加一个客户端；可带名字，例如 <code>sudo nbvpn peer add phone</code>。添加后会再次展示该 peer 的 URI / 二维码 / 文件。",
    "help.commands.note":
      "若公网 IP 检测失败，客户端连不上时请设置入口： <code>sudo nbvpn config set endpoint &lt;公网IP或域名&gt;</code>（可选端口，默认见下节）。",
    "help.import.title": "客户端如何导入",
    "help.import.intro": "在电脑或手机安装网桥 VPN 客户端后，任选一种方式添加服务器：",
    "help.import.li1":
      "<strong>URI</strong>：在服务器执行 <code>sudo nbvpn show --uri</code>，把整段 URI 粘贴到客户端「添加服务器」。",
    "help.import.li2":
      "<strong>二维码</strong>：执行 <code>sudo nbvpn show</code>（或 <code>--qr</code>），用手机客户端扫描终端里的二维码（桌面端若无相机，请改用 URI / 文件）。",
    "help.import.li3":
      "<strong>配置文件</strong>：用 <code>nbvpn show --file</code> 得到的 <code>.nbvpn.json</code>（或客户端支持的导入文件）拷到设备后选择「从文件导入」。",
    "help.import.secretTitle": "密钥警告",
    "help.import.secretBody":
      "URI、二维码、配置文件都含客户端私钥，等同于密码。不要发到公开群、截图到社交网络，也不要提交到代码仓库。",
    "help.network.title": "端口、防火墙与 NAT",
    "help.network.li1":
      "默认监听 <strong>UDP 51820</strong>。请在<strong>主机防火墙</strong>与<strong>云厂商安全组</strong>同时放行该端口（只开 UDP，不要只开 TCP）。",
    "help.network.li2":
      "安装脚本会尽量开启 <strong>IP 转发（ip_forward）</strong> 与 <strong>MASQUERADE（NAT）</strong>，让客户端流量经节点出口。若服务器已启用 ufw，还需按安装完成后的终端提示放行转发规则。",
    "help.network.li3":
      "连不上时优先检查：安全组是否放行 UDP 51820 → <code>nbvpn status</code> 是否在跑 → <code>nbvpn show</code> 里的 endpoint 是否为真实可达的公网地址。",
    "help.duty.title": "责任说明",
    "help.duty.body":
      "节点部署在<strong>您的服务器</strong>上。出口网络行为与合法合规使用，责任由您自行承担。本产品<strong>不提供</strong>公共 VPN 节点，也不代管您的流量。更多摘要见 <a href=\"#responsibility\">责任与去中心化</a>。",
    "responsibility.title": "责任与去中心化",
    "responsibility.copy":
      "节点部署在您的服务器上。出口网络与合法使用责任由您自行承担。本产品不提供公共 VPN 节点。",
    "footer.meta": "版本与校验和见 <a href=\"./releases.json\">releases.json</a>。下载后请核对 SHA256。",
    "footer.note": "无登录 · 无官方节点列表 · 配置由你导入",
    "footer.partners": "合作伙伴",
    "footer.terms": "用户协议",
    "footer.privacy": "隐私政策",
    "footer.legal": "法律信息",
    "dl.version": "版本",
    "dl.shaPending": "上传后更新",
    "dl.download": "下载",
    "dl.downloadPkg": "下载安装包",
    "dl.downloadInstallScript": "下载安装脚本",
    "dl.downloadInstallPs1": "下载 install.ps1（高级）",
    "dl.downloadWinSetup": "下载安装包 Setup.exe",
    "dl.downloadWinExe": "下载 nbvpn-windows-amd64.exe",
    "dl.downloadWin2012Exe": "下载 nbvpn-windows-amd64-win2012.exe",
    "dl.downloadWinPortable": "下载便携版 zip",
    "dl.downloadDocs": "查看 WINDOWS.md",
    "dl.linkInstallPs1": "install.ps1",
    "dl.linkWin2012Exe": "win2012 exe",
    "dl.linkWinExe": "nbvpn-windows-amd64.exe",
    "dl.linkWindowsMd": "WINDOWS.md",
    "dl.windowsSetupHint": "下载后右键「以管理员身份运行」安装。无需命令行。",
    "dl.windowsAdvanced": "高级 / 无 GUI",
    "dl.windowsBootstrapHint": "PowerShell 一键（管理员；自动识别 2012 与新系统）：",
    "dl.windowsSameFolder": "若不用 Setup.exe：请将 install.ps1 与对应 exe 放在同一文件夹后再执行。",
    "dl.windowsSetupPrimary": "推荐下载 Setup.exe 安装；install.ps1 仅作高级/2012 备用。",
    "dl.uploadPending": "上传后更新",
    "dl.localSource": "源码本机运行 / 暂不分发",
    "dl.localSourceNote": "请用仓库源码：cd clients/netbridge && flutter run -d macos。真 VPN 隧道见 TRY-CONNECT「本机 macOS 业务」。",
    "dl.skippedSigning": "暂无签名包",
    "dl.skippedSigningNote": "CI 不产出可安装签名包。",
    "dl.pendingNote": "产物上传到 OpenList 后更新下载链接",
    "dl.clientUnavailable": "客户端暂时不可用 · 校验说明仍可见",
    "dl.serverUnavailable": "服务端暂时不可用 · 校验说明仍可见",
    "dl.loadClientsError": "客户端发布信息暂时不可用。校验说明仍见页脚 releases.json。",
    "dl.loadServersError": "服务端发布信息暂时不可用。校验说明仍见页脚 releases.json。",
    "dl.copy": "复制",
    "dl.copied": "已复制",
    "dl.copyFail": "失败",
    "partner.trademind": "TradeMind",
    "partner.tmOpen": "TM 开放平台",
    "legal.back": "返回下载站",
    "terms.title": "用户协议",
    "terms.lead": "使用网桥 VPN（NetBridge）即表示您理解并同意以下条款摘要。",
    "terms.p1":
      "网桥 VPN 是去中心化的自建 VPN 工具：节点部署在您自己的服务器上，本站不提供公共节点，也不代管您的流量。",
    "terms.p2":
      "您须自行确保对服务器、网络出口及所传输内容的合法合规使用。因不当使用产生的责任由您自行承担。",
    "terms.p3":
      "连接信息（URI、二维码、配置文件）含密钥材料，请妥善保管，勿公开发布。",
    "terms.p4": "本页为摘要占位；正式法律文本可由运营方替换。联系与官方站点见 releases.json 中的 meta.officialSite。",
    "privacy.title": "隐私政策",
    "privacy.lead": "网桥 VPN 下载站尽量少收集信息。",
    "privacy.p1":
      "本静态下载站不要求注册或登录，不运营账号体系，也不提供「一键连公共服务器」。",
    "privacy.p2":
      "版本与下载链接来自公开的 releases.json；安装包由您从配置的存储（如 OpenList）获取。密钥与隧道配置仅在您的服务器与客户端之间生成与使用。",
    "privacy.p3":
      "语言偏好仅保存在您浏览器的 localStorage（键名 nbvpn-store-lang），不会上传到本站服务器。",
    "privacy.p4": "本页为摘要占位；正式隐私政策可由运营方替换。官方站点见 meta.officialSite。",
  },
  en: {
    "meta.title": "NetBridge VPN — Your nodes, your control",
    "meta.description":
      "NetBridge VPN — self-hosted nodes under your control. No official servers; you import the config.",
    "skip": "Skip to main content",
    "brand.home": "NetBridge VPN home",
    "brand.name": "NetBridge VPN",
    "nav.menu": "Menu",
    "nav.steps": "Get started",
    "nav.clients": "Clients",
    "nav.servers": "Servers",
    "nav.help": "Help",
    "nav.responsibility": "Responsibility",
    "lang.switch": "中文",
    "lang.aria": "Switch to 中文",
    "hero.brand": "NetBridge VPN",
    "hero.headline": "Your nodes, your control.",
    "hero.support": "No official servers — you import the config.",
    "hero.ctaClients": "Download clients",
    "hero.ctaServers": "Deploy server",
    "steps.title": "Three steps",
    "steps.lead": "Install a node → get connection info → add it in the client. No account needed.",
    "steps.1": "Download and install the server from this store (Debian / Ubuntu / CentOS / RHEL)",
    "steps.2":
      "After install, run <code>nbvpn show</code> on the server, then copy the URI or scan the terminal QR code",
    "steps.3": "Open the client, add the server, and connect",
    "clients.title": "Download clients",
    "clients.lead": "Windows and Android downloads; macOS is local-source only (not distributed); iOS has no signed package yet. Versions and SHA256 come from the release manifest.",
    "servers.title": "Deploy server",
    "servers.lead":
      "Linux (four families) and Windows Server install entry points. Rocky / Alma follow the CentOS / RHEL notes.",
    "servers.secretTitle": "Secret tip",
    "servers.secretBody":
      "The URI / QR code / config from <code>nbvpn show</code> is equivalent to a secret — do not publish it.",
    "help.title": "Help",
    "help.lead":
      "From a fresh node to a connected client: follow the order below. No registration required.",
    "help.toc.what": "What it is",
    "help.toc.flow": "Three-step flow",
    "help.toc.install": "Install server",
    "help.toc.commands": "Commands",
    "help.toc.import": "Import client",
    "help.toc.network": "Ports & network",
    "help.toc.duty": "Responsibility",
    "help.what.title": "What is NetBridge VPN",
    "help.what.p1":
      "NetBridge VPN is a <strong>decentralized</strong>, self-hosted VPN: the node runs on <strong>your own server</strong>, and WireGuard tunnels your phone/computer to that node.",
    "help.what.li1":
      "<strong>No official public nodes</strong> — this site does not offer one-click public servers.",
    "help.what.li2":
      "<strong>No accounts</strong> — no sign-up or login; you generate connection info on the server and import it into the client.",
    "help.what.li3":
      "This download page only ships client and server install entry points; keys and config stay under your control.",
    "help.flow.title": "Three-step flow (required)",
    "help.flow.li1":
      "<strong>Install the server</strong>: on this page open <a href=\"#servers\">Deploy server</a>, pick Debian / Ubuntu / CentOS / RHEL, and run the one-liner.",
    "help.flow.li2":
      "<strong>Get connection info</strong>: on the server run <code>sudo nbvpn show</code> for a URI, terminal QR code, or config file (treat as a secret — do not publish).",
    "help.flow.li3":
      "<strong>Add and connect</strong>: install the <a href=\"#clients\">client</a> on your device, import via URI / QR / file, then connect.",
    "help.flow.note":
      "The top “Get started” strip is the same flow in brief; this section has more install and troubleshooting detail.",
    "help.install.title": "Install the server",
    "help.install.intro": "Currently supported server systems:",
    "help.install.li1": "<strong>Debian</strong> / <strong>Ubuntu</strong> (deb-family one-liner)",
    "help.install.li2": "<strong>CentOS</strong> / <strong>RHEL</strong> (including Rocky / Alma)",
    "help.install.li3":
      "<strong>Windows Server</strong> (prefer <code>Setup.exe</code>; advanced: PowerShell one-liner / <code>install.ps1</code>)",
    "help.install.body":
      "Go to <a href=\"#servers\">Deploy server</a>: on Linux copy the one-liner and run as root / <code>sudo</code>; on Windows download Setup.exe and run as Administrator (advanced fold has a PowerShell one-liner). Install configures the first client peer and tries to enable the service.",
    "help.install.winTitle": "Windows server MVP",
    "help.install.winBody":
      "On the Windows card under <a href=\"#servers\">Deploy server</a>: most users only download <strong>Setup.exe</strong> and run as Administrator. Headless / Server 2012: expand Advanced for the PowerShell one-liner (<code>bootstrap.ps1</code>) or manual links. Install <a href=\"https://www.wireguard.com/install/\" rel=\"noopener noreferrer\">WireGuard for Windows</a> before a real tunnel. Data: <code>explorer %ProgramData%\\nbvpn</code>. See <code>WINDOWS.md</code>.",
    "help.commands.title": "Common nbvpn commands",
    "help.commands.intro":
      "After install, run these in a server shell (most environments need <code>sudo</code>):",
    "help.commands.d1":
      "First-time install / repair config; generate the node and first client config and try to enable the service.",
    "help.commands.d2":
      "Show connection info (URI + QR + file by default). Also <code>nbvpn show --uri</code> / <code>--qr</code> / <code>--file</code>.",
    "help.commands.d3": "Check whether the service / tunnel is running.",
    "help.commands.d4": "Start the WireGuard service.",
    "help.commands.d5": "Stop the service.",
    "help.commands.d6":
      "Add another client device; optional name, e.g. <code>sudo nbvpn peer add phone</code>. Shows that peer’s URI / QR / file again.",
    "help.commands.note":
      "If public IP detection fails and clients cannot connect, set the endpoint: <code>sudo nbvpn config set endpoint &lt;public-IP-or-hostname&gt;</code> (optional port; defaults in the next section).",
    "help.import.title": "How to import into the client",
    "help.import.intro":
      "After installing the NetBridge VPN client on desktop or mobile, add a server using any of:",
    "help.import.li1":
      "<strong>URI</strong>: on the server run <code>sudo nbvpn show --uri</code> and paste the full URI into the client’s “Add server”.",
    "help.import.li2":
      "<strong>QR code</strong>: run <code>sudo nbvpn show</code> (or <code>--qr</code>) and scan the terminal QR with the phone client (use URI / file on desktop if there is no camera).",
    "help.import.li3":
      "<strong>Config file</strong>: take the <code>.nbvpn.json</code> (or supported import file) from <code>nbvpn show --file</code>, copy it to the device, and choose “Import from file”.",
    "help.import.secretTitle": "Secret warning",
    "help.import.secretBody":
      "URI, QR, and config files contain the client private key — treat them like a password. Do not post them in public chats, social screenshots, or git repos.",
    "help.network.title": "Ports, firewall, and NAT",
    "help.network.li1":
      "Default listen port is <strong>UDP 51820</strong>. Allow it on both the <strong>host firewall</strong> and the <strong>cloud security group</strong> (UDP only — not TCP alone).",
    "help.network.li2":
      "Install scripts try to enable <strong>IP forwarding (ip_forward)</strong> and <strong>MASQUERADE (NAT)</strong> so client traffic exits via the node. If ufw is already on, follow the post-install tips to allow forwarding.",
    "help.network.li3":
      "If you cannot connect, check first: security group allows UDP 51820 → <code>nbvpn status</code> is running → endpoint in <code>nbvpn show</code> is a reachable public address.",
    "help.duty.title": "Responsibility",
    "help.duty.body":
      "The node runs on <strong>your server</strong>. You are responsible for egress traffic and lawful use. This product <strong>does not</strong> provide public VPN nodes or proxy your traffic. See also <a href=\"#responsibility\">Responsibility & decentralization</a>.",
    "responsibility.title": "Responsibility & decentralization",
    "responsibility.copy":
      "The node runs on your server. You own egress and lawful-use responsibility. This product does not provide public VPN nodes.",
    "footer.meta":
      "Versions and checksums live in <a href=\"./releases.json\">releases.json</a>. Verify SHA256 after download.",
    "footer.note": "No login · no official node list · you import the config",
    "footer.partners": "Partners",
    "footer.terms": "Terms of use",
    "footer.privacy": "Privacy policy",
    "footer.legal": "Legal",
    "dl.version": "Version",
    "dl.shaPending": "Update after upload",
    "dl.download": "Download",
    "dl.downloadPkg": "Download package",
    "dl.downloadInstallScript": "Download install script",
    "dl.downloadInstallPs1": "Download install.ps1 (advanced)",
    "dl.downloadWinSetup": "Download Setup.exe",
    "dl.downloadWinExe": "Download nbvpn-windows-amd64.exe",
    "dl.downloadWin2012Exe": "Download nbvpn-windows-amd64-win2012.exe",
    "dl.downloadWinPortable": "Download portable zip",
    "dl.downloadDocs": "Open WINDOWS.md",
    "dl.linkInstallPs1": "install.ps1",
    "dl.linkWin2012Exe": "win2012 exe",
    "dl.linkWinExe": "nbvpn-windows-amd64.exe",
    "dl.linkWindowsMd": "WINDOWS.md",
    "dl.windowsSetupHint": "After download, right-click → Run as administrator. No command line needed.",
    "dl.windowsAdvanced": "Advanced / headless",
    "dl.windowsBootstrapHint": "PowerShell one-liner (elevated; detects 2012 vs newer):",
    "dl.windowsSameFolder": "If not using Setup.exe: put install.ps1 and the matching exe in the same folder, then run install.",
    "dl.windowsSetupPrimary": "Prefer Setup.exe. install.ps1 is advanced / Server 2012 only.",
    "dl.uploadPending": "Update after upload",
    "dl.localSource": "Source / local only — not distributed",
    "dl.localSourceNote": "Run from repo: cd clients/netbridge && flutter run -d macos. Real VPN tunnel: see TRY-CONNECT macOS local business section.",
    "dl.skippedSigning": "No signed package yet",
    "dl.skippedSigningNote": "CI does not produce an installable signed package.",
    "dl.pendingNote": "Update the download URL after uploading artifacts to OpenList",
    "dl.clientUnavailable": "Client temporarily unavailable · checksum notes still apply",
    "dl.serverUnavailable": "Server temporarily unavailable · checksum notes still apply",
    "dl.loadClientsError":
      "Client release info is temporarily unavailable. See footer releases.json for checksum notes.",
    "dl.loadServersError":
      "Server release info is temporarily unavailable. See footer releases.json for checksum notes.",
    "dl.copy": "Copy",
    "dl.copied": "Copied",
    "dl.copyFail": "Failed",
    "partner.trademind": "TradeMind",
    "partner.tmOpen": "TM Open Platform",
    "legal.back": "Back to download site",
    "terms.title": "Terms of use",
    "terms.lead": "By using NetBridge VPN you acknowledge the following summary.",
    "terms.p1":
      "NetBridge VPN is a decentralized, self-hosted VPN tool: nodes run on your servers. This site does not offer public nodes or proxy your traffic.",
    "terms.p2":
      "You must ensure lawful use of your servers, network egress, and transmitted content. You are solely responsible for misuse.",
    "terms.p3":
      "Connection material (URI, QR, config files) contains secrets — keep it private; do not publish it.",
    "terms.p4":
      "This page is a placeholder summary; operators may replace it with formal legal text. Official site: meta.officialSite in releases.json.",
    "privacy.title": "Privacy policy",
    "privacy.lead": "The NetBridge download site collects as little as practical.",
    "privacy.p1":
      "This static download site requires no registration or login, runs no account system, and does not offer one-click public servers.",
    "privacy.p2":
      "Versions and download links come from the public releases.json; packages are fetched from your configured storage (e.g. OpenList). Keys and tunnel config are created only between your server and clients.",
    "privacy.p3":
      "Language preference is stored only in your browser’s localStorage (key nbvpn-store-lang) and is not uploaded to this site.",
    "privacy.p4":
      "This page is a placeholder summary; operators may replace it with a formal policy. Official site: meta.officialSite.",
  },
};

/** @returns {'zh'|'en'} */
export function getLang() {
  try {
    const saved = localStorage.getItem(LANG_KEY);
    if (saved === "en" || saved === "zh") return saved;
  } catch {
    /* ignore */
  }
  return "zh";
}

/** @param {'zh'|'en'} lang */
export function setLang(lang) {
  const next = lang === "en" ? "en" : "zh";
  try {
    localStorage.setItem(LANG_KEY, next);
  } catch {
    /* ignore */
  }
  return next;
}

export function t(key, lang = getLang()) {
  const table = dict[lang] || dict.zh;
  return table[key] ?? dict.zh[key] ?? key;
}

export function applyI18n(root = document, lang = getLang()) {
  document.documentElement.lang = lang === "en" ? "en" : "zh-CN";

  root.querySelectorAll("[data-i18n]").forEach((el) => {
    const key = el.getAttribute("data-i18n");
    if (!key) return;
    el.textContent = t(key, lang);
  });

  root.querySelectorAll("[data-i18n-html]").forEach((el) => {
    const key = el.getAttribute("data-i18n-html");
    if (!key) return;
    el.innerHTML = t(key, lang);
  });

  root.querySelectorAll("[data-i18n-aria]").forEach((el) => {
    const key = el.getAttribute("data-i18n-aria");
    if (!key) return;
    el.setAttribute("aria-label", t(key, lang));
  });

  root.querySelectorAll("[data-i18n-meta]").forEach((el) => {
    const key = el.getAttribute("data-i18n-meta");
    if (!key) return;
    if (el.tagName === "TITLE") {
      el.textContent = t(key, lang);
    } else if (el.getAttribute("name") === "description") {
      el.setAttribute("content", t(key, lang));
    }
  });
}

export function initLangToggle(onChange) {
  const btn = document.querySelector("[data-lang-toggle]");
  if (!btn) return;

  const syncBtn = (lang) => {
    btn.textContent = t("lang.switch", lang);
    btn.setAttribute("aria-label", t("lang.aria", lang));
  };

  syncBtn(getLang());

  btn.addEventListener("click", () => {
    const next = setLang(getLang() === "zh" ? "en" : "zh");
    applyI18n(document, next);
    syncBtn(next);
    if (typeof onChange === "function") onChange(next);
  });
}
