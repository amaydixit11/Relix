'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useNotes, useHealthCheck, useVaultStatus } from '@relix/core';
import { PageLayout } from '@/components';

export default function HomePage() {
  const { data: isHealthy, isLoading: healthLoading } = useHealthCheck();
  const { data: status } = useVaultStatus();
  const { data: notes, isLoading: notesLoading } = useNotes({ limit: 10 });

  return (
    <PageLayout>
      <header style={{ marginBottom: '3rem', textAlign: 'center' }}>
        <h1 style={{ 
          fontSize: '3rem', 
          fontWeight: 800,
          background: 'linear-gradient(135deg, var(--text-primary), var(--text-secondary))',
          WebkitBackgroundClip: 'text',
          WebkitTextFillColor: 'transparent',
          marginBottom: '0.5rem',
          letterSpacing: '-1px',
        }}>
          Relix
        </h1>
        <p style={{ color: 'var(--text-secondary)', fontSize: '1.1rem' }}>
          Your second brain. Without the cloud.
        </p>
      </header>

      {/* Status Bar */}
      <div style={{ 
        display: 'flex', 
        justifyContent: 'center',
        gap: '2rem', 
        marginBottom: '3rem',
        flexWrap: 'wrap',
      }}>
        <StatusBadge
          label="ACORDE"
          status={healthLoading ? 'loading' : isHealthy ? 'connected' : 'disconnected'}
        />
        {status && (
          <>
            <StatusBadge label="Entries" value={String(status.entries_count || 0)} />
            <StatusBadge label="Peers" value={String(status.peers || 0)} />
          </>
        )}
      </div>

      {/* Navigation Grid */}
      <div style={{ 
        display: 'grid', 
        gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
        gap: '1.5rem', 
        marginBottom: '3rem' 
      }}>
        <NavCard href="/notes/new" icon="✏️" title="New Note" desc="Create instant thought" />
        <NavCard href="/notes" icon="📝" title="All Notes" desc="Browse your library" />
        <NavCard href="/graph" icon="🕸️" title="Graph View" desc="Explore connections" />
        <NavCard href="/files" icon="📁" title="Files" desc="Manage attachments" />
      </div>

      {/* Recent Notes */}
      <section>
        <h2 style={{ 
          fontSize: '1.1rem', 
          marginBottom: '1.5rem', 
          color: 'var(--text-secondary)',
          textTransform: 'uppercase',
          letterSpacing: '1px',
          fontWeight: 600,
          borderBottom: '1px solid var(--border)',
          paddingBottom: '0.5rem',
        }}>
          Recent Notes
        </h2>
        
        {notesLoading ? (
          <p style={{ color: 'var(--text-muted)' }}>Loading...</p>
        ) : !notes || notes.length === 0 ? (
          <div style={{ 
            textAlign: 'center', 
            padding: '3rem', 
            background: 'var(--bg-secondary)', 
            borderRadius: '12px',
            border: '1px dashed var(--border)',
          }}>
            <p style={{ color: 'var(--text-muted)', marginBottom: '1rem' }}>No notes yet.</p>
            <Link href="/notes/new">
              <button className="primary">Create your first note</button>
            </Link>
          </div>
        ) : (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))', gap: '1rem' }}>
            {notes.map((note) => (
              <Link 
                key={note.id} 
                href={`/notes/${note.id}`}
                style={{
                  display: 'flex',
                  flexDirection: 'column',
                  padding: '1.25rem',
                  background: 'var(--bg-secondary)',
                  borderRadius: '12px',
                  border: '1px solid var(--border)',
                  transition: 'all 0.2s ease',
                  height: '100%',
                }}
              >
                <div style={{ fontWeight: 600, fontSize: '1.1rem', marginBottom: '0.5rem', color: 'var(--text-primary)' }}>
                  {note.content.title}
                </div>
                <div style={{ 
                  color: 'var(--text-secondary)', 
                  fontSize: '0.85rem',
                  marginBottom: '1rem',
                  lineHeight: 1.5,
                  flex: 1,
                  overflow: 'hidden',
                  display: '-webkit-box',
                  WebkitLineClamp: 3,
                  WebkitBoxOrient: 'vertical',
                }}>
                  {note.content.body.slice(0, 150)}
                </div>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.5rem' }}>
                  {note.tags
                    .filter(t => !t.startsWith('backlink:') && !t.startsWith('outlink:'))
                    .slice(0, 3)
                    .map(t => (
                      <span key={t} style={{
                        background: 'var(--bg-primary)',
                        padding: '2px 8px',
                        borderRadius: '4px',
                        fontSize: '0.75rem',
                        color: 'var(--text-muted)',
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
      </section>
    </PageLayout>
  );
}

function NavCard({ href, icon, title, desc }: { href: string; icon: string; title: string; desc: string }) {
  return (
    <Link 
      href={href as any}
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '2rem',
        background: 'var(--bg-secondary)',
        borderRadius: '16px',
        border: '1px solid var(--border)',
        transition: 'transform 0.2s, border-color 0.2s',
        textAlign: 'center',
        height: '100%',
      }}
    >
      <span style={{ fontSize: '2.5rem', marginBottom: '1rem' }}>{icon}</span>
      <span style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '0.25rem', color: 'var(--text-primary)' }}>{title}</span>
      <span style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>{desc}</span>
    </Link>
  );
}

function StatusBadge({ 
  label, 
  status, 
  value 
}: { 
  label: string; 
  status?: 'connected' | 'disconnected' | 'loading';
  value?: string;
}) {
  const color = status === 'connected' ? 'var(--success)' 
    : status === 'disconnected' ? 'var(--error)'
    : 'var(--text-muted)';

  return (
    <div style={{ 
      display: 'flex', 
      alignItems: 'center', 
      gap: '0.75rem',
      background: 'var(--bg-secondary)',
      padding: '0.5rem 1rem',
      borderRadius: '20px',
      border: '1px solid var(--border)',
    }}>
      {status && (
        <div style={{
          width: 8,
          height: 8,
          borderRadius: '50%',
          background: color,
          boxShadow: `0 0 8px ${color}`,
        }} />
      )}
      <span style={{ color: 'var(--text-secondary)', fontSize: '0.85rem', fontWeight: 500 }}>
        {label}
      </span>
      {value && (
        <span style={{ fontWeight: 600, fontSize: '0.9rem', color: 'var(--text-primary)' }}>{value}</span>
      )}
    </div>
  );
}
