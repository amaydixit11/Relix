'use client';

import { useState, useEffect, useMemo } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Link from 'next/link';
import { 
  useNote, 
  useBacklinks, 
  useUpdateNote, 
  useDeleteNote, 
  useConflictDetection, 
  noteService,
  exportService 
} from '@relix/core';
import { MarkdownEditor } from '@/components/Editor';
import { PageLayout } from '@/components';
import Sidebar from '@/components/Sidebar/Sidebar';

export default function NoteDetailPage() {
  const params = useParams();
  const router = useRouter();
  const id = params.id as string;

  const { data: note, isLoading } = useNote(id);
  const { data: backlinks } = useBacklinks(id);
  const { hasConflict, resetConflict } = useConflictDetection(id);
  
  const updateNote = useUpdateNote();
  const deleteNote = useDeleteNote({
    onSuccess: () => router.push('/notes'),
  });

  const [body, setBody] = useState('');
  const [title, setTitle] = useState('');
  const [lastSaved, setLastSaved] = useState<Date | null>(null);
  const [isSaving, setIsSaving] = useState(false);

  useEffect(() => {
    if (note) {
      setBody(note.content.body || '');
      setTitle(note.content.title || '');
      setLastSaved(new Date(note.updated_at));
    }
  }, [note]);

  // Debounced auto-save
  useEffect(() => {
    if (!note || (body === note.content.body && title === note.content.title)) return;

    setIsSaving(true);
    const timeout = setTimeout(async () => {
      try {
        await updateNote.mutateAsync({
          id,
          patch: { body, title },
        });
        setLastSaved(new Date());
      } finally {
        setIsSaving(false);
      }
    }, 2000);

    return () => clearTimeout(timeout);
  }, [body, title]);

  const handleWikilinkClick = async (idOrTitle: string) => {
    // 1. Try resolving title to ID
    const searchResult = await noteService.search(idOrTitle, 5);
    const matched = searchResult.find(n => 
        n.content.title.toLowerCase() === idOrTitle.toLowerCase());
    
    if (matched) {
      router.push(`/notes/${matched.id}`);
    } else {
      // 2. Try as direct ID
      try {
        await noteService.get(idOrTitle);
        router.push(`/notes/${idOrTitle}`);
      } catch {
        alert(`Note "${idOrTitle}" doesn't exist yet.`);
      }
    }
  };

  if (!note && !isLoading) return <PageLayout><div>Note not found.</div></PageLayout>;
  if (isLoading) return <PageLayout><div>Loading...</div></PageLayout>;

  return (
    <PageLayout noPadding>
      <div style={{ display: 'flex', height: '100%', overflow: 'hidden' }}>
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', height: '100%', position: 'relative' }}>
          
          {/* Breadcrumb Header */}
          <header style={{ 
            height: '48px', 
            borderBottom: '1px solid var(--border)', 
            display: 'flex', 
            alignItems: 'center', 
            padding: '0 24px',
            fontSize: '0.85rem',
            color: 'var(--text-secondary)',
            gap: '8px',
            zIndex: 10
          }}>
            <Link href="/notes" style={{ color: 'inherit', textDecoration: 'none' }}>Notes</Link>
            <span>/</span>
            <span style={{ color: 'var(--text-primary)', fontWeight: 500 }}>{title || 'Untitled'}</span>
            <div style={{ flex: 1 }} />
            {isSaving ? (
              <span style={{ fontSize: '0.75rem', opacity: 0.6 }}>Saving...</span>
            ) : lastSaved && (
              <span style={{ fontSize: '0.75rem', opacity: 0.4 }}>Saved {lastSaved.toLocaleTimeString()}</span>
            )}
            {note && (
              <button 
                onClick={() => exportService.downloadNote(note)}
                style={{ background: 'transparent', border: 'none', color: 'var(--accent)', cursor: 'pointer', marginLeft: '12px' }}
              >
                Export
              </button>
            )}
          </header>

          <main style={{ flex: 1, padding: '2rem 4rem', overflowY: 'auto' }}>
            <input 
              value={title}
              onChange={e => setTitle(e.target.value)}
              placeholder="Note Title"
              style={{
                fontSize: '2.5rem',
                fontWeight: 800,
                background: 'transparent',
                border: 'none',
                color: 'var(--text-primary)',
                outline: 'none',
                width: '100%',
                marginBottom: '1rem'
              }}
            />
            <MarkdownEditor 
              value={body}
              onChange={setBody}
              onWikilinkClick={handleWikilinkClick}
              className="zen-editor"
            />
          </main>

          {/* Conflict Detector Banner */}
          {hasConflict && (
            <div style={{ 
              position: 'absolute', 
              bottom: '24px', 
              right: '24px', 
              left: '24px',
              background: 'rgba(255, 107, 107, 0.95)',
              color: 'white',
              backdropFilter: 'blur(10px)',
              padding: '1.25rem',
              borderRadius: '16px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              boxShadow: '0 20px 40px rgba(0,0,0,0.4)',
              zIndex: 100,
              border: '1px solid rgba(255,255,255,0.1)'
            }}>
              <div>
                <strong style={{ fontSize: '1.05rem', display: 'block' }}>Changes detected on another device!</strong>
                <span style={{ fontSize: '0.85rem', opacity: 0.9 }}>
                  This note was updated remotely. Resolve the conflict to keep your changes.
                </span>
              </div>
              <div style={{ display: 'flex', gap: '8px' }}>
                <button 
                  onClick={async () => {
                    const latest = await noteService.get(id);
                    setBody(latest.content.body);
                    setTitle(latest.content.title);
                    resetConflict();
                  }}
                  style={{ 
                    background: 'white', 
                    color: '#ff6b6b', 
                    fontWeight: 600,
                    padding: '10px 20px',
                    borderRadius: '10px'
                  }}
                >
                  Merge Changes
                </button>
              </div>
            </div>
          )}
        </div>

        {/* Dynamic Backlink Sidebar */}
        <div style={{ width: '300px', borderLeft: '1px solid var(--border)', background: 'var(--bg-secondary)', overflowY: 'auto', padding: '1.5rem' }}>
          <h2 style={{ fontSize: '0.85rem', textTransform: 'uppercase', color: 'var(--text-muted)', marginBottom: '1.5rem', letterSpacing: '0.05em' }}>
            Connections
          </h2>
          
          <div style={{ display: 'flex', flexDirection: 'column', gap: '2rem' }}>
            <section>
              <h3 style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginBottom: '1rem' }}>Backlinks</h3>
              {backlinks && backlinks.length > 0 ? (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
                  {backlinks.map(link => (
                    <Link 
                      key={link.id} 
                      href={`/notes/${link.id}`}
                      style={{ 
                        fontSize: '0.9rem', 
                        color: 'var(--text-primary)',
                        textDecoration: 'none',
                        padding: '10px',
                        background: 'rgba(255,255,255,0.03)',
                        borderRadius: '8px'
                      }}
                    >
                      [[{link.content.title || 'Untitled'}]]
                    </Link>
                  ))}
                </div>
              ) : (
                <span style={{ fontSize: '0.85rem', color: 'var(--text-muted)', fontStyle: 'italic' }}>None yet</span>
              )}
            </section>
            
            <section>
              <h3 style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginBottom: '1rem' }}>Outgoing</h3>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.5rem' }}>
                {note?.tags
                  .filter(t => t.startsWith('outlink:'))
                  .map(t => {
                    const targetId = t.split(':')[1];
                    return (
                      <Link 
                        key={t}
                        href={`/notes/${targetId}`}
                        style={{ 
                          fontSize: '0.7rem', 
                          padding: '4px 8px', 
                          background: 'rgba(99, 102, 241, 0.1)', 
                          color: 'var(--accent)',
                          borderRadius: '4px',
                          textDecoration: 'none'
                        }}
                      >
                        [[{targetId.slice(0, 8)}]]
                      </Link>
                    );
                  })}
              </div>
            </section>
          </div>
        </div>
      </div>
    </PageLayout>
  );
}
