//go:build windows

package cli

import (
	"fmt"
	"os"
	"syscall"
	"unsafe"
)

// ownsConsoleAlone is true when this process is the only one attached to the
// console — typical of Explorer double-click (Windows creates a fresh console).
// When launched from cmd/PowerShell, the shell remains attached (count >= 2).
func ownsConsoleAlone() bool {
	kernel32 := syscall.NewLazyDLL("kernel32.dll")
	proc := kernel32.NewProc("GetConsoleProcessList")
	var pids [8]uint32
	n, _, _ := proc.Call(uintptr(unsafe.Pointer(&pids[0])), uintptr(len(pids)))
	return n == 1
}

func showLaunchHintMessageBox() {
	user32 := syscall.NewLazyDLL("user32.dll")
	messageBox := user32.NewProc("MessageBoxW")
	title, err1 := syscall.UTF16PtrFromString("NetBridge nbvpn")
	text, err2 := syscall.UTF16PtrFromString(
		"nbvpn 是命令行工具，不是安装包。\n" +
			"双击窗口马上关掉是正常现象，不是闪退崩溃。\n\n" +
			"Server 2012 / 2012 R2 请下载并双击安装：\n" +
			"  NetBridge-nbvpn-Setup-win2012.exe\n\n" +
			"装好后开始菜单打开「NetBridge nbvpn GUI」\n" +
			"（含 WireGuard 0.5.3 + Win32 管理界面）。\n\n" +
			"关闭本对话框后，请在黑色窗口按 Enter 退出。",
	)
	if err1 != nil || err2 != nil {
		return
	}
	const (
		mbOK              = 0
		mbIconInformation = 0x40
	)
	_, _, _ = messageBox.Call(
		0,
		uintptr(unsafe.Pointer(text)),
		uintptr(unsafe.Pointer(title)),
		uintptr(mbOK|mbIconInformation),
	)
}

// pauseIfDoubleClickConsole keeps the console open after help so double-click
// does not look like a crash. No-op when already inside an interactive shell.
func pauseIfDoubleClickConsole() {
	if !ownsConsoleAlone() {
		return
	}
	fmt.Fprintln(os.Stdout, "")
	fmt.Fprintln(os.Stdout, "—— 这不是崩溃。请用 Setup-win2012 安装（含 WG+GUI） ——")
	fmt.Fprintln(os.Stdout, "  2012 请双击安装: NetBridge-nbvpn-Setup-win2012.exe")
	fmt.Fprintln(os.Stdout, "  装好后: 开始菜单 →「NetBridge nbvpn GUI」")
	fmt.Fprintln(os.Stdout, "  或管理员 CMD: nbvpn version / status / show --uri")
	showLaunchHintMessageBox()
	fmt.Fprint(os.Stdout, "\n按 Enter 关闭此窗口…")
	_, _ = fmt.Scanln()
}
