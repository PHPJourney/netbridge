// Package main is the NetBridge nbvpn native Windows manager (Fyne + system tray).
package main

import (
	"bytes"
	_ "embed"
	"fmt"
	"image"
	"image/png"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"time"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/canvas"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/dialog"
	"fyne.io/fyne/v2/driver/desktop"
	"fyne.io/fyne/v2/layout"
	"fyne.io/fyne/v2/theme"
	"fyne.io/fyne/v2/widget"
	qrcode "github.com/skip2/go-qrcode"
)

//go:embed assets/icon.png
var iconPNG []byte

var version = "1.0.0"

func main() {
	a := app.NewWithID("com.netbridge.nbvpn-gui")
	iconRes := fyne.NewStaticResource("icon.png", iconPNG)
	a.SetIcon(iconRes)

	w := a.NewWindow("NetBridge nbvpn")
	w.Resize(fyne.NewSize(520, 680))
	w.SetFixedSize(false)

	nbvpnPath, err := findNbvpn()
	if err != nil {
		w.SetContent(widget.NewLabel("缺少 nbvpn.exe：请与 nbvpn-gui.exe 放在同一目录，或先运行 Setup。\n" + err.Error()))
		w.ShowAndRun()
		return
	}

	ui := newUI(a, w, nbvpnPath)
	w.SetContent(ui.root)

	// Close button → hide to tray (do not quit; tunnel keeps running).
	w.SetCloseIntercept(func() {
		w.Hide()
	})

	setupSystemTray(a, w, ui, iconRes)

	w.Show()
	ui.refreshAll()
	go ui.pollLoop()
	w.ShowAndRun()
}

func setupSystemTray(a fyne.App, w fyne.Window, ui *uiState, icon fyne.Resource) {
	desk, ok := a.(desktop.App)
	if !ok {
		return
	}
	desk.SetSystemTrayIcon(icon)

	showItem := fyne.NewMenuItem("显示主窗口", func() {
		fyne.Do(func() {
			w.Show()
			w.RequestFocus()
		})
	})
	statusItem := fyne.NewMenuItem("状态: …", nil)
	statusItem.Disabled = true

	startItem := fyne.NewMenuItem("启动隧道", func() { ui.doStart() })
	stopItem := fyne.NewMenuItem("停止隧道", func() { ui.doStop() })
	quitItem := fyne.NewMenuItem("退出", func() {
		a.Quit()
	})

	menu := fyne.NewMenu("NetBridge nbvpn",
		showItem,
		statusItem,
		fyne.NewMenuItemSeparator(),
		startItem,
		stopItem,
		fyne.NewMenuItemSeparator(),
		quitItem,
	)
	desk.SetSystemTrayMenu(menu)
	ui.trayStatusItem = statusItem
	ui.trayMenu = menu
	ui.trayApp = desk
}

type uiState struct {
	nbvpn string
	app   fyne.App
	win   fyne.Window

	statusBadge *widget.Label
	statusRaw   *widget.Entry
	actionMsg   *widget.Label
	settingsMsg *widget.Label
	uriEntry    *widget.Entry
	qrImg       *canvas.Image
	btnStart    *widget.Button
	btnStop     *widget.Button

	trayStatusItem *fyne.MenuItem
	trayMenu       *fyne.Menu
	trayApp        desktop.App
	lastState      string
	mu             sync.Mutex

	root fyne.CanvasObject
}

