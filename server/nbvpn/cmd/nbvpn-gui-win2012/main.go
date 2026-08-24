//go:build windows

// NetBridge nbvpn GUI for Server 2012 / 2012 R2.
// Pure Win32 via syscall (CGO_ENABLED=0) — no Fyne, no MinGW CRT → avoids CreateProcess 14001.
package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"unsafe"

	"github.com/netbridge/nbvpn/internal/qr"
	qrcode "github.com/skip2/go-qrcode"
)

// Set via: go build -ldflags "-X main.version=…"
var version = "1.0.0"

var (
	user32               = syscall.NewLazyDLL("user32.dll")
	kernel32             = syscall.NewLazyDLL("kernel32.dll")
	shell32              = syscall.NewLazyDLL("shell32.dll")
	procRegisterClassEx   = user32.NewProc("RegisterClassExW")
	procCreateWindowEx    = user32.NewProc("CreateWindowExW")
	procDefWindowProc     = user32.NewProc("DefWindowProcW")
	procShowWindow        = user32.NewProc("ShowWindow")
	procUpdateWindow      = user32.NewProc("UpdateWindow")
	procGetMessage        = user32.NewProc("GetMessageW")
	procTranslateMessage  = user32.NewProc("TranslateMessage")
	procDispatchMessage   = user32.NewProc("DispatchMessageW")
	procPostQuitMessage   = user32.NewProc("PostQuitMessage")
	procSetWindowText     = user32.NewProc("SetWindowTextW")
	procMessageBox        = user32.NewProc("MessageBoxW")
	procGetModuleHandle   = kernel32.NewProc("GetModuleHandleW")
	procShellExecute      = shell32.NewProc("ShellExecuteW")
	procOpenClipboard     = user32.NewProc("OpenClipboard")
	procCloseClipboard    = user32.NewProc("CloseClipboard")
	procEmptyClipboard    = user32.NewProc("EmptyClipboard")
	procSetClipboardData  = user32.NewProc("SetClipboardData")
	procGlobalAlloc       = kernel32.NewProc("GlobalAlloc")
	procGlobalLock        = kernel32.NewProc("GlobalLock")
	procGlobalUnlock      = kernel32.NewProc("GlobalUnlock")
)

const (
	wsOverlappedWindow = 0x00CF0000
	wsVisible          = 0x10000000
	wsChild            = 0x40000000
	wsTabstop          = 0x00010000
	wsBorder           = 0x00800000
	wsVScroll          = 0x00200000
	wsHScroll          = 0x00100000
	esMultiline        = 0x0004
	esReadonly         = 0x0800
	esAutovScroll      = 0x0040
	esWantReturn       = 0x1000
	swShow             = 5
	wmDestroy          = 0x0002
	wmCommand          = 0x0111
	wmSetFont          = 0x0030
	bnClicked          = 0
	idiApplication     = 32512
	idcArrow           = 32512
	colorWindow        = 5
	cfUnicodeText      = 13
	gmemMoveable       = 0x0002
)

const (
	idStatusEdit = 1001
	idBtnRefresh = 1002
	idBtnStart   = 1003
	idBtnStop    = 1004
	idBtnPeers   = 1005
	idBtnURI     = 1006
	idBtnCopyURI = 1007
	idBtnQR      = 1008
	idBtnData    = 1009
	idBtnAddPeer = 1010
	idBtnHelp    = 1011
)

type wndClassEx struct {
	size       uint32
	style      uint32
	wndProc    uintptr
	clsExtra   int32
	wndExtra   int32
	instance   syscall.Handle
	icon       syscall.Handle
	cursor     syscall.Handle
	background syscall.Handle
	menuName   *uint16
	className  *uint16
	iconSm     syscall.Handle
}

type point struct{ x, y int32 }
type msg struct {
	hwnd    syscall.Handle
	message uint32
	wParam  uintptr
	lParam  uintptr
	time    uint32
	pt      point
}

var (
	nbvpnPath string
	hwndMain  syscall.Handle
	hwndEdit  syscall.Handle
	lastURI   string
)

func utf16Ptr(s string) *uint16 {
	p, _ := syscall.UTF16PtrFromString(s)
	return p
}

