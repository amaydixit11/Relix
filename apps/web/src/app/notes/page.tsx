'use client';

import { useState, useMemo } from 'react';
import Link from 'next/link';
import { useNotes } from '@relix/core';
import { PageLayout } from '@/components';

export default function NotesPage() {
  const [search, setSearch] = useState('');
  const [displayCount, setDisplayCount] = useState(24);
  const { data: notes, isLoading } = useNotes();

  // 1. Filter ALL notes by search
  const filteredNotes = useMemo(() => {
    if (!notes) return [];
    
    const query = search.toLowerCase();
    return notes.filter(n => {
      const title = n.content?.title || '';
      const body = n.content?.body || '';
      const tags = n.tags || [];
      
      return title.toLowerCase().includes(query) ||
             body.toLowerCase().includes(query) ||
             tags.some(t => t.toLowerCase().includes(query));
    });
  }, [notes, search]);

  // 2. Slice for pagination
  const paginatedNotes = useMemo(() => {
    return filteredNotes.slice(0, displayCount);
  }, [filteredNotes, displayCount]);

  return (
    <PageLayout>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2rem' }}>
        <h1 style={{ fontSize: '1.75rem', fontWeight: 700 }}>Notes</h1>
        <Link href="/notes/new">
          <button className="primary" style={{ padding: '8px 16px', borderRadius: '8px', cursor: 'pointer' }}>New Note</button>
        </Link>
      </div>

      {/* Search Bar */}
      <div style={{ marginBottom: '1.5rem' }}>
        <input
          type="text"
          placeholder="Filter notes..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          style={{
            width: '100%',
            padding: '0.75rem 1rem',
            fontSize: '0.95rem',
            borderRadius: '12px',
            background: 'var(--bg-secondary)',
            border: '1px solid var(--border)',
            color: 'var(--text-primary)',
            outline: 'none',
          }}
        />
      </div>

      {/* Notes Grid */}
      {isLoading ? (
        <div style={{ color: 'var(--text-muted)' }}>Loading...</div>
      ) : filteredNotes.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '3rem', color: 'var(--text-muted)' }}>
          {search ? 'No notes match your search' : 'No notes yet'}
        </div>
      ) : (
        <>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))', gap: '1.25rem' }}>
            {paginatedNotes.map((note) => (
              <Link 
                key={note.id} 
                href={`/notes/${note.id}`}
                style={{
                  display: 'block',
                  background: 'var(--bg-secondary)',
                  borderRadius: '12px',
                  border: '1px solid var(--border)',
                  padding: '1.5rem',
                  transition: 'all 0.2s ease',
                  textDecoration: 'none',
                }}
              >
                <div style={{ fontWeight: 600, fontSize: '1.1rem', marginBottom: '0.5rem', color: 'var(--text-primary)' }}>
                  {note.content?.title || 'Untitled'}
                </div>
                <div style={{ 
                  fontSize: '0.85rem', 
                  color: 'var(--text-secondary)',
                  display: '-webkit-box',
                  WebkitLineClamp: 3,
                  WebkitBoxOrient: 'vertical',
                  overflow: 'hidden',
                  marginBottom: '1rem',
                  lineHeight: 1.5,
                }}>
                  {note.content?.body || ''}
                </div>
                <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
                  {(note.tags || [])
                    .filter(t => !t.startsWith('backlink:') && !t.startsWith('outlink:'))
                    .slice(0, 3)
                    .map(t => (
                      <span key={t} style={{
                        fontSize: '0.7rem',
                        color: 'var(--accent)',
                        background: 'rgba(99, 102, 241, 0.1)',
                        padding: '2px 8px',
                        borderRadius: '4px',
                      }}>
                        #{t}
                      </span>
                    ))}
                </div>
              </Link>
            ))}
          </div>
          
          {filteredNotes.length > displayCount && (
            <div style={{ display: 'flex', justifyContent: 'center', marginTop: '3rem', marginBottom: '2rem' }}>
              <button 
                onClick={() => setDisplayCount(c => c + 24)}
                style={{ 
                  background: 'var(--bg-secondary)', 
                  border: '1px solid var(--border)', 
                  padding: '10px 24px', 
                  borderRadius: '10px',
                  color: 'var(--text-primary)',
                  cursor: 'pointer' 
                }}
              >
                Load More
              </button>
            </div>
          )}
        </>
      )}
    </PageLayout>
  );
}