func newUI(a fyne.App, w fyne.Window, nbvpnPath string) *uiState {
	u := &uiState{nbvpn: nbvpnPath, app: a, win: w}

	u.statusBadge = widget.NewLabel("状态: 未知")
	u.statusBadge.TextStyle = fyne.TextStyle{Bold: true}
	u.statusRaw = widget.NewMultiLineEntry()
	u.statusRaw.SetMinRowsVisible(6)
	u.statusRaw.Wrapping = fyne.TextWrapWord
	u.statusRaw.Disable()

	u.actionMsg = widget.NewLabel("")
	u.settingsMsg = widget.NewLabel("关闭窗口会隐藏到托盘，隧道不会因此停止。右键托盘选「退出」才结束程序。")
	u.uriEntry = widget.NewMultiLineEntry()
	u.uriEntry.SetMinRowsVisible(3)
	u.uriEntry.Wrapping = fyne.TextWrapBreak
	u.uriEntry.Disable()

	u.qrImg = canvas.NewImageFromImage(nil)
	u.qrImg.FillMode = canvas.ImageFillContain
	u.qrImg.SetMinSize(fyne.NewSize(220, 220))

	btnRefresh := widget.NewButtonWithIcon("刷新", theme.ViewRefreshIcon(), func() { u.refreshAll() })
	u.btnStart = widget.NewButtonWithIcon("启动", theme.MediaPlayIcon(), func() { u.doStart() })
	u.btnStop = widget.NewButtonWithIcon("停止", theme.MediaStopIcon(), func() { u.doStop() })
	u.btnStart.Importance = widget.HighImportance
	u.btnStop.Importance = widget.DangerImportance

	btnOpenData := widget.NewButton("打开数据目录", func() { u.openDataDir() })
	btnCopyURI := widget.NewButton("复制 URI", func() { u.copyURI() })
	btnHelp := widget.NewButton("说明", func() { u.showHelp() })
	btnReloadQR := widget.NewButton("刷新二维码", func() { u.reloadQR() })

	header := container.NewVBox(
		widget.NewLabelWithStyle("NetBridge nbvpn", fyne.TextAlignLeading, fyne.TextStyle{Bold: true}),
		widget.NewLabel("Windows 节点管理（原生窗口；底层调用 nbvpn CLI）"),
	)

	statusBox := container.NewBorder(
		container.NewHBox(u.statusBadge, layout.NewSpacer(), btnRefresh),
		nil, nil, nil,
		u.statusRaw,
	)

	controlBox := container.NewVBox(
		container.NewHBox(u.btnStart, u.btnStop),
		u.actionMsg,
	)

	qrBox := container.NewBorder(
		widget.NewLabel("Peer 二维码（窗口内显示）"),
		btnReloadQR,
		nil, nil,
		container.NewCenter(u.qrImg),
	)

	settingsBox := container.NewVBox(
		container.NewHBox(btnOpenData, btnCopyURI, btnHelp),
		u.settingsMsg,
		widget.NewLabel("nbvpn: URI"),
		u.uriEntry,
	)

	u.root = container.NewBorder(
		header,
		widget.NewLabel("GUI "+version+" · "+nbvpnPath),
		nil, nil,
		container.NewVBox(
			widget.NewCard("", "状态", statusBox),
			widget.NewCard("", "启停", controlBox),
			widget.NewCard("", "二维码", qrBox),
			widget.NewCard("", "设置", settingsBox),
		),
	)
	return u
}

func (u *uiState) pollLoop() {
	t := time.NewTicker(8 * time.Second)
	defer t.Stop()
	for range t.C {
		u.refreshStatus()
	}
}

func (u *uiState) refreshAll() {
	u.refreshStatus()
	u.reloadQR()
	u.loadURI()
}

func (u *uiState) setBusy(busy bool) {
	if busy {
		u.btnStart.Disable()
		u.btnStop.Disable()
	} else {
		u.btnStart.Enable()
		u.btnStop.Enable()
	}
}

