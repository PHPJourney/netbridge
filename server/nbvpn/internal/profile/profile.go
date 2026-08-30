package profile

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net"
	"strings"
)

const (
	Version     = 1
	URIScheme   = "nbvpn"
	URIPrefix   = "nbvpn:1?"
	DefaultDNS1 = "1.1.1.1"
	DefaultDNS2 = "1.0.0.1"
	DefaultMTU  = 1280
	DefaultKA   = 25
)

// NbVpnProfile is the frozen v1 connection payload (03-contract.md).
type NbVpnProfile struct {
	V      int            `json:"v"`
	Name   string         `json:"name"`
	Client ClientSection  `json:"client"`
	Server ServerSection  `json:"server"`
	// Obfs is the optional obfuscation-layer section (obfs2 transport).
	Obfs   *ObfsSection   `json:"obfs,omitempty"`
}

// ObfsSection carries the obfs2 transport parameters for one profile.
// PSK is hex-encoded; Entries form the multi-entry pool.
type ObfsSection struct {
	Type     string   `json:"type"`
	PSK      string   `json:"psk"`
	Entries  []string `json:"entries"`
	LocalUDP int      `json:"localUDP,omitempty"`
	Insecure bool     `json:"insecure,omitempty"`
	Channels int      `json:"channels,omitempty"`
}

type ClientSection struct {
	PrivateKey string   `json:"privateKey"`
	Address    []string `json:"address"`
	DNS        []string `json:"dns"`
	MTU        int      `json:"mtu,omitempty"`
}

type ServerSection struct {
	PublicKey           string   `json:"publicKey"`
	Endpoint            string   `json:"endpoint"`
	EndpointV6          string   `json:"endpointV6,omitempty"`
	IPv6Enabled         bool     `json:"ipv6Enabled,omitempty"`
	AllowedIPs          []string `json:"allowedIPs"`
	PersistentKeepalive int      `json:"persistentKeepalive,omitempty"`
	PresharedKey        *string  `json:"presharedKey"`
}

// ActiveEndpoint returns the WireGuard peer Endpoint to use at connect time.
// When ipv6Enabled and endpointV6 are set, prefer IPv6; otherwise primary endpoint.
// WireGuard supports a single Endpoint per peer — not dual simultaneous.
func (s ServerSection) ActiveEndpoint() string {
	v6 := strings.TrimSpace(s.EndpointV6)
	if s.IPv6Enabled && v6 != "" {
		return v6
	}
	return strings.TrimSpace(s.Endpoint)
}

// Validate checks required fields per contract §1.2.
func (p *NbVpnProfile) Validate() error {
	if p == nil {
		return fmt.Errorf("E_PROFILE_INVALID: profile is nil")
	}
	if p.V == 0 {
		return fmt.Errorf("E_PROFILE_INVALID: missing v")
	}
	if p.V < 1 {
		return fmt.Errorf("E_PROFILE_INVALID: unsupported v=%d", p.V)
	}
	if p.V > Version {
		return fmt.Errorf("E_PROFILE_UNSUPPORTED: profile v=%d requires newer client (supported=%d)", p.V, Version)
	}
	if p.V != Version {
		return fmt.Errorf("E_PROFILE_INVALID: unsupported v=%d", p.V)
	}
	if strings.TrimSpace(p.Name) == "" {
		return fmt.Errorf("E_PROFILE_INVALID: name is required")
	}
	if err := validateKey(p.Client.PrivateKey, "client.privateKey"); err != nil {
		return err
	}
	if len(p.Client.Address) == 0 {
		return fmt.Errorf("E_PROFILE_INVALID: client.address must not be empty")
	}
	if len(p.Client.DNS) == 0 {
		return fmt.Errorf("E_PROFILE_INVALID: client.dns must not be empty")
	}
	if err := validateKey(p.Server.PublicKey, "server.publicKey"); err != nil {
		return err
	}
	if err := validateEndpoint(p.Server.Endpoint); err != nil {
		return err
	}
	if v6 := strings.TrimSpace(p.Server.EndpointV6); v6 != "" {
		if err := validateEndpointField(v6, "server.endpointV6"); err != nil {
			return err
		}
	}
	if len(p.Server.AllowedIPs) == 0 {
		return fmt.Errorf("E_PROFILE_INVALID: server.allowedIPs must not be empty")
	}
	return nil
}

func validateKey(k, field string) error {
	k = strings.TrimSpace(k)
	if k == "" {
		return fmt.Errorf("E_PROFILE_INVALID: %s is required", field)
	}
	raw, err := base64.StdEncoding.DecodeString(k)
	if err != nil || len(raw) != 32 {
		return fmt.Errorf("E_PROFILE_INVALID: %s must be a 32-byte WireGuard key (base64)", field)
	}
	return nil
}

