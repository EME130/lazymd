import { useState, useEffect, useCallback, useRef } from 'react';
import { client } from '../protocol/client';
import type { EditorState, Heading } from '../types/editor';
import type { JsonRpcMessage, JsonRpcNotification } from '../types/protocol';

const initialState: EditorState = {
  content: '',
  filePath: null,
  cursorRow: 0,
  cursorCol: 0,
  mode: 'normal',
  dirty: false,
};

export function useDocument() {
  const [state, setState] = useState<EditorState>(initialState);
  const [headings, setHeadings] = useState<Heading[]>([]);
  const versionRef = useRef(0);

  // Listen for server push events
  useEffect(() => {
    const unsub = client.onMessage((msg: JsonRpcMessage) => {
      if (!('method' in msg)) return;
      const notif = msg as JsonRpcNotification;

      switch (notif.method) {
        case 'document/changed': {
          const p = notif.params as { content: string; version: number } | undefined;
          if (p && p.version > versionRef.current) {
            versionRef.current = p.version;
            setState(prev => ({ ...prev, content: p.content, dirty: false }));
          }
          break;
        }
        case 'cursor/moved': {
          const p = notif.params as { row: number; col: number } | undefined;
          if (p) {
            setState(prev => ({ ...prev, cursorRow: p.row, cursorCol: p.col }));
          }
          break;
        }
        case 'mode/changed': {
          const p = notif.params as { mode: 'normal' | 'insert' | 'command' } | undefined;
          if (p) {
            setState(prev => ({ ...prev, mode: p.mode }));
          }
          break;
        }
      }
    });
    return unsub;
  }, []);

  const openFile = useCallback(async (path: string) => {
    const result = await client.callTool('open_file', { path }) as { content?: Array<{ text: string }> };
    if (result?.content?.[0]?.text) {
      setState(prev => ({ ...prev, filePath: path }));
      await refreshContent();
    }
  }, []);

  const refreshContent = useCallback(async () => {
    const result = await client.callTool('read_document') as { content?: Array<{ text: string }> };
    if (result?.content?.[0]?.text) {
      setState(prev => ({ ...prev, content: result.content![0].text }));
    }
  }, []);

  const saveDocument = useCallback(async (content: string) => {
    await client.callTool('write_document', { content });
    setState(prev => ({ ...prev, dirty: false }));
  }, []);

  const updateContent = useCallback(async (content: string) => {
    setState(prev => ({ ...prev, content, dirty: true }));
    await client.callTool('write_document', { content });
    setState(prev => ({ ...prev, dirty: false }));
  }, []);

  const refreshHeadings = useCallback(async () => {
    const result = await client.callTool('list_headings') as { content?: Array<{ text: string }> };
    if (result?.content?.[0]?.text) {
      try {
        const parsed = JSON.parse(result.content[0].text);
        setHeadings(Array.isArray(parsed) ? parsed : []);
      } catch {
        setHeadings([]);
      }
    }
  }, []);

  return {
    state,
    headings,
    openFile,
    refreshContent,
    saveDocument,
    updateContent,
    refreshHeadings,
  };
}
