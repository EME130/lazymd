// JSON-RPC 2.0 message types for lazy-md WebSocket protocol

export interface JsonRpcRequest {
  jsonrpc: '2.0';
  id: number;
  method: string;
  params?: Record<string, unknown>;
}

export interface JsonRpcNotification {
  jsonrpc: '2.0';
  method: string;
  params?: Record<string, unknown>;
}

export interface JsonRpcResponse {
  jsonrpc: '2.0';
  id: number;
  result?: unknown;
  error?: { code: number; message: string };
}

export type JsonRpcMessage = JsonRpcRequest | JsonRpcNotification | JsonRpcResponse;

// Tool call types
export interface ToolCallParams {
  name: string;
  arguments: Record<string, unknown>;
}

// Server push event types
export interface DocumentChangedEvent {
  content: string;
  version: number;
}

export interface CursorMovedEvent {
  row: number;
  col: number;
}

export interface ModeChangedEvent {
  mode: 'normal' | 'insert' | 'command';
}
