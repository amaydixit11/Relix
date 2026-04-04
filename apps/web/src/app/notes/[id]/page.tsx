'use client';

import { useState, useEffect } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Link from 'next/link';
import { useNote, useBacklinks, useUpdateNote, useDeleteNote, useConflictDetection, exportService } from '@relix/core';
import { MarkdownEditor } from '@/components/Editor';
import { PageLayout } from '@/components';

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

  const [isEditing, setIsEditing] = useState(false);
  const [content, setContent] = useState('');
  const [title, setTitle] = useState('');
  const [lastSaved, setLastSaved] = useState<Date | null>(null);

  useEffect(() => {
    if (note) {
      setContent(note.content.body || '');
      setTitle(note.content.title || '');
      setLastSaved(new Date(note.updated_at));
    }
  }, [note]);

  // Debounced auto-save
  useEffect(() => {
    if (!note || (content === note.content.body && title === note.content.title)) return;

    const timeout = setTimeout(async () => {
      await updateNote.mutateAsync({
        id,
        patch: { body: content, title },
      });
      setLastSaved(new Date());
    }, 2000);

    return () => clearTimeout(timeout);
  }, [content, title]);

  const handleDelete = async () => {
    if (confirm('Are you sure you want to delete this note?')) {
      deleteNote.mutate(id);
    }
  };

  const navigateToWikilink = (targetId: string) => {
    router.push(`/notes/${targetId}`);
  };

  if (isLoading) return <PageLayout><div>Loading...</div></PageLayout>;
  if (!note) return <PageLayout><div>Note not found</div></PageLayout>;

  return (
    <PageLayout noPadding>
      <div style={{ 
        display: 'flex', 
        height: '100%',
        background: 'var(--bg-primary)',
      }}>
        
        <div style={{ 
          flex: 1, 
          overflowY: 'auto', 
          padding: '2rem 4rem', 
          maxWidth: '900px',
          margin: '0 auto',
          position: 'relative'
        }}>
          {/* Header Area */}
          <div style={{ 
            display: 'flex', 
            justifyContent: 'space-between', 
            alignItems: 'center',
            marginBottom: '3rem',
            paddingBottom: '1rem',
            borderBottom: '1px solid rgba(255,255,255,0.05)'
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
              <Link href="/notes" style={{ color: 'var(--text-muted)', fontSize: '0.9rem' }}>← Notes</Link>
              <div style={{ 
                fontSize: '0.75rem', 
                color: 'var(--text-muted)',
                background: 'rgba(255,255,255,0.05)',
                padding: '2px 8px',
                borderRadius: '4px'
              }}>
                {updateNote.isPending ? 'Saving...' : lastSaved ? `Saved ${lastSaved.toLocaleTimeString()}` : 'Connected'}
              </div>
            </div>
            
            <div style={{ display: 'flex', gap: '1rem' }}>
              <button 
                onClick={() => exportService.downloadNote(note)}
                style={{ background: 'transparent', border: 'none', color: 'var(--text-muted)', fontSize: '0.9rem', cursor: 'pointer' }}
              >
                Export
              </button>
              <button 
                onClick={handleDelete}
                style={{ background: 'transparent', border: 'none', color: 'var(--error)', fontSize: '0.9rem', cursor: 'pointer' }}
              >
                Delete
              </button>
            </div>
          </div>

          {/* Conflict Banner */}
          {hasConflict && (
            <div style={{ 
              background: 'var(--accent)',
              color: 'white',
              padding: '1rem',
              borderRadius: '8px',
              marginBottom: '2rem',
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              animation: 'slideDown 0.3s ease-out'
            }}>
              <div>
                <strong style={{ display: 'block' }}>Remote update detected!</strong>
                <span style={{ fontSize: '0.85rem' }}>This note was updated on another device.</span>
              </div>
              <button 
                onClick={() => {
                  setContent(note.content.body || '');
                  setTitle(note.content.title || '');
                  resetConflict();
                }}
                style={{ 
                  background: 'white', 
                  color: 'var(--accent)', 
                  border: 'none', 
                  fontWeight: 600,
                  padding: '6px 12px',
                  borderRadius: '4px'
                }}
              >
                Merge Changes
              </button>
            </div>
          )}

          {/* Editor Body */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
            <input
              value={title}
              onChange={e => setTitle(e.target.value)}
              style={{ 
                fontSize: '2.5rem', 
                fontWeight: 800, 
                background: 'transparent',
                border: 'none',
                color: 'var(--text-primary)',
                outline: 'none',
                width: '100%',
              }}
              placeholder="Untitled Note"
            />

            <div style={{ minHeight: 'calc(100vh - 300px)', marginTop: '1rem' }}>
              <MarkdownEditor 
                value={content} 
                onChange={setContent} 
                onWikilinkClick={navigateToWikilink}
                className="zen-editor"
              />
            </div>
          </div>

          {/* Footer Metadata */}
          <div style={{ 
            marginTop: '4rem', 
            paddingTop: '2rem', 
            borderTop: '1px solid rgba(255,255,255,0.05)',
            color: 'var(--text-muted)',
            fontSize: '0.8rem',
            display: 'flex',
            justifyContent: 'space-between'
          }}>
            <div style={{ display: 'flex', gap: '2rem' }}>
              <div>ID: <span style={{ fontFamily: 'monospace' }}>{id.slice(0, 8)}...</span></div>
              <div>Owner: {note.owner?.slice(0, 8) || 'local'}</div>
            </div>
            
            <div style={{ display: 'flex', gap: '1rem' }}>
              {note.tags.filter(t => !t.startsWith('backlink:') && !t.startsWith('outlink:')).map(tag => (
                <span key={tag} style={{ color: 'var(--accent)' }}>#{tag}</span>
              ))}
            </div>
          </div>
        </div>

        {/* Right Sidebar: Context & Connections */}
        <aside style={{ 
          width: '300px', 
          borderLeft: '1px solid var(--border)',
          background: 'var(--bg-secondary)',
          display: 'flex',
          flexDirection: 'column',
          padding: '2rem 1.5rem',
          overflowY: 'auto'
        }}>
          <h2 style={{ fontSize: '1rem', fontWeight: 600, marginBottom: '1.5rem', color: 'var(--text-primary)' }}>References</h2>
          
          <div style={{ display: 'flex', flexDirection: 'column', gap: '2rem' }}>
            {/* Backlinks */}
            <section>
              <h3 style={{ fontSize: '0.75rem', textTransform: 'uppercase', color: 'var(--text-muted)', marginBottom: '1rem', letterSpacing: '0.05em' }}>
                Backlinks
              </h3>
              {backlinks && backlinks.length > 0 ? (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
                  {backlinks.map(link => (
                    <Link 
                      key={link.id} 
                      href={`/notes/${link.id}`}
                      style={{ 
                        fontSize: '0.9rem', 
                        color: 'var(--text-secondary)',
                        textDecoration: 'none',
                        padding: '8px 12px',
                        background: 'rgba(255,255,255,0.02)',
                        borderRadius: '6px',
                        border: '1px solid transparent',
                        transition: 'all 0.2s'
                      }}
                      onMouseEnter={e => e.currentTarget.style.borderColor = 'var(--accent)'}
                      onMouseLeave={e => e.currentTarget.style.borderColor = 'transparent'}
                    >
                      [[{link.content.title || 'Untitled'}]]
                    </Link>
                  ))}
                </div>
              ) : (
                <div style={{ fontSize: '0.85rem', color: 'var(--text-muted)', fontStyle: 'italic' }}>
                  No backlinks found.
                </div>
              )}
            </section>

            {/* Tags */}
            <section>
              <h3 style={{ fontSize: '0.75rem', textTransform: 'uppercase', color: 'var(--text-muted)', marginBottom: '1rem', letterSpacing: '0.05em' }}>
                Outgoing Links
              </h3>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.5rem' }}>
                {note.tags
                  .filter(t => t.startsWith('outlink:'))
                  .map(t => (
                    <Link 
                      key={t}
                      href={`/notes/${t.split(':')[1]}`}
                      style={{ 
                        fontSize: '0.75rem', 
                        padding: '4px 8px', 
                        background: 'rgba(99, 102, 241, 0.1)', 
                        color: 'var(--accent)',
                        borderRadius: '4px',
                        textDecoration: 'none'
                      }}
                    >
                      [[{t.split(':')[1].slice(0, 8)}]]
                    </Link>
                  ))}
              </div>
            </section>
          </div>
        </aside>
      </div>
    </PageLayout>
  );
}
