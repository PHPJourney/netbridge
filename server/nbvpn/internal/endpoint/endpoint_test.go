package endpoint

import "testing"

func TestNormalizeEndpoint_IPv4AndHost(t *testing.T) {
	cases := []struct {
		in   string
		want string
	}{
		{"203.0.113.10", "203.0.113.10:51820"},
		{"203.0.113.10:51821", "203.0.113.10:51821"},
		{"vpn.example.com", "vpn.example.com:51820"},
		{"vpn.example.com:443", "vpn.example.com:443"},
	}
	for _, tc := range cases {
		got, err := NormalizeEndpoint(tc.in, 51820)
		if err != nil {
			t.Fatalf("%q: %v", tc.in, err)
		}
		if got != tc.want {
			t.Fatalf("%q: got %q want %q", tc.in, got, tc.want)
		}
	}
}

func TestNormalizeEndpoint_IPv6(t *testing.T) {
	cases := []struct {
		in   string
		want string
	}{
		{"2001:db8::1", "[2001:db8::1]:51820"},
		{"[2001:db8::1]", "[2001:db8::1]:51820"},
		{"[2001:db8::1]:51821", "[2001:db8::1]:51821"},
	}
	for _, tc := range cases {
		got, err := NormalizeEndpoint(tc.in, 51820)
		if err != nil {
			t.Fatalf("%q: %v", tc.in, err)
		}
		if got != tc.want {
			t.Fatalf("%q: got %q want %q", tc.in, got, tc.want)
		}
	}
}

func TestNormalizeEndpoint_RejectEmpty(t *testing.T) {
	if _, err := NormalizeEndpoint("  ", 51820); err == nil {
		t.Fatal("expected empty error")
	}
}
