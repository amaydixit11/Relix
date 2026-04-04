'use client';

import { useEffect, useRef, useCallback } from 'react';
import { EditorState, StateEffect, StateField } from '@codemirror/state';
import { EditorView, keymap, Decoration, DecorationSet, ViewPlugin, ViewUpdate, placeholder as cmPlaceholder } from '@codemirror/view';
import { markdown } from '@codemirror/lang-markdown';
import { defaultKeymap, history, historyKeymap } from '@codemirror/commands';
import { oneDark } from '@codemirror/theme-one-dark';
import { syntaxHighlighting, HighlightStyle } from '@codemirror/language';
import { tags } from '@lezer/highlight';

// Wikilink decoration
const wikilinkMatcher = /\[\[([^\]]+)\]\]/g;

const wikilinkDecoration = Decoration.mark({
  class: 'cm-wikilink',
});

function getWikilinkDecorations(view: EditorView): DecorationSet {
  const decorations: { from: number; to: number }[] = [];
  const doc = view.state.doc.toString();
  let match;

  while ((match = wikilinkMatcher.exec(doc)) !== null) {
    decorations.push({
      from: match.index,
      to: match.index + match[0].length,
    });
  }

  return Decoration.set(
    decorations.map(d => wikilinkDecoration.range(d.from, d.to))
  );
}

const wikilinkPlugin = ViewPlugin.fromClass(
  class {
    decorations: DecorationSet;

    constructor(view: EditorView) {
      this.decorations = getWikilinkDecorations(view);
    }

    update(update: ViewUpdate) {
      if (update.docChanged) {
        this.decorations = getWikilinkDecorations(update.view);
      }
    }
  },
  {
    decorations: v => v.decorations,
  }
);

// Custom theme
const editorTheme = EditorView.theme({
  '&': {
    height: '100%',
    fontSize: '14px',
  },
  '.cm-content': {
    fontFamily: 'ui-monospace, SFMono-Regular, Menlo, Monaco, monospace',
    padding: '16px',
  },
  '.cm-line': {
    padding: '0 4px',
  },
  '.cm-wikilink': {
    color: '#6366f1',
    backgroundColor: 'rgba(99, 102, 241, 0.1)',
    borderRadius: '3px',
    padding: '1px 2px',
    cursor: 'pointer',
    transition: 'background-color 0.2s',
  },
  '.cm-wikilink:hover': {
    backgroundColor: 'rgba(99, 102, 241, 0.2)',
  },
  '.cm-scroller': {
    overflow: 'auto',
  },
  '&.cm-focused': {
    outline: 'none',
  },
});

// Highlight style
const highlightStyle = HighlightStyle.define([
  { tag: tags.heading1, fontSize: '1.5em', fontWeight: 'bold', color: 'var(--text-primary)' },
  { tag: tags.heading2, fontSize: '1.3em', fontWeight: 'bold', color: 'var(--text-primary)' },
  { tag: tags.heading3, fontSize: '1.15em', fontWeight: 'bold', color: 'var(--text-primary)' },
  { tag: tags.emphasis, fontStyle: 'italic' },
  { tag: tags.strong, fontWeight: 'bold' },
  { tag: tags.link, color: '#6366f1' },
  { tag: tags.url, color: '#6366f1' },
  { tag: tags.monospace, backgroundColor: 'rgba(255, 255, 255, 0.1)', borderRadius: '3px' },
]);

interface MarkdownEditorProps {
  value: string;
  onChange?: (value: string) => void;
  onWikilinkClick?: (id: string) => void;
  placeholder?: string;
  className?: string;
  readonly?: boolean;
}

export function MarkdownEditor({ 
  value, 
  onChange, 
  onWikilinkClick,
  placeholder = 'Write in markdown...',
  className = '',
  readonly = false,
}: MarkdownEditorProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const viewRef = useRef<EditorView | null>(null);
  const onChangeRef = useRef(onChange);

  // Keep onChange ref up to date
  useEffect(() => {
    onChangeRef.current = onChange;
  }, [onChange]);

  useEffect(() => {
    if (!containerRef.current) return;

    const updateListener = EditorView.updateListener.of((update) => {
      if (update.docChanged && onChangeRef.current && !readonly) {
        onChangeRef.current(update.state.doc.toString());
      }
    });

    const state = EditorState.create({
      doc: value,
      extensions: [
        markdown(),
        history(),
        keymap.of([
          ...defaultKeymap, 
          ...historyKeymap,
          {
            key: 'Mod-b',
            run: (view) => {
              const { from, to } = view.state.selection.main;
              view.dispatch({
                changes: { from, to, insert: `**${view.state.sliceDoc(from, to)}**` },
                selection: { anchor: from + 2, head: to + 2 }
              });
              return true;
            }
          },
          {
            key: 'Mod-i',
            run: (view) => {
              const { from, to } = view.state.selection.main;
              view.dispatch({
                changes: { from, to, insert: `_${view.state.sliceDoc(from, to)}_` },
                selection: { anchor: from + 1, head: to + 1 }
              });
              return true;
            }
          },
          {
            key: 'Mod-l', // mod-l for link
            run: (view) => {
              const { from, to } = view.state.selection.main;
              view.dispatch({
                changes: { from, to, insert: `[[${view.state.sliceDoc(from, to)}]]` },
                selection: { anchor: from + 2, head: to + 2 }
              });
              return true;
            }
          }
        ]),
        oneDark,
        editorTheme,
        syntaxHighlighting(highlightStyle),
        wikilinkPlugin,
        updateListener,
        EditorView.lineWrapping,
        EditorState.tabSize.of(2),
        EditorState.readOnly.of(readonly),
        EditorView.editable.of(!readonly),
        cmPlaceholder(placeholder),
      ],
    });

    const onClick = (e: MouseEvent) => {
      const target = e.target as HTMLElement;
      if (target.classList.contains('cm-wikilink') && onWikilinkClick) {
        const text = target.innerText;
        const idMatch = text.match(/\[\[([^\]]+)\]\]/);
        if (idMatch) {
          onWikilinkClick(idMatch[1].trim());
        }
      }
    };

    containerRef.current.addEventListener('click', onClick);

    const view = new EditorView({
      state,
      parent: containerRef.current,
    });

    viewRef.current = view;

    return () => {
      if (containerRef.current) {
        containerRef.current.removeEventListener('click', onClick);
      }
      view.destroy();
      viewRef.current = null;
    };
  }, []); // Only run once on mount

  // Sync external value changes
  useEffect(() => {
    if (!viewRef.current) return;
    
    const currentValue = viewRef.current.state.doc.toString();
    if (value !== currentValue) {
      viewRef.current.dispatch({
        changes: {
          from: 0,
          to: currentValue.length,
          insert: value,
        },
      });
    }
  }, [value]);

  return (
    <div 
      ref={containerRef} 
      className={className}
      style={{
        height: '100%',
        background: 'var(--bg-secondary)',
        borderRadius: '8px',
        border: '1px solid var(--border)',
        overflow: 'hidden',
      }}
    />
  );
}

export default MarkdownEditor;
