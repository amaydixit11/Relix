'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useNotes, useHealthCheck, useVaultStatus } from '@relix/core';
import { PageLayout } from '@/components';

export default function HomePage() {
  const { data: isHealthy, isLoading: healthLoading } = useHealthCheck();
  const { data: status } = useVaultStatus();
  const { data: notes, isLoading: notesLoading } = useNotes({ limit: 6 });

  const getGreeting = () => {
    const hour = new Date().getHours();
    if (hour < 12) return 'Good morning.';
    if (hour < 17) return 'Good afternoon.';
    return 'Good evening.';
  };

  return (
    <PageLayout>
      {/* Dynamic Hero Section */}
      <header style={{ 
        marginBottom: '4rem', 
        textAlign: 'center',
        padding: '3rem 0',
        position: 'relative',
      }}>
        <div style={{
          position: 'absolute',
          top: '50%',
          left: '50%',
          transform: 'translate(-50%, -50%)',
          width: '300px',
          height: '100px',
          background: 'linear-gradient(90deg, var(--accent-cyan), var(--accent-rose))',
          filter: 'blur(80px)',
          opacity: 0.2,
          zIndex: -1,
        }} />
        
        <h1 style={{ 
          fontSize: '4rem', 
          fontWeight: 800,
          background: 'linear-gradient(135deg, white 0%, var(--text-secondary) 100%)',
          WebkitBackgroundClip: 'text',
          WebkitTextFillColor: 'transparent',
          marginBottom: '1rem',
          letterSpacing: '-2px',
          lineHeight: 1.1,
        }}>
          {getGreeting()}
        </h1>
        <p style={{ 
          color: 'var(--text-secondary)', 
          fontSize: '1.25rem',
          maxWidth: '600px',
          margin: '0 auto',
          lineHeight: 1.6,
        }}>
          Your digital garden is growing. <span style={{ color: 'var(--accent-cyan)' }}>{status?.entries_count || 0} notes</span> securely synced.
        </p>
      </header>

      {/* Status Bar - Floating Glass */}
      <div style={{ 
        display: 'flex', 
        justifyContent: 'center',
        gap: '1.5rem', 
        marginBottom: '4rem',
        flexWrap: 'wrap',
      }}>
        <StatusPill 
          label="System" 
          value={healthLoading ? 'Checking...' : isHealthy ? 'Online' : 'Offline'}
          dotColor={isHealthy ? 'var(--success)' : 'var(--error)'}
        />
        {status && (
          <>
            <StatusPill label="Peers" value={`${status.peers} connected`} dotColor="var(--accent)" />
            <StatusPill label="Sync" value="Up to date" dotColor="var(--accent-cyan)" />
          </>
        )}
      </div>

      {/* Quick Actions Grid - Staggered Fade In */}
      <div style={{ 
        display: 'grid', 
        gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
        gap: '1.5rem', 
        marginBottom: '4rem' 
      }}>
        <NavCard delay={0} href="/notes/new" icon="✨" title="New Thought" desc="Capture an idea instantly" accent="var(--accent)" />
        <NavCard delay={100} href="/notes" icon="📚" title="Library" desc="Browse your second brain" accent="var(--accent-cyan)" />
        <NavCard delay={200} href="/graph" icon="🕸️" title="Graph" desc="Visualize connections" accent="var(--accent-rose)" />
        <NavCard delay={300} href="/files" icon="📂" title="Assets" desc="Manage files & media" accent="var(--warning)" />
      </div>

      {/* Jump Back In */}
      <section>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'end', marginBottom: '1.5rem' }}>
          <h2 style={{ 
            fontSize: '1.5rem', 
            fontWeight: 700,
            letterSpacing: '-0.5px',
          }}>
            Jump back in
          </h2>
          <Link href="/notes" style={{ fontSize: '0.9rem', color: 'var(--accent)' }}>View all →</Link>
        </div>
        
        {notesLoading ? (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '1rem' }}>
            {[1,2,3].map(i => (
              <div key={i} className="glass-card" style={{ height: '140px', borderRadius: '16px' }} />
            ))}
          </div>
        ) : !notes || notes.length === 0 ? (
          <div className="glass-panel" style={{ 
            textAlign: 'center', 
            padding: '4rem', 
            borderRadius: '24px',
            borderStyle: 'dashed',
          }}>
            <p style={{ color: 'var(--text-muted)', marginBottom: '1.5rem' }}>The canvas is empty.</p>
            <Link href="/notes/new">
              <button className="primary">Write something</button>
            </Link>
          </div>
        ) : (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))', gap: '1.25rem' }}>
            {notes.map((note, i) => (
              <NoteCard key={note.id} note={note} delay={i * 50} />
            ))}
          </div>
        )}
      </section>
    </PageLayout>
  );
}

