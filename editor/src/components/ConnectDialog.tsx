import { useState, useRef, useEffect, useCallback } from 'react';

interface Props {
  onConnect: (url: string) => void;
  onCancel: () => void;
  error?: string;
}

export function ConnectDialog({ onConnect, onCancel, error }: Props) {
  const [url, setUrl] = useState('ws://localhost:8080');
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    inputRef.current?.focus();
    inputRef.current?.select();
  }, []);

  const handleKeyDown = useCallback((e: React.KeyboardEvent) => {
    if (e.key === 'Escape') {
      onCancel();
    }
  }, [onCancel]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (url.trim()) {
      onConnect(url.trim());
    }
  };

  return (
    <div className="connect-overlay" onClick={onCancel} onKeyDown={handleKeyDown}>
      <form
        className="connect-dialog"
        onClick={e => e.stopPropagation()}
        onSubmit={handleSubmit}
        role="dialog"
        aria-labelledby="connect-dialog-title"
      >
        <h2 id="connect-dialog-title" className="connect-dialog__title">Connect to lazy-md</h2>
        <p className="connect-dialog__subtitle">
          Enter the WebSocket URL of your lazy-md server (lazy-md --web-server)
        </p>
        {error && <div className="connect-dialog__error" role="alert" aria-live="polite">{error}</div>}
        <label htmlFor="ws-url" className="sr-only">WebSocket URL</label>
        <input
          id="ws-url"
          ref={inputRef}
          className="connect-dialog__input"
          value={url}
          onChange={e => setUrl(e.target.value)}
          placeholder="ws://localhost:8080"
          name="ws-url"
          autoComplete="url"
          spellCheck={false}
        />
        <div className="connect-dialog__actions">
          <button type="button" className="connect-dialog__btn" onClick={onCancel}>
            Cancel
          </button>
          <button type="submit" className="connect-dialog__btn connect-dialog__btn--primary">
            Connect
          </button>
        </div>
      </form>
    </div>
  );
}