func (u *uiState) refreshStatus() {
	out, errOut, err := u.run("status")
	raw := strings.TrimSpace(out)
	if raw == "" {
		raw = strings.TrimSpace(errOut)
	}
	st := parseStatus(out + "\n" + errOut)
	label := map[string]string{
		"running": "状态: 运行中",
		"stopped": "状态: 已停止",
		"unknown": "状态: 未知",
	}[st]
	if label == "" {
		label = "状态: 未知"
	}
	u.mu.Lock()
	u.lastState = st
	u.mu.Unlock()

	fyne.Do(func() {
		u.statusBadge.SetText(label)
		u.statusRaw.SetText(raw)
		if err != nil && strings.TrimSpace(errOut) != "" && raw == "" {
			u.statusRaw.SetText(err.Error() + "\n" + errOut)
		}
		if u.trayStatusItem != nil {
			u.trayStatusItem.Label = label
			if u.trayApp != nil && u.trayMenu != nil {
				u.trayApp.SetSystemTrayMenu(u.trayMenu)
			}
		}
	})
}

func (u *uiState) doStart() {
	fyne.Do(func() {
		u.setBusy(true)
		u.actionMsg.SetText("正在启动…")
	})
	go func() {
		out, errOut, err := u.run("start")
		msg := strings.TrimSpace(out + "\n" + errOut)
		fyne.Do(func() {
			u.setBusy(false)
			if err != nil {
				u.actionMsg.SetText("启动失败: " + errString(err) + " " + msg)
			} else {
				u.actionMsg.SetText("已启动: " + msg)
			}
			u.refreshStatus()
		})
	}()
}

func (u *uiState) doStop() {
	fyne.Do(func() {
		u.setBusy(true)
		u.actionMsg.SetText("正在停止…")
	})
	go func() {
		out, errOut, err := u.run("stop")
		msg := strings.TrimSpace(out + "\n" + errOut)
		stOut, _, _ := u.run("status")
		st := parseStatus(stOut)
		fyne.Do(func() {
			u.setBusy(false)
			if err != nil {
				u.actionMsg.SetText("停止调用结束: " + errString(err) + " " + msg + " | status=" + st)
			} else if st == "running" {
				u.actionMsg.SetText("停止已执行但仍显示运行中，请以管理员重试。 " + msg)
			} else {
				u.actionMsg.SetText("已停止（status=" + st + "）")
			}
			u.refreshStatus()
		})
	}()
}

func (u *uiState) openDataDir() {
	dir := dataDir()
	if err := revealPath(dir); err != nil {
		u.settingsMsg.SetText("打开失败: " + err.Error())
		return
	}
	u.settingsMsg.SetText("已打开: " + dir)
}

func (u *uiState) copyURI() {
	uri, err := u.fetchURI()
	if err != nil {
		u.settingsMsg.SetText("无法获取 URI: " + err.Error())
		return
	}
	u.app.Clipboard().SetContent(uri)
	u.uriEntry.SetText(uri)
	u.settingsMsg.SetText("已复制 nbvpn: URI（含私钥，勿公开分享）")
}

func (u *uiState) loadURI() {
	uri, err := u.fetchURI()
	fyne.Do(func() {
		if err != nil {
			u.uriEntry.SetText("")
			return
		}
		u.uriEntry.SetText(uri)
	})
}

func (u *uiState) fetchURI() (string, error) {
	out, errOut, err := u.run("show", "--uri")
	uri := strings.TrimSpace(out)
	if err != nil {
		return "", fmt.Errorf("%w (%s)", err, strings.TrimSpace(errOut))
	}
	if !strings.HasPrefix(uri, "nbvpn:") {
		return "", fmt.Errorf("unexpected uri output")
	}
	return uri, nil
}

func (u *uiState) reloadQR() {
	go func() {
		img, src, err := u.loadQRImage()
		fyne.Do(func() {
			if err != nil {
				u.qrImg.Image = nil
				u.qrImg.Refresh()
				u.settingsMsg.SetText("二维码: " + err.Error())
				return
			}
			u.qrImg.Image = img
			u.qrImg.Refresh()
			u.settingsMsg.SetText("二维码来源: " + src + "（关窗进托盘，隧道继续）")
		})
	}()
}

