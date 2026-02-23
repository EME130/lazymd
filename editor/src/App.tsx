import { useState, useCallback } from 'react';
import { useConnection } from './hooks/useConnection';
import { useDocument } from './hooks/useDocument';
import { EditorPanel } from './components/EditorPanel';
import { PreviewPanel } from './components/PreviewPanel';
import { FileTree } from './components/FileTree';
import { BrainGraph } from './components/BrainGraph';
import { StatusBar } from './components/StatusBar';
import { ConnectDialog } from './components/ConnectDialog';

type RightPanel = 'preview' | 'brain' | 'none';

export function App() {
  const { status, connect, disconnect } = useConnection();
  const { state, openFile, updateContent, saveDocument } = useDocument();
  const [showConnect, setShowConnect] = useState(true);
  const [connectError, setConnectError] = useState<string>();
  const [rightPanel, setRightPanel] = useState<RightPanel>('preview');

  const connected = status === 'connected';

  const handleConnect = useCallback(async (url: string) => {
    setConnectError(undefined);
    try {
      await connect(url);
      setShowConnect(false);
    } catch {
      setConnectError('Failed to connect. Is lazy-md --web-server running?');
    }
  }, [connect]);

  const handleDisconnect = useCallback(() => {
    disconnect();
    setShowConnect(true);
  }, [disconnect]);

  const handleSave = useCallback(() => {
    if (state.content) {
      saveDocument(state.content);
    }
  }, [state.content, saveDocument]);

  return (
    <div className="app">
      {showConnect && (
        <ConnectDialog
          onConnect={handleConnect}
          onCancel={() => { if (connected) setShowConnect(false); }}
          error={connectError}
        />
      )}

      <nav className="tab-bar" aria-label="View tabs">
        <button
          className={`tab-bar__tab ${rightPanel === 'preview' ? 'tab-bar__tab--active' : ''}`}
          onClick={() => setRightPanel(rightPanel === 'preview' ? 'none' : 'preview')}
          aria-pressed={rightPanel === 'preview'}
        >
          Preview
        </button>
        <button
          className={`tab-bar__tab ${rightPanel === 'brain' ? 'tab-bar__tab--active' : ''}`}
          onClick={() => setRightPanel(rightPanel === 'brain' ? 'none' : 'brain')}
          aria-pressed={rightPanel === 'brain'}
        >
          Brain
        </button>
        <div style={{ flex: 1 }} />
        {connected && (
          <button
            className="tab-bar__tab"
            onClick={handleDisconnect}
            style={{ color: 'var(--red)' }}
          >
            Disconnect
          </button>
        )}
      </nav>

      <main className="main-layout">
        <FileTree
          connected={connected}
          currentFile={state.filePath}
          onOpenFile={openFile}
        />

        <div className="split-horizontal">
          <div className="editor-area">
            <EditorPanel
              content={state.content}
              onChange={updateContent}
              onSave={handleSave}
            />
          </div>

          {rightPanel === 'preview' && (
            <PreviewPanel content={state.content} />
          )}

          {rightPanel === 'brain' && (
            <BrainGraph connected={connected} />
          )}
        </div>
      </main>

      <StatusBar
        state={state}
        connectionStatus={status}
        onConnectionClick={() => setShowConnect(true)}
      />
    </div>
  );
}
