'use client';

import { useState, useEffect, useRef, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import { useNoteSearch, noteService } from '@relix/core';

interface CommandPaletteProps {
  isOpen: boolean;
  onClose: () => void;
}

interface Command {
  id: string;
  label: string;
  shortcut?: string;
  icon?: string;
  action: () => void;
}

export function CommandPalette({ isOpen, onClose }: CommandPaletteProps) {
  const router = useRouter();
  const inputRef = useRef<HTMLInputElement>(null);
  const [query, setQuery] = useState('');
  const [selectedIndex, setSelectedIndex] = useState(0);
  
  const { data: searchResults } = useNoteSearch(query);

  const commands: Command[] = [
    { id: 'new-note', label: 'New Note', shortcut: '⌘N', icon: '✏️', action: () => router.push('/notes/new') },
    { id: 'all-notes', label: 'All Notes', shortcut: '⌘⇧N', icon: '📝', action: () => router.push('/notes') },
    { id: 'graph', label: 'Graph View', shortcut: '⌘G', icon: '🕸️', action: () => router.push('/graph') },
    { id: 'files', label: 'Files', icon: '📁', action: () => router.push('/files') },
    { id: 'settings', label: 'Settings', shortcut: '⌘,', icon: '⚙️', action: () => router.push('/settings') },
    { id: 'daily', label: 'Today\'s Note', shortcut: '⌘D', icon: '📅', action: () => createDailyNote() },
  ];

  const createDailyNote = async () => {
    const today = new Date().toISOString().split('T')[0];
    const title = `Daily Note - ${today}`;
    
    try {
      const note = await noteService.create(title, `# ${today}\n\n`, ['daily']);
      router.push(`/notes/${note.id}`);
    } catch {
      // Note might already exist, search for it
      router.push(`/notes?search=${encodeURIComponent(title)}`);
    }
  };

  // Filter commands and notes
  const filteredCommands = query.length === 0 
    ? commands 
    : commands.filter(c => c.label.toLowerCase().includes(query.toLowerCase()));

  const allItems = [
    ...filteredCommands.map(c => ({ type: 'command' as const, ...c })),
    ...(searchResults || []).map(note => ({
      type: 'note' as const,
      id: note.id,
      label: note.content.title,
      icon: '📄',
      action: () => router.push(`/notes/${note.id}`),
    })),
  ];

  // Keyboard navigation
  const handleKeyDown = useCallback((e: KeyboardEvent) => {
    if (!isOpen) return;

    switch (e.key) {
      case 'ArrowDown':
        e.preventDefault();
        setSelectedIndex(i => Math.min(i + 1, allItems.length - 1));
        break;
      case 'ArrowUp':
        e.preventDefault();
        setSelectedIndex(i => Math.max(i - 1, 0));
        break;
      case 'Enter':
        e.preventDefault();
        if (allItems[selectedIndex]) {
          allItems[selectedIndex].action();
          onClose();
        }
        break;
      case 'Escape':
        onClose();
        break;
    }
  }, [isOpen, allItems, selectedIndex, onClose]);

  useEffect(() => {
    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [handleKeyDown]);

  useEffect(() => {
    if (isOpen) {
      inputRef.current?.focus();
      setQuery('');
      setSelectedIndex(0);
    }
  }, [isOpen]);

  useEffect(() => {
    setSelectedIndex(0);
  }, [query]);

  if (!isOpen) return null;

  return (
    <div 
      style={{
        position: 'fixed',
        inset: 0,
        background: 'rgba(0, 0, 0, 0.7)',
        display: 'flex',
        justifyContent: 'center',
        paddingTop: '15vh',
        zIndex: 1000,
      }}
      onClick={onClose}
    >
      <div 
        style={{
          background: 'var(--bg-primary)',
          border: '1px solid var(--border)',
          borderRadius: '12px',
          width: '100%',
          maxWidth: '600px',
          maxHeight: '60vh',
          overflow: 'hidden',
          boxShadow: '0 25px 50px -12px rgba(0, 0, 0, 0.5)',
        }}
        onClick={e => e.stopPropagation()}
      >
        {/* Search Input */}
        <div style={{ padding: '16px', borderBottom: '1px solid var(--border)' }}>
          <input
            ref={inputRef}
            type="text"
            value={query}
            onChange={e => setQuery(e.target.value)}
            placeholder="Type a command or search notes..."
            style={{
              width: '100%',
              background: 'transparent',
              border: 'none',
              fontSize: '16px',
              outline: 'none',
              color: 'var(--text-primary)',
            }}
          />
        </div>

        {/* Results */}
        <div style={{ maxHeight: '400px', overflow: 'auto' }}>
          {allItems.length === 0 ? (
            <div style={{ padding: '24px', textAlign: 'center', color: 'var(--text-muted)' }}>
              No results found
            </div>
          ) : (
            allItems.map((item, i) => (
              <div
                key={item.id}
                onClick={() => { item.action(); onClose(); }}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  padding: '12px 16px',
                  cursor: 'pointer',
                  background: i === selectedIndex ? 'var(--bg-secondary)' : 'transparent',
                  borderLeft: i === selectedIndex ? '2px solid var(--accent)' : '2px solid transparent',
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                  <span style={{ fontSize: '16px' }}>{item.icon}</span>
                  <span>{item.label}</span>
                  {item.type === 'note' && (
                    <span style={{ 
                      fontSize: '10px', 
                      background: 'var(--bg-tertiary)', 
                      padding: '2px 6px', 
                      borderRadius: '4px',
                      color: 'var(--text-muted)',
                    }}>
                      note
                    </span>
                  )}
                </div>
                {'shortcut' in item && item.shortcut && (
                  <span style={{ 
                    fontSize: '12px', 
                    color: 'var(--text-muted)',
                    fontFamily: 'monospace',
                  }}>
                    {item.shortcut}
                  </span>
                )}
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
}

export default CommandPalette;