func main() {
	var err error
	nbvpnPath, err = findNbvpn()
	if err != nil {
		msgBox("NetBridge nbvpn", "找不到 nbvpn.exe。\n请与本程序放在同一目录，或先运行 Setup-win2012。\n\n"+err.Error())
		os.Exit(1)
	}

	className := utf16Ptr("NetBridgeNbvpnGuiWin2012")
	hInst, _, _ := procGetModuleHandle.Call(0)
	loadCursor := user32.NewProc("LoadCursorW")
	hCursor, _, _ := loadCursor.Call(0, uintptr(idcArrow))
	// Embedded RT_GROUP_ICON from resource_windows_amd64.syso (goversioninfo → ID 1).
	loadIcon := user32.NewProc("LoadIconW")
	hIcon, _, _ := loadIcon.Call(hInst, 1)
	if hIcon == 0 {
		hIcon, _, _ = loadIcon.Call(0, uintptr(idiApplication))
	}

	var wc wndClassEx
	wc.size = uint32(unsafe.Sizeof(wc))
	wc.wndProc = syscall.NewCallback(wndProc)
	wc.instance = syscall.Handle(hInst)
	wc.icon = syscall.Handle(hIcon)
	wc.iconSm = syscall.Handle(hIcon)
	wc.cursor = syscall.Handle(hCursor)
	wc.background = colorWindow + 1
	wc.className = className
	atom, _, err2 := procRegisterClassEx.Call(uintptr(unsafe.Pointer(&wc)))
	if atom == 0 {
		msgBox("NetBridge nbvpn", "RegisterClassEx failed: "+err2.Error())
		os.Exit(1)
	}

	title := utf16Ptr("NetBridge nbvpn 管理 (Server 2012)")
	hwnd, _, _ := procCreateWindowEx.Call(
		0,
		uintptr(unsafe.Pointer(className)),
		uintptr(unsafe.Pointer(title)),
		wsOverlappedWindow|wsVisible,
		200, 120, 640, 520,
		0, 0, hInst, 0,
	)
	if hwnd == 0 {
		msgBox("NetBridge nbvpn", "CreateWindow failed")
		os.Exit(1)
	}
	hwndMain = syscall.Handle(hwnd)
	// WM_SETICON large/small — ensure title bar / Alt-Tab use embedded icon.
	const wmSetIcon = 0x0080
	const iconBig, iconSmall = 1, 0
	sendMsg := user32.NewProc("SendMessageW")
	sendMsg.Call(hwnd, wmSetIcon, iconBig, hIcon)
	sendMsg.Call(hwnd, wmSetIcon, iconSmall, hIcon)
	procShowWindow.Call(hwnd, swShow)
	procUpdateWindow.Call(hwnd)
	setEditText("正在加载状态…\r\n")
	go refreshStatus()

	var m msg
	for {
		ret, _, _ := procGetMessage.Call(uintptr(unsafe.Pointer(&m)), 0, 0, 0)
		if int32(ret) <= 0 {
			break
		}
		procTranslateMessage.Call(uintptr(unsafe.Pointer(&m)))
		procDispatchMessage.Call(uintptr(unsafe.Pointer(&m)))
	}
}

func wndProc(hwnd syscall.Handle, msgU uint32, wParam, lParam uintptr) uintptr {
	switch msgU {
	case 0x0001: // WM_CREATE
		createControls(hwnd)
		return 0
	case wmCommand:
		id := wParam & 0xffff
		notify := (wParam >> 16) & 0xffff
		if notify == bnClicked || notify == 0 {
			handleCommand(uint16(id))
		}
		return 0
	case wmDestroy:
		procPostQuitMessage.Call(0)
		return 0
	}
	r, _, _ := procDefWindowProc.Call(uintptr(hwnd), uintptr(msgU), wParam, lParam)
	return r
}

