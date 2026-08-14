//go:build !windows

package qr

func afterWritePlatform(canonicalPath string) AfterWriteResult {
	_ = canonicalPath
	return AfterWriteResult{
		Notes: []string{
			"Open this PNG with an image viewer and scan with the NetBridge client.",
			"(No auto-open on Linux/macOS — headless servers stay quiet.)",
		},
	}
}
