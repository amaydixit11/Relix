'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useNotes } from '@relix/core';
import { PageLayout } from '@/components';

export default function NotesPage() {
  const [search, setSearch] = useState('');
  const { data: notes, isLoading } = useNotes();

  const filteredNotes = notes?.filter(n => 
    n.content.title.toLowerCase().includes(search.toLowerCase()) ||
    n.tags.some(t => t.toLowerCase().includes(search.toLowerCase()))
  ) || [];

  return (
    <PageLayout>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2rem' }}>
        <h1 style={{ fontSize: '1.75rem', fontWeight: 700 }}>Notes</h1>
        <Link href="/notes/new">
          <button className="primary">New Note</button>
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
            borderRadius: '8px',
            background: 'var(--bg-secondary)',
            border: '1px solid var(--border)',
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
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))', gap: '1rem' }}>
          {filteredNotes.map((note) => (
            <Link 
              key={note.id} 
              href={`/notes/${note.id}`}
              style={{
                display: 'block',
                background: 'var(--bg-secondary)',
                borderRadius: '8px',
                border: '1px solid var(--border)',
                padding: '1.25rem',
                transition: 'all 0.15s ease',
              }}
            >
              <div style={{ fontWeight: 600, fontSize: '1rem', marginBottom: '0.5rem', color: 'var(--text-primary)' }}>
                {note.content.title}
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
                {note.content.body}
              </div>
              <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
                {note.tags
                  .filter(t => !t.startsWith('backlink:') && !t.startsWith('outlink:'))
                  .slice(0, 3)
                  .map(t => (
                    <span key={t} style={{
                      fontSize: '0.75rem',
                      color: 'var(--text-muted)',
                      background: 'var(--bg-primary)',
                      padding: '2px 6px',
                      borderRadius: '4px',
                      border: '1px solid var(--border)',
                    }}>
                      #{t}
                    </span>
                  ))}
              </div>
            </Link>
          ))}
        </div>
      )}
    </PageLayout>
  );
}