func createControls(parent syscall.Handle) {
	hInst, _, _ := procGetModuleHandle.Call(0)
	mkBtn := func(id int, title string, x, y, w, h int) {
		procCreateWindowEx.Call(
			0,
			uintptr(unsafe.Pointer(utf16Ptr("BUTTON"))),
			uintptr(unsafe.Pointer(utf16Ptr(title))),
			wsChild|wsVisible|wsTabstop,
			uintptr(x), uintptr(y), uintptr(w), uintptr(h),
			uintptr(parent), uintptr(id), hInst, 0,
		)
	}
	mkBtn(idBtnRefresh, "刷新状态", 12, 12, 100, 28)
	mkBtn(idBtnStart, "启动", 120, 12, 80, 28)
	mkBtn(idBtnStop, "停止", 208, 12, 80, 28)
	mkBtn(idBtnPeers, "Peer 列表", 296, 12, 100, 28)
	mkBtn(idBtnURI, "显示 URI", 404, 12, 100, 28)
	mkBtn(idBtnCopyURI, "复制 URI", 12, 48, 100, 28)
	mkBtn(idBtnQR, "显示 QR", 120, 48, 80, 28)
	mkBtn(idBtnData, "数据目录", 208, 48, 100, 28)
	mkBtn(idBtnAddPeer, "添加 Peer", 316, 48, 100, 28)
	mkBtn(idBtnHelp, "说明", 424, 48, 80, 28)

	style := wsChild | wsVisible | wsBorder | wsVScroll | wsHScroll | esMultiline | esReadonly | esAutovScroll | esWantReturn
	h, _, _ := procCreateWindowEx.Call(
		0,
		uintptr(unsafe.Pointer(utf16Ptr("EDIT"))),
		0,
		uintptr(style),
		12, 88, 600, 360,
		uintptr(parent), idStatusEdit, hInst, 0,
	)
	hwndEdit = syscall.Handle(h)
}

func handleCommand(id uint16) {
	switch id {
	case idBtnRefresh:
		go refreshStatus()
	case idBtnStart:
		go runAndShow("start")
	case idBtnStop:
		go runAndShow("stop")
	case idBtnPeers:
		go runAndShow("peer", "list")
	case idBtnURI:
		go showURI()
	case idBtnCopyURI:
		go copyURI()
	case idBtnQR:
		go openQR()
	case idBtnData:
		openDataDir()
	case idBtnAddPeer:
		go runAndShow("peer", "add")
	case idBtnHelp:
		msgBox("说明",
			"NetBridge nbvpn GUI (Server 2012)\n版本: "+version+"\n\n"+
				"本 GUI 为纯 Win32（无动态 CRT 依赖）。\n"+
				"WireGuard：Setup 会静默安装历史官方 MSI 0.5.3（兼容 2012）。\n"+
				"现代 1.1 MSI 仅支持 Win10 / Server 2016+。\n\n"+
				"nbvpn: "+nbvpnPath)
	}
}

func refreshStatus() {
	out, err := runNbvpn("status")
	ver, _ := runNbvpn("version")
	text := strings.TrimSpace(ver) + "\r\n\r\n" + strings.TrimSpace(out)
	if err != nil {
		text += "\r\n\r\n[error] " + err.Error()
	}
	setEditText(text + "\r\n")
}

func runAndShow(args ...string) {
	out, err := runNbvpn(args...)
	text := "$ nbvpn " + strings.Join(args, " ") + "\r\n" + strings.TrimSpace(out)
	if err != nil {
		text += "\r\n[error] " + err.Error()
	}
	setEditText(text + "\r\n")
}

func showURI() {
	out, err := runNbvpn("show", "--uri")
	lastURI = strings.TrimSpace(firstLine(out))
	text := strings.TrimSpace(out)
	if err != nil {
		text += "\r\n[error] " + err.Error()
	}
	setEditText(text + "\r\n")
}

func copyURI() {
	if lastURI == "" {
		out, _ := runNbvpn("show", "--uri")
		lastURI = strings.TrimSpace(firstLine(out))
	}
	if lastURI == "" {
		msgBox("复制 URI", "没有可用的 URI，请先点「显示 URI」。")
		return
	}
	if err := setClipboard(lastURI); err != nil {
		msgBox("复制 URI", err.Error())
		return
	}
	msgBox("复制 URI", "已复制到剪贴板。")
}

