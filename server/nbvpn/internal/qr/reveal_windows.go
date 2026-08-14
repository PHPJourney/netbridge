//go:build windows

package qr

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func afterWritePlatform(canonicalPath string) AfterWriteResult {
	r := AfterWriteResult{
		SelectCmd: fmt.Sprintf(`explorer /select,"%s"`, canonicalPath),
		Notes: []string{
			"注意: %ProgramData% 默认是隐藏文件夹 — 在资源管理器根目录 C:\\ 看不到 ProgramData。",
			"Note: ProgramData is hidden by default — you will NOT see it under C:\\ in Explorer.",
			`打开数据目录:  explorer %ProgramData%\nbvpn`,
			`或在资源管理器地址栏输入:  %ProgramData%\nbvpn\peers`,
		},
	}

	base := peerPNGBasename(canonicalPath)
	// Desktop (user-visible)
	if home := strings.TrimSpace(os.Getenv("USERPROFILE")); home != "" {
		dst := filepath.Join(home, "Desktop", "nbvpn-peer-"+base)
		if err := copyFile(canonicalPath, dst); err == nil {
			r.VisibleCopies = append(r.VisibleCopies, dst)
		}
	}
	// Public Documents (shared, usually not hidden)
	public := strings.TrimSpace(os.Getenv("PUBLIC"))
	if public == "" {
		public = `C:\Users\Public`
	}
	pubDir := filepath.Join(public, "Documents", "nbvpn")
	dstPub := filepath.Join(pubDir, base)
	if err := copyFile(canonicalPath, dstPub); err == nil {
		r.VisibleCopies = append(r.VisibleCopies, dstPub)
	}

	// Prefer selecting a visible copy if we made one; else the canonical path.
	reveal := canonicalPath
	if len(r.VisibleCopies) > 0 {
		reveal = r.VisibleCopies[0]
		r.SelectCmd = fmt.Sprintf(`explorer /select,"%s"`, reveal)
	}

	r.Opened = true
	// explorer /select highlights the file; also try starting the PNG (Photos / default viewer).
	if err := exec.Command("explorer", "/select,"+reveal).Start(); err != nil {
		r.OpenErr = err
		if err2 := exec.Command("cmd", "/c", "start", "", reveal).Start(); err2 != nil && r.OpenErr == nil {
			r.OpenErr = err2
		}
	} else {
		// Best-effort open image viewer as well (does not block).
		_ = exec.Command("cmd", "/c", "start", "", reveal).Start()
	}
	return r
}
