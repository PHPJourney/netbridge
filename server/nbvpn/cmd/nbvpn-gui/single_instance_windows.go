//go:build windows

package main

import (
	"unsafe"

	"golang.org/x/sys/windows"
)

const (
	nbvpnGUIMutexName = `Local\NetBridgeNbvpnGuiSingleInstance`
	nbvpnGUIWinTitle  = "NetBridge nbvpn"
)

// ensureSingleInstance returns false if another instance is already running
// (after activating that window). On success, call the returned release when quitting.
func ensureSingleInstance() (release func(), ok bool) {
	name, err := windows.UTF16PtrFromString(nbvpnGUIMutexName)
	if err != nil {
		return func() {}, true
	}
	handle, err := windows.CreateMutex(nil, false, name)
	if err == windows.ERROR_ALREADY_EXISTS {
		activateExistingNbvpnGUI()
		if handle != 0 {
			_ = windows.CloseHandle(handle)
		}
		return nil, false
	}
	if err != nil {
		// Fail open: do not block launch if mutex creation fails.
		return func() {}, true
	}
	return func() { _ = windows.CloseHandle(handle) }, true
}

func activateExistingNbvpnGUI() {
	user32 := windows.NewLazySystemDLL("user32.dll")
	findWindow := user32.NewProc("FindWindowW")
	showWindow := user32.NewProc("ShowWindow")
	setForeground := user32.NewProc("SetForegroundWindow")

	title, err := windows.UTF16PtrFromString(nbvpnGUIWinTitle)
	if err != nil {
		return
	}
	hwnd, _, _ := findWindow.Call(0, uintptr(unsafe.Pointer(title)))
	if hwnd == 0 {
		return
	}
	const swRestore = 9
	_, _, _ = showWindow.Call(hwnd, swRestore)
	_, _, _ = setForeground.Call(hwnd)
}
