// WebSocket MCP client — connects to lazy-md --web-server backend

import type { JsonRpcRequest, JsonRpcResponse, JsonRpcMessage } from '../types/protocol';

type MessageHandler = (message: JsonRpcMessage) => void;

export class McpClient {
  private ws: WebSocket | null = null;
  private nextId = 1;
  private pending = new Map<number, { resolve: (v: unknown) => void; reject: (e: Error) => void }>();
  private handlers: MessageHandler[] = [];

  get connected(): boolean {
    return this.ws?.readyState === WebSocket.OPEN;
  }

  connect(url: string): Promise<void> {
    return new Promise((resolve, reject) => {
      this.ws = new WebSocket(url);

      this.ws.onopen = () => {
        this.initialize().then(() => resolve()).catch(reject);
      };

      this.ws.onclose = () => {
        this.ws = null;
        this.pending.forEach(p => p.reject(new Error('Connection closed')));
        this.pending.clear();
      };

      this.ws.onerror = () => {
        reject(new Error('WebSocket connection failed'));
      };

      this.ws.onmessage = (event) => {
        this.handleMessage(event.data as string);
      };
    });
  }

  disconnect(): void {
    this.ws?.close();
    this.ws = null;
  }

  onMessage(handler: MessageHandler): () => void {
    this.handlers.push(handler);
    return () => {
      this.handlers = this.handlers.filter(h => h !== handler);
    };
  }

  async callTool(name: string, args: Record<string, unknown> = {}): Promise<unknown> {
    return this.send('tools/call', { name, arguments: args });
  }

  async send(method: string, params?: Record<string, unknown>): Promise<unknown> {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      throw new Error('Not connected');
    }

    const id = this.nextId++;
    const request: JsonRpcRequest = {
      jsonrpc: '2.0',
      id,
      method,
      params,
    };

    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.ws!.send(JSON.stringify(request));

      // Timeout after 30s
      setTimeout(() => {
        if (this.pending.has(id)) {
          this.pending.delete(id);
          reject(new Error('Request timed out'));
        }
      }, 30000);
    });
  }

  private async initialize(): Promise<void> {
    await this.send('initialize', {
      protocolVersion: '2024-11-05',
      capabilities: {},
      clientInfo: { name: 'lazy-md-web', version: '0.1.0' },
    });
  }

  private handleMessage(data: string): void {
    let message: JsonRpcMessage;
    try {
      message = JSON.parse(data) as JsonRpcMessage;
    } catch {
      return;
    }

    // Handle response to our requests
    if ('id' in message && message.id != null) {
      const response = message as JsonRpcResponse;
      const pending = this.pending.get(response.id);
      if (pending) {
        this.pending.delete(response.id);
        if (response.error) {
          pending.reject(new Error(response.error.message));
        } else {
          pending.resolve(response.result);
        }
        return;
      }
    }

    // Notify handlers for server-initiated messages
    this.handlers.forEach(h => h(message));
  }
}

// Singleton client
export const client = new McpClient();
