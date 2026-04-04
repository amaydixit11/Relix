'use client';

import { useState, useRef, useEffect } from 'react';
import { useCreateNote } from '@relix/core';

interface QuickCaptureProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess?: (noteId: string) => void;
}

export function QuickCapture({ isOpen, onClose, onSuccess }: QuickCaptureProps) {
  const inputRef = useRef<HTMLTextAreaElement>(null);
  const [content, setContent] = useState('');
  
  const createNote = useCreateNote({
    onSuccess: (note) => {
      setContent('');
      onClose();
      onSuccess?.(note.id);
    },
  });

  useEffect(() => {
    if (isOpen) {
      inputRef.current?.focus();
    }
  }, [isOpen]);

  // Handle keyboard
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (!isOpen) return;
      
      if (e.key === 'Escape') {
        onClose();
      } else if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) {
        handleSubmit();
      }
    };

    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, content]);

  const handleSubmit = () => {
    if (!content.trim()) return;

    const lines = content.split('\n');
    const firstLine = lines[0].trim();
    
    // Extract title
    let title = firstLine.replace(/^#\s*/, '').trim();
    let body = '';
    
    if (lines.length === 1) {
      if (!title || title.length < 2) {
        title = `Quick Note - ${new Date().toLocaleTimeString()}`;
        body = content;
      } else {
        // One line is just the title
        body = '';
      }
    } else {
      // Multiple lines: first is title, rest is body
      body = lines.slice(1).join('\n').trim();
      if (!title || title.length < 2) {
         title = `Quick Note - ${new Date().toLocaleTimeString()}`;
         body = content; // Keep the whole thing in body if title is empty
      }
    }

    createNote.mutate({ 
      title, 
      body,
      tags: ['quick-capture'],
    });
  };

  if (!isOpen) return null;

  return (
    <div 
      style={{
        position: 'fixed',
        bottom: '24px',
        right: '24px',
        width: '400px',
        background: 'var(--bg-primary)',
        border: '1px solid var(--border)',
        borderRadius: '12px',
        boxShadow: '0 25px 50px -12px rgba(0, 0, 0, 0.5)',
        zIndex: 1000,
        overflow: 'hidden',
      }}
    >
      <div style={{ 
        padding: '12px 16px',
        borderBottom: '1px solid var(--border)',
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
      }}>
        <span style={{ fontWeight: 500, fontSize: '0.875rem' }}>Quick Capture</span>
        <button 
          onClick={onClose}
          style={{ 
            background: 'transparent', 
            padding: '4px 8px',
            fontSize: '0.75rem',
            color: 'var(--text-muted)',
          }}
        >
          ✕
        </button>
      </div>

      <div style={{ padding: '12px' }}>
        <textarea
          ref={inputRef}
          value={content}
          onChange={(e) => setContent(e.target.value)}
          placeholder="Capture a thought...&#10;First line becomes the title"
          style={{
            width: '100%',
            minHeight: '120px',
            background: 'var(--bg-secondary)',
            border: '1px solid var(--border)',
            borderRadius: '8px',
            padding: '12px',
            color: 'var(--text-primary)',
            fontSize: '0.875rem',
            resize: 'vertical',
            fontFamily: 'inherit',
          }}
        />
      </div>

      <div style={{ 
        padding: '12px',
        borderTop: '1px solid var(--border)',
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
      }}>
        <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
          ⌘↵ to save
        </span>
        <button 
          onClick={handleSubmit}
          disabled={!content.trim() || createNote.isPending}
        >
          {createNote.isPending ? 'Saving...' : 'Save Note'}
        </button>
      </div>
    </div>
  );
}

export default QuickCapture;
