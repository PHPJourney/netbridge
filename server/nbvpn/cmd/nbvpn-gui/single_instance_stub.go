//go:build !windows

package main

func ensureSingleInstance() (release func(), ok bool) {
	return func() {}, true
}
