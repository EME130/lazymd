package web

import "testing"

func TestComputeAcceptKey(t *testing.T) {
	// RFC 6455 test vector
	accept := ComputeAcceptKey("dGhlIHNhbXBsZSBub25jZQ==")
	expected := "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="
	if accept != expected {
		t.Errorf("expected %s, got %s", expected, accept)
	}
}

func TestIsUpgradeRequest(t *testing.T) {
	req := "GET / HTTP/1.1\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n"
	if !IsUpgradeRequest(req) {
		t.Error("expected WebSocket upgrade")
	}

	if IsUpgradeRequest("GET / HTTP/1.1\r\n\r\n") {
		t.Error("expected no upgrade")
	}
}

func TestExtractWSKey(t *testing.T) {
	req := "GET / HTTP/1.1\r\nHost: localhost\r\nSec-WebSocket-Key: abc123\r\n\r\n"
	key := ExtractWSKey(req)
	if key != "abc123" {
		t.Errorf("expected abc123, got %s", key)
	}

	if ExtractWSKey("GET / HTTP/1.1\r\n\r\n") != "" {
		t.Error("expected empty key")
	}
}

func TestUpgradeResponse(t *testing.T) {
	resp := UpgradeResponse("dGhlIHNhbXBsZSBub25jZQ==")
	if resp == "" {
		t.Error("expected non-empty response")
	}
	if len(resp) < 50 {
		t.Error("response too short")
	}
}
