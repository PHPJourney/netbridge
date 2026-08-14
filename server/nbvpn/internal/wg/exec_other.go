//go:build !windows

package wg

import "os/exec"

func hideConsoleWindow(cmd *exec.Cmd) {}