func validateEndpoint(ep string) error {
	return validateEndpointField(ep, "server.endpoint")
}

func validateEndpointField(ep, field string) error {
	ep = strings.TrimSpace(ep)
	if ep == "" {
		return fmt.Errorf("E_PROFILE_INVALID: %s is required", field)
	}
	host, port, err := net.SplitHostPort(ep)
	if err != nil || host == "" || port == "" {
		return fmt.Errorf("E_PROFILE_INVALID: %s must be host:port (IPv6 as [addr]:port)", field)
	}
	return nil
}

// MarshalCanonical returns stable UTF-8 JSON (compact).
func (p *NbVpnProfile) MarshalCanonical() ([]byte, error) {
	if err := p.Validate(); err != nil {
		return nil, err
	}
	return json.Marshal(p)
}

// EncodeURI builds nbvpn:1?<base64url(JSON)> (no padding).
func EncodeURI(p *NbVpnProfile) (string, error) {
	raw, err := p.MarshalCanonical()
	if err != nil {
		return "", err
	}
	enc := base64.RawURLEncoding.EncodeToString(raw)
	return URIPrefix + enc, nil
}

// DecodeURI parses nbvpn:1?<base64url(JSON)> into a validated profile.
func DecodeURI(uri string) (*NbVpnProfile, error) {
	uri = strings.TrimSpace(uri)
	if !strings.HasPrefix(uri, URIScheme+":") {
		return nil, fmt.Errorf("E_URI_SCHEME: expected scheme %s:", URIScheme)
	}
	rest := strings.TrimPrefix(uri, URIScheme+":")
	verPart, payload, ok := strings.Cut(rest, "?")
	if !ok {
		return nil, fmt.Errorf("E_URI_DECODE: missing '?' payload")
	}
	if verPart != "1" {
		return nil, fmt.Errorf("E_URI_VERSION: unsupported URI version %q", verPart)
	}
	raw, err := base64.RawURLEncoding.DecodeString(payload)
	if err != nil {
		// try with padding for leniency
		raw, err = base64.URLEncoding.DecodeString(payload)
		if err != nil {
			return nil, fmt.Errorf("E_URI_DECODE: base64url decode failed: %w", err)
		}
	}
	var p NbVpnProfile
	if err := json.Unmarshal(raw, &p); err != nil {
		return nil, fmt.Errorf("E_URI_DECODE: JSON parse failed: %w", err)
	}
	if err := p.Validate(); err != nil {
		return nil, err
	}
	return &p, nil
}

// ParseJSON decodes and validates a .nbvpn.json body.
func ParseJSON(data []byte) (*NbVpnProfile, error) {
	var p NbVpnProfile
	if err := json.Unmarshal(data, &p); err != nil {
		return nil, fmt.Errorf("E_URI_DECODE: JSON parse failed: %w", err)
	}
	if err := p.Validate(); err != nil {
		return nil, err
	}
	return &p, nil
}

// ToWireGuardConf generates a wg-quick compatible client config from the profile.
func ToWireGuardConf(p *NbVpnProfile) (string, error) {
	if err := p.Validate(); err != nil {
		return "", err
	}
	ka := p.Server.PersistentKeepalive
	if ka == 0 {
		ka = DefaultKA
	}
	var b strings.Builder
	b.WriteString("[Interface]\n")
	b.WriteString(fmt.Sprintf("PrivateKey = %s\n", p.Client.PrivateKey))
	b.WriteString(fmt.Sprintf("Address = %s\n", strings.Join(p.Client.Address, ", ")))
	b.WriteString(fmt.Sprintf("DNS = %s\n", strings.Join(p.Client.DNS, ", ")))
	if p.Client.MTU > 0 {
		b.WriteString(fmt.Sprintf("MTU = %d\n", p.Client.MTU))
	}
	b.WriteString("\n[Peer]\n")
	b.WriteString(fmt.Sprintf("PublicKey = %s\n", p.Server.PublicKey))
	b.WriteString(fmt.Sprintf("Endpoint = %s\n", p.Server.ActiveEndpoint()))
	b.WriteString(fmt.Sprintf("AllowedIPs = %s\n", strings.Join(p.Server.AllowedIPs, ", ")))
	b.WriteString(fmt.Sprintf("PersistentKeepalive = %d\n", ka))
	if p.Server.PresharedKey != nil && *p.Server.PresharedKey != "" {
		b.WriteString(fmt.Sprintf("PresharedKey = %s\n", *p.Server.PresharedKey))
	}
	return b.String(), nil
}
