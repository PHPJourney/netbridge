package endpoint

import (
	"fmt"
	"io"
	"net"
	"net/http"
	"strconv"
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
		parsed := net.ParseIP(ip)
		if parsed == nil {
			continue
		}
		// Prefer IPv4 for primary endpoint detection.
		if parsed.To4() != nil {
			return ip
		}
	}
	return ""
}

// DetectPublicIPv6 tries IPv6-capable echo services; returns empty on failure.
func DetectPublicIPv6() string {
	clients := &http.Client{Timeout: 4 * time.Second}
	urls := []string{
		"https://api6.ipify.org",
		"https://ipv6.icanhazip.com",
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
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 128))
		_ = resp.Body.Close()
		if resp.StatusCode != 200 {
			continue
		}
		ip := strings.TrimSpace(string(body))
		parsed := net.ParseIP(ip)
		if parsed == nil || parsed.To4() != nil {
			continue
		}
		return ip
	}
	return ""
}

// NormalizeEndpoint ensures host:port form (IPv6 as [addr]:port); defaultPort when omitted.
func NormalizeEndpoint(hostOrEP string, defaultPort int) (string, error) {
	hostOrEP = strings.TrimSpace(hostOrEP)
	if hostOrEP == "" {
		return "", fmt.Errorf("endpoint is empty")
	}
	portStr := strconv.Itoa(defaultPort)

	if strings.HasPrefix(hostOrEP, "[") {
		if host, port, err := net.SplitHostPort(hostOrEP); err == nil && host != "" && port != "" {
			return net.JoinHostPort(host, port), nil
		}
		if strings.HasSuffix(hostOrEP, "]") {
			inner := strings.TrimSuffix(strings.TrimPrefix(hostOrEP, "["), "]")
			if net.ParseIP(inner) == nil {
				return "", fmt.Errorf("invalid IPv6 endpoint %q", hostOrEP)
			}
			return net.JoinHostPort(inner, portStr), nil
		}
		return "", fmt.Errorf("invalid endpoint %q; use [ipv6]:port", hostOrEP)
	}

	if host, port, err := net.SplitHostPort(hostOrEP); err == nil && host != "" && port != "" {
		return net.JoinHostPort(host, port), nil
	}

	// Bare IP (v4 or v6) or hostname without port.
	if ip := net.ParseIP(hostOrEP); ip != nil {
		return net.JoinHostPort(hostOrEP, portStr), nil
	}
	if strings.Contains(hostOrEP, ":") {
		return "", fmt.Errorf("invalid endpoint %q; use host:port or [ipv6]:port", hostOrEP)
	}
	return net.JoinHostPort(hostOrEP, portStr), nil
}