function NavCard({ href, icon, title, desc, delay, accent }: any) {
  return (
    <Link 
      href={href}
      className="glass-card animate-in"
      style={{
        display: 'flex',
        flexDirection: 'column',
        padding: '1.75rem',
        borderRadius: '20px',
        textDecoration: 'none',
        height: '100%',
        animationDelay: `${delay}ms`,
        position: 'relative',
        overflow: 'hidden',
      }}
    >
      <div style={{ 
        position: 'absolute', 
        top: 0, 
        right: 0, 
        width: '100px', 
        height: '100px', 
        background: accent, 
        filter: 'blur(60px)', 
        opacity: 0.15,
        borderRadius: '50%',
        transform: 'translate(30%, -30%)'
      }} />
      
      <span style={{ fontSize: '2rem', marginBottom: '1rem' }}>{icon}</span>
      <span style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '0.5rem', color: 'var(--text-primary)' }}>{title}</span>
      <span style={{ fontSize: '0.9rem', color: 'var(--text-muted)', lineHeight: 1.4 }}>{desc}</span>
    </Link>
  );
}

function NoteCard({ note, delay }: any) {
  if (!note?.content) return null;

  return (
    <Link 
      href={`/notes/${note.id}`}
      className="glass-card animate-in"
      style={{
        display: 'flex',
        flexDirection: 'column',
        padding: '1.5rem',
        borderRadius: '16px',
        animationDelay: `${delay}ms`,
        height: '100%',
        position: 'relative',
        overflow: 'hidden',
        border: '1px solid rgba(255,255,255,0.05)',
      }}
    >
      <div style={{
        position: 'absolute',
        top: 0,
        left: 0,
        width: '100%',
        height: '100%',
        background: 'radial-gradient(circle at top right, rgba(139, 92, 246, 0.1), transparent 50%)',
        pointerEvents: 'none',
      }} />

      <h3 style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '0.5rem', color: 'var(--text-primary)', position: 'relative' }}>
        {note.content.title || 'Untitled'}
      </h3>
      <p style={{ 
        color: 'var(--text-secondary)', 
        fontSize: '0.9rem',
        marginBottom: '1rem',
        lineHeight: 1.6,
        flex: 1,
        overflow: 'hidden',
        display: '-webkit-box',
        WebkitLineClamp: 3,
        WebkitBoxOrient: 'vertical',
        position: 'relative'
      }}>
        {note.content.body ? note.content.body.slice(0, 150) : ''}
      </p>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.5rem', position: 'relative' }}>
        {note.tags && note.tags
          .filter((t: string) => !t.startsWith('backlink:') && !t.startsWith('outlink:'))
          .slice(0, 3)
          .map((t: string) => (
            <span key={t} style={{
              background: 'rgba(255,255,255,0.05)',
              padding: '4px 10px',
              borderRadius: '20px',
              fontSize: '0.75rem',
              color: 'var(--text-secondary)',
              border: '1px solid rgba(255,255,255,0.1)',
            }}>
              #{t}
            </span>
          ))}
      </div>
    </Link>
  );
}

function StatusPill({ label, value, dotColor }: any) {
  return (
    <div className="glass-panel" style={{ 
      display: 'flex', 
      alignItems: 'center', 
      gap: '0.75rem',
      padding: '0.6rem 1.25rem',
      borderRadius: '50px',
      fontSize: '0.9rem',
    }}>
      <div style={{
        width: 8,
        height: 8,
        borderRadius: '50%',
        background: dotColor,
        boxShadow: `0 0 10px ${dotColor}`,
      }} />
      <span style={{ color: 'var(--text-muted)' }}>{label}</span>
      <span style={{ fontWeight: 600, color: 'var(--text-primary)' }}>{value}</span>
    </div>
  );
}
