import { useState, useEffect, useCallback } from 'react';
import { client } from '../protocol/client';

interface Props {
  connected: boolean;
  currentFile: string | null;
  onOpenFile: (path: string) => void;
}

interface FileEntry {
  name: string;
  path: string;
}

export function FileTree({ connected, currentFile, onOpenFile }: Props) {
  const [files, setFiles] = useState<FileEntry[]>([]);

  const refresh = useCallback(async () => {
    if (!connected) return;
    try {
      const result = await client.callTool('get_structure') as { content?: Array<{ text: string }> };
      if (result?.content?.[0]?.text) {
        const text = result.content[0].text;
        try {
          const parsed = JSON.parse(text);
          if (Array.isArray(parsed)) {
            setFiles(parsed.map((f: string | { name: string; path: string }) =>
              typeof f === 'string' ? { name: f, path: f } : f
            ));
          }
        } catch {
          setFiles([]);
        }
      }
    } catch {
      // Tool not available or error
    }
  }, [connected]);

  useEffect(() => {
    refresh();
  }, [refresh]);

  return (
    <nav className="file-tree" aria-label="File explorer">
      <div className="file-tree__header">Explorer</div>
      <div className="file-tree__list" role="list">
        {files.length === 0 && connected && (
          <div className="file-tree__item" role="listitem" style={{ color: 'var(--text-muted)', fontStyle: 'italic' }}>
            No files loaded
          </div>
        )}
        {!connected && (
          <div className="file-tree__item" role="listitem" style={{ color: 'var(--text-muted)', fontStyle: 'italic' }}>
            Not connected
          </div>
        )}
        {files.map(file => (
          <button
            key={file.path}
            role="listitem"
            className={`file-tree__item ${currentFile === file.path ? 'file-tree__item--active' : ''}`}
            onClick={() => onOpenFile(file.path)}
          >
            {file.name}
          </button>
        ))}
      </div>
    </nav>
  );
}
