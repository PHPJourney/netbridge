package endpoint

import (
	"fmt"
	"io"
	"net"
	"net/http"
	"strings"
	"time"
)

// DetectPublicIP tries several HTTPS endpoints; returns empty string on failure.
func DetectPublicIP() string {
	clients := &http.Client{Timeout: 4 * time.Second}
	urls := []string{
		"https://api.ipify.org",
		"https://ifconfig.me/ip",
		"https://icanhazip.com",
	}
	for _, u := range urls {
		req, err := http.NewRequest(http.MethodGet, u, nil)
		if err != nil {
			continue
		}
		req.Header.Set("User-Agent", "nbvpn/1.0")
		resp, err := clients.Do(req)
		if err != nil {
			continue
		}
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 64))
		_ = resp.Body.Close()
		if resp.StatusCode != 200 {
			continue
		}
		ip := strings.TrimSpace(string(body))
		if net.ParseIP(ip) != nil {
			return ip
		}
	}
	return ""
}

// NormalizeEndpoint ensures host:port form; defaultPort used when port omitted.
func NormalizeEndpoint(hostOrEP string, defaultPort int) (string, error) {
	hostOrEP = strings.TrimSpace(hostOrEP)
	if hostOrEP == "" {
		return "", fmt.Errorf("endpoint is empty")
	}
	if strings.HasPrefix(hostOrEP, "[") {
		if strings.Contains(hostOrEP, "]:") {
			return hostOrEP, nil
		}
		return fmt.Sprintf("%s:%d", hostOrEP, defaultPort), nil
	}
	// already host:port?
	if h, p, err := net.SplitHostPort(hostOrEP); err == nil && h != "" && p != "" {
		return net.JoinHostPort(h, p), nil
	}
	// bare host / IP
	if strings.Contains(hostOrEP, ":") && net.ParseIP(hostOrEP) == nil {
		// ambiguous — treat as missing port if SplitHostPort failed
		return "", fmt.Errorf("invalid endpoint %q; use host:port", hostOrEP)
	}
	return fmt.Sprintf("%s:%d", hostOrEP, defaultPort), nil
}
