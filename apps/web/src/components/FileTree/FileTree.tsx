'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useNotes } from '@relix/core';

export function FileTree() {
  const { data: notes } = useNotes();
  const [expandedTags, setExpandedTags] = useState<string[]>([]);

  // Group notes by tags (simulate folders)
  const notesByTag: Record<string, typeof notes> = {};
  const untaggedNotes: typeof notes = [];

  notes?.forEach(note => {
    const userTags = (note.tags || []).filter(
      tag => !tag.startsWith('backlink:') && !tag.startsWith('outlink:')
    );

    if (userTags.length === 0) {
      untaggedNotes.push(note);
    } else {
      userTags.forEach(tag => {
        if (!notesByTag[tag]) notesByTag[tag] = [];
        notesByTag[tag].push(note);
      });
    }
  });

  const toggleTag = (tag: string) => {
    setExpandedTags(prev => 
      prev.includes(tag) ? prev.filter(t => t !== tag) : [...prev, tag]
    );
  };

  return (
    <div style={{
      width: '250px',
      height: '100%',
      borderRight: '1px solid var(--border)',
      background: 'var(--bg-secondary)',
      display: 'flex',
      flexDirection: 'column',
      overflow: 'hidden',
    }}>
      <div style={{ padding: '10px', fontWeight: 'bold', borderBottom: '1px solid var(--border)' }}>
        Explorer
      </div>
      
      <div style={{ flex: 1, overflowY: 'auto', padding: '10px' }}>
        {/* Tags as Folders */}
        {Object.entries(notesByTag).map(([tag, taggedNotes]) => (
          <div key={tag}>
            <div 
              onClick={() => toggleTag(tag)}
              style={{ 
                cursor: 'pointer', 
                padding: '4px 0', 
                display: 'flex', 
                alignItems: 'center',
                color: 'var(--text-secondary)',
                fontSize: '0.9rem'
              }}
            >
              <span style={{ marginRight: '5px', fontSize: '0.8rem' }}>
                {expandedTags.includes(tag) ? '▼' : '▶'}
              </span>
              📁 {tag}
            </div>
            
            {expandedTags.includes(tag) && taggedNotes && (
              <div style={{ paddingLeft: '20px', borderLeft: '1px solid var(--border-light)' }}>
                {taggedNotes.map(note => (
                  <Link 
                    key={`${tag}-${note.id}`} 
                    href={`/notes/${note.id}`}
                    style={{
                      display: 'block',
                      padding: '2px 0',
                      color: 'var(--text-primary)',
                      fontSize: '0.9rem',
                      textDecoration: 'none',
                      whiteSpace: 'nowrap',
                      overflow: 'hidden',
                      textOverflow: 'ellipsis'
                    }}
                  >
                    📄 {note.content?.title || 'Untitled'}
                  </Link>
                ))}
              </div>
            )}
          </div>
        ))}

        {/* Untagged Notes */}
        {untaggedNotes.length > 0 && (
          <div style={{ marginTop: '10px' }}>
            <div style={{ color: 'var(--text-secondary)', fontSize: '0.8rem', marginBottom: '5px' }}>
              Root
            </div>
            {untaggedNotes.map(note => (
              <Link 
                key={note.id} 
                href={`/notes/${note.id}`}
                style={{
                  display: 'block',
                  padding: '2px 0',
                  color: 'var(--text-primary)',
                  fontSize: '0.9rem',
                  textDecoration: 'none'
                }}
              >
                📄 {note.content?.title || 'Untitled'}
              </Link>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
