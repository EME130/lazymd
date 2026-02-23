import type { EditorState, ConnectionStatus } from '../types/editor';

interface Props {
  state: EditorState;
  connectionStatus: ConnectionStatus;
  onConnectionClick: () => void;
}

export function StatusBar({ state, connectionStatus, onConnectionClick }: Props) {
  return (
    <footer className="status-bar">
      <span className={`status-bar__mode status-bar__mode--${state.mode}`}>
        {state.mode}
      </span>
      <span className="status-bar__file">
        {state.filePath || '[No file]'}
      </span>
      {state.dirty && <span className="status-bar__dirty">[+]</span>}
      <span className="status-bar__spacer" />
      <span className="status-bar__cursor">
        Ln {state.cursorRow + 1}, Col {state.cursorCol + 1}
      </span>
      <button
        className="status-bar__connection"
        onClick={onConnectionClick}
        aria-label={`Connection status: ${connectionStatus}. Click to connect.`}
      >
        <span className={`status-bar__dot status-bar__dot--${connectionStatus}`} aria-hidden="true" />
        <span>{connectionStatus}</span>
      </button>
    </footer>
  );
}
