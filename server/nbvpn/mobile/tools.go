//go:build tools

package mobile

// Keep golang.org/x/mobile a direct dependency for gomobile bind
// (see https://go.dev/issue/77183).
import _ "golang.org/x/mobile/bind"
