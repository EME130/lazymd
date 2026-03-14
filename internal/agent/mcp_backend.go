package agent

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"strings"
)

// McpBackend implements Backend for MCP stdio transport.
// Editor→Agent: sends JSON-RPC notifications over stdout.
// Agent→Editor: reads JSON-RPC requests from stdin.
type McpBackend struct {
	connected bool
	scanner   *bufio.Scanner
	nextID    int
}

// NewMcpBackend creates a new MCP stdio backend.
func NewMcpBackend() *McpBackend {
	return &McpBackend{
		scanner: bufio.NewScanner(os.Stdin),
	}
}

func (b *McpBackend) Connect(_ Config) error {
	b.connected = true
	return nil
}

func (b *McpBackend) Disconnect() {
	b.connected = false
}

func (b *McpBackend) SendContext(ctx EditorContext) error {
	if !b.connected {
		return nil
	}
	msg := map[string]any{
		"jsonrpc": "2.0",
		"method":  "editor/context",
		"params":  ctx,
	}
	data, err := json.Marshal(msg)
	if err != nil {
		return err
	}
	_, err = fmt.Fprintln(os.Stdout, string(data))
	return err
}

func (b *McpBackend) SendEvent(event Event) error {
	if !b.connected {
		return nil
	}
	method := "editor/" + strings.ReplaceAll(string(event.Type), "_", "")
	msg := map[string]any{
		"jsonrpc": "2.0",
		"method":  method,
		"params":  event,
	}
	data, err := json.Marshal(msg)
	if err != nil {
		return err
	}
	_, err = fmt.Fprintln(os.Stdout, string(data))
	return err
}

func (b *McpBackend) PollCommand() (*Command, error) {
	if !b.connected {
		return nil, nil
	}
	// Non-blocking stdin isn't practical in Go without goroutines.
	// In real usage, this would run in a goroutine with a channel.
	// For now, return nil (no pending command).
	return nil, nil
}

func (b *McpBackend) IsConnected() bool {
	return b.connected
}

func (b *McpBackend) Info() BackendInfo {
	return BackendInfo{
		Name:      "mcp",
		Transport: TransportStdio,
	}
}
