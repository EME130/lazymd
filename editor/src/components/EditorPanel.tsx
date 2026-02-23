import { useEffect, useRef } from 'react';
import { EditorView, basicSetup } from 'codemirror';
import { EditorState } from '@codemirror/state';
import { markdown } from '@codemirror/lang-markdown';
import { oneDark } from '@codemirror/theme-one-dark';
import { vim } from '@replit/codemirror-vim';
import { keymap } from '@codemirror/view';

interface Props {
  content: string;
  onChange: (content: string) => void;
  onSave?: () => void;
}

export function EditorPanel({ content, onChange, onSave }: Props) {
  const containerRef = useRef<HTMLDivElement>(null);
  const viewRef = useRef<EditorView>();
  const contentRef = useRef(content);

  useEffect(() => {
    if (!containerRef.current) return;

    const saveKeymap = keymap.of([
      {
        key: 'Ctrl-s',
        run: () => { onSave?.(); return true; },
      },
      {
        key: 'Meta-s',
        run: () => { onSave?.(); return true; },
      },
    ]);

    const state = EditorState.create({
      doc: content,
      extensions: [
        vim(),
        basicSetup,
        markdown(),
        oneDark,
        saveKeymap,
        EditorView.updateListener.of(update => {
          if (update.docChanged) {
            const newContent = update.state.doc.toString();
            contentRef.current = newContent;
            onChange(newContent);
          }
        }),
        EditorView.theme({
          '&': { height: '100%' },
          '.cm-scroller': { overflow: 'auto' },
        }),
      ],
    });

    const view = new EditorView({
      state,
      parent: containerRef.current,
    });

    viewRef.current = view;

    return () => {
      view.destroy();
    };
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  // Update content from external changes (server push)
  useEffect(() => {
    const view = viewRef.current;
    if (!view) return;
    if (content === contentRef.current) return;

    contentRef.current = content;
    const currentContent = view.state.doc.toString();
    if (content !== currentContent) {
      view.dispatch({
        changes: { from: 0, to: currentContent.length, insert: content },
      });
    }
  }, [content]);

  return <div ref={containerRef} className="editor-panel" role="region" aria-label="Editor" />;
}
