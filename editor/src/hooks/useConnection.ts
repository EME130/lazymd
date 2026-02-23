import { useState, useCallback, useEffect, useRef } from 'react';
import { client } from '../protocol/client';
import type { ConnectionStatus } from '../types/editor';

export function useConnection() {
  const [status, setStatus] = useState<ConnectionStatus>('disconnected');
  const [url, setUrl] = useState<string>('');
  const reconnectTimer = useRef<ReturnType<typeof setTimeout>>();

  const connect = useCallback(async (wsUrl: string) => {
    setStatus('connecting');
    setUrl(wsUrl);
    try {
      await client.connect(wsUrl);
      setStatus('connected');
    } catch {
      setStatus('error');
    }
  }, []);

  const disconnect = useCallback(() => {
    client.disconnect();
    setStatus('disconnected');
    setUrl('');
    if (reconnectTimer.current) {
      clearTimeout(reconnectTimer.current);
    }
  }, []);

  useEffect(() => {
    const unsub = client.onMessage(() => {
      // If we get any message, we're connected
      if (!client.connected && status === 'connected') {
        setStatus('disconnected');
      }
    });

    // Poll connection state
    const interval = setInterval(() => {
      if (status === 'connected' && !client.connected) {
        setStatus('disconnected');
        // Auto-reconnect
        if (url) {
          reconnectTimer.current = setTimeout(() => connect(url), 3000);
        }
      }
    }, 1000);

    return () => {
      unsub();
      clearInterval(interval);
    };
  }, [status, url, connect]);

  return { status, url, connect, disconnect, client };
}