func (u *uiState) loadQRImage() (image.Image, string, error) {
	out, _, err := u.run("show", "--file")
	if err == nil {
		for _, line := range strings.Split(out, "\n") {
			line = strings.TrimSpace(line)
			if strings.HasSuffix(strings.ToLower(line), ".png") {
				b, rerr := os.ReadFile(line)
				if rerr == nil {
					img, derr := png.Decode(bytes.NewReader(b))
					if derr == nil {
						return img, line, nil
					}
				}
			}
		}
	}
	uri, uerr := u.fetchURI()
	if uerr != nil {
		return nil, "", fmt.Errorf("no PNG and no URI: %v / %v", err, uerr)
	}
	pngBytes, err := qrcode.Encode(uri, qrcode.Medium, 256)
	if err != nil {
		return nil, "", err
	}
	img, err := png.Decode(bytes.NewReader(pngBytes))
	if err != nil {
		return nil, "", err
	}
	return img, "memory URI", nil
}

func (u *uiState) showHelp() {
	msg := `NetBridge nbvpn GUI

• 启动 / 停止：调用同目录 nbvpn.exe（隐藏控制台），管理 WireGuardTunnel$nbvpn
• 关闭窗口：隐藏到系统托盘，不退出；已启动的隧道继续运行
• 托盘：显示主窗口 / 启停 / 退出（退出才结束进程）
• 二维码：优先读取 peer PNG，否则由 URI 内存生成
• CLI 仍可用：nbvpn status / start / stop / show

数据目录: ` + dataDir()
	dialog.ShowInformation("说明", msg, u.win)
}

func (u *uiState) run(args ...string) (stdout, stderr string, err error) {
	cmd := exec.Command(u.nbvpn, args...)
	hideConsole(cmd)
	var outBuf, errBuf strings.Builder
	cmd.Stdout = &outBuf
	cmd.Stderr = &errBuf
	err = cmd.Run()
	return outBuf.String(), errBuf.String(), err
}

func parseStatus(raw string) string {
	low := strings.ToLower(raw)
	// Order matters: "not running" contains "running"
	switch {
	case strings.Contains(low, "not running"), strings.Contains(low, "not installed"),
		strings.Contains(low, "stopped"), strings.Contains(low, "inactive"):
		return "stopped"
	case strings.Contains(low, "running"):
		return "running"
	case strings.Contains(low, "dry-run"):
		return "unknown"
	default:
		if strings.TrimSpace(raw) == "" {
			return "unknown"
		}
		return "unknown"
	}
}

func dataDir() string {
	if v := strings.TrimSpace(os.Getenv("NBVPN_DATA_DIR")); v != "" {
		return v
	}
	if runtime.GOOS == "windows" {
		pd := strings.TrimSpace(os.Getenv("ProgramData"))
		if pd == "" {
			pd = `C:\ProgramData`
		}
		return filepath.Join(pd, "nbvpn")
	}
	return "/var/lib/nbvpn"
}

func findNbvpn() (string, error) {
	if v := strings.TrimSpace(os.Getenv("NBVPN_BIN")); v != "" {
		if st, err := os.Stat(v); err == nil && !st.IsDir() {
			return v, nil
		}
		return "", fmt.Errorf("NBVPN_BIN not found: %s", v)
	}
	self, err := os.Executable()
	if err == nil {
		dir := filepath.Dir(self)
		name := "nbvpn"
		if runtime.GOOS == "windows" {
			name = "nbvpn.exe"
		}
		cand := filepath.Join(dir, name)
		if st, err := os.Stat(cand); err == nil && !st.IsDir() {
			return cand, nil
		}
	}
	path, err := exec.LookPath("nbvpn")
	if err != nil {
		return "", fmt.Errorf("nbvpn not on PATH and not beside nbvpn-gui")
	}
	return path, nil
}

func errString(err error) string {
	if err == nil {
		return ""
	}
	return err.Error()
}

func revealPath(path string) error {
	if runtime.GOOS == "windows" {
		return exec.Command("explorer", path).Start()
	}
	if runtime.GOOS == "darwin" {
		return exec.Command("open", path).Start()
	}
	return exec.Command("xdg-open", path).Start()
}
