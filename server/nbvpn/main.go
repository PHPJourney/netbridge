package main

import (
	"os"

	"github.com/netbridge/nbvpn/internal/cli"
)

// Set via: go build -ldflags "-X main.version=1.0.0"
var version = "1.0.0"

func main() {
	cli.Version = version
	os.Exit(cli.Run(os.Args[1:]))
}