func openQR() {
	out, err := runNbvpn("show", "--uri")
	uri := strings.TrimSpace(firstLine(out))
	if uri == "" || err != nil {
		msgBox("显示 QR", "无法获取 URI: "+fmt.Sprint(err))
		return
	}
	lastURI = uri
	// Render half-block QR inside the GUI text pane (no external PNG viewer).
	q, qerr := qr.RenderTerminalOpts(uri, qr.RenderOptions{UseANSI: false, MaxCols: 96})
	var text strings.Builder
	text.WriteString("窗口内二维码（字符块；与 nbvpn show --qr 相同载荷）\r\n")
	text.WriteString("QR payload = full nbvpn: URI\r\n\r\n")
	if qerr != nil {
		text.WriteString("[terminal QR] " + qerr.Error() + "\r\n")
		text.WriteString("可改用「显示 URI」或数据目录中的 peers\\*.png 作为附件。\r\n")
	} else {
		text.WriteString(strings.ReplaceAll(q, "\n", "\r\n"))
	}
	pngPath := filepath.Join(os.TempDir(), "nbvpn-peer-qr.png")
	if err := qrcode.WriteFile(uri, qrcode.Medium, 256, pngPath); err == nil {
		text.WriteString("\r\n可选 PNG 附件: " + pngPath + "\r\n")
	}
	setEditText(text.String())
}

func openDataDir() {
	dir := filepath.Join(os.Getenv("ProgramData"), "nbvpn")
	procShellExecute.Call(0, uintptr(unsafe.Pointer(utf16Ptr("explore"))), uintptr(unsafe.Pointer(utf16Ptr(dir))), 0, 0, swShow)
}

func runNbvpn(args ...string) (string, error) {
	cmd := exec.Command(nbvpnPath, args...)
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	b, err := cmd.CombinedOutput()
	return string(b), err
}

func findNbvpn() (string, error) {
	exe, err := os.Executable()
	if err == nil {
		cand := filepath.Join(filepath.Dir(exe), "nbvpn.exe")
		if st, e := os.Stat(cand); e == nil && !st.IsDir() {
			return cand, nil
		}
	}
	if p, err := exec.LookPath("nbvpn.exe"); err == nil {
		return p, nil
	}
	if p, err := exec.LookPath("nbvpn"); err == nil {
		return p, nil
	}
	return "", fmt.Errorf("nbvpn.exe not found next to GUI or on PATH")
}

func setEditText(s string) {
	if hwndEdit == 0 {
		return
	}
	procSetWindowText.Call(uintptr(hwndEdit), uintptr(unsafe.Pointer(utf16Ptr(s))))
}

func msgBox(title, text string) {
	procMessageBox.Call(0, uintptr(unsafe.Pointer(utf16Ptr(text))), uintptr(unsafe.Pointer(utf16Ptr(title))), 0x40)
}

func firstLine(s string) string {
	s = strings.TrimSpace(s)
	if i := strings.IndexAny(s, "\r\n"); i >= 0 {
		return strings.TrimSpace(s[:i])
	}
	return s
}

func setClipboard(s string) error {
	u, err := syscall.UTF16FromString(s)
	if err != nil {
		return err
	}
	if r, _, e := procOpenClipboard.Call(0); r == 0 {
		return fmt.Errorf("OpenClipboard: %v", e)
	}
	defer procCloseClipboard.Call()
	procEmptyClipboard.Call()
	bytes := len(u) * 2
	h, _, e := procGlobalAlloc.Call(gmemMoveable, uintptr(bytes))
	if h == 0 {
		return fmt.Errorf("GlobalAlloc: %v", e)
	}
	ptr, _, e := procGlobalLock.Call(h)
	if ptr == 0 {
		return fmt.Errorf("GlobalLock: %v", e)
	}
	dst := unsafe.Slice((*uint16)(unsafe.Pointer(ptr)), len(u))
	copy(dst, u)
	procGlobalUnlock.Call(h)
	if r, _, e := procSetClipboardData.Call(cfUnicodeText, h); r == 0 {
		return fmt.Errorf("SetClipboardData: %v", e)
	}
	return nil
}
