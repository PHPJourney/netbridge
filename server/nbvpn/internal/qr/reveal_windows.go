//go:build windows

package qr

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

func afterWritePlatform(canonicalPath string) AfterWriteResult {
	r := AfterWriteResult{
		SelectCmd: fmt.Sprintf(`explorer /select,"%s"`, canonicalPath),
		Notes: []string{
			"注意: %ProgramData% 默认是隐藏文件夹 — 终端二维码优先；PNG 仅作扫码附件。",
			"Note: ProgramData is hidden — prefer the terminal QR; PNG is optional.",
			`打开数据目录:  explorer %ProgramData%\nbvpn`,
		},
	}

	base := peerPNGBasename(canonicalPath)
	// Desktop (user-visible) — optional copy only; do not auto-open Photos.
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

	if len(r.VisibleCopies) > 0 {
		r.SelectCmd = fmt.Sprintf(`explorer /select,"%s"`, r.VisibleCopies[0])
	}
	// Do not auto-open explorer / image viewer — CLI prints terminal QR instead.
	return r
}
