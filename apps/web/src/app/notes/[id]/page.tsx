'use client';

import { useState, useEffect } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Link from 'next/link';
import { useNote, useBacklinks, useUpdateNote, useDeleteNote, renderWikilinks, exportService } from '@relix/core';
import { MarkdownEditor } from '@/components/Editor';
import { PageLayout } from '@/components';

export default function NoteDetailPage() {
  const params = useParams();
  const router = useRouter();
  const id = params.id as string;

  const { data: note, isLoading } = useNote(id);
  const { data: backlinks } = useBacklinks(id);
  const updateNote = useUpdateNote();
  const deleteNote = useDeleteNote({
    onSuccess: () => router.push('/notes'),
  });

  const [isEditing, setIsEditing] = useState(false);
  const [content, setContent] = useState('');
  const [title, setTitle] = useState('');

  useEffect(() => {
    if (note) {
      setContent(note.content.body);
      setTitle(note.content.title);
    }
  }, [note]);

  const handleSave = async () => {
    await updateNote.mutateAsync({
      id,
      patch: { body: content, title },
    });
    setIsEditing(false);
  };

  const handleDelete = async () => {
    if (confirm('Are you sure you want to delete this note?')) {
      deleteNote.mutate(id);
    }
  };

  if (isLoading) return <PageLayout><div>Loading...</div></PageLayout>;
  if (!note) return <PageLayout><div>Note not found</div></PageLayout>;

  return (
    <PageLayout noPadding>
      <div style={{ display: 'flex', height: '100%' }}>
        
        {/* Main Note Area */}
        <div style={{ 
          flex: 1, 
          overflowY: 'auto', 
          padding: '3rem 4rem', 
          maxWidth: '850px',
          margin: '0 auto',
        }}>
          {isEditing ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem', height: '100%' }}>
              <input
                value={title}
                onChange={e => setTitle(e.target.value)}
                style={{ 
                  fontSize: '2rem', 
                  fontWeight: 700, 
                  background: 'transparent',
                  border: 'none',
                  borderBottom: '1px solid var(--border)',
                  borderRadius: 0,
                  padding: '0.5rem 0',
                }}
                placeholder="Note Title"
              />
              <div style={{ flex: 1, minHeight: '500px' }}>
                <MarkdownEditor value={content} onChange={setContent} />
              </div>
              <div style={{ display: 'flex', gap: '1rem', paddingTop: '1rem', borderTop: '1px solid var(--border)' }}>
                <button className="primary" onClick={handleSave} disabled={updateNote.isPending}>
                  {updateNote.isPending ? 'Saving...' : 'Save Changes'}
                </button>
                <button onClick={() => setIsEditing(false)}>Cancel</button>
              </div>
            </div>
          ) : (
            <div>
              {/* Header */}
              <div style={{ 
                marginBottom: '2rem', 
                borderBottom: '1px solid var(--border)', 
                paddingBottom: '1rem',
                display: 'flex', 
                justifyContent: 'space-between', 
                alignItems: 'baseline' 
              }}>
                <h1 style={{ fontSize: '2.5rem', fontWeight: 800, lineHeight: 1.2 }}>{note.content.title}</h1>
                <div style={{ display: 'flex', gap: '0.75rem' }}>
                  <button onClick={() => setIsEditing(true)}>Edit</button>
                  <button onClick={() => exportService.downloadNote(note)}>Export</button>
                  <button onClick={handleDelete} style={{ color: 'var(--error)', borderColor: 'var(--error)' }}>
                    Delete
                  </button>
                </div>
              </div>

              {/* Backlinks Panel (Mobile/Narrow) */}
              {backlinks && backlinks.length > 0 && (
                <div style={{ 
                  marginBottom: '2rem',
                  padding: '1rem',
                  background: 'var(--bg-secondary)',
                  borderRadius: '8px',
                  border: '1px dashed var(--border)',
                  fontSize: '0.9rem',
                }}>
                  <strong style={{ display: 'block', marginBottom: '0.5rem', color: 'var(--text-secondary)' }}>Linked References</strong>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
                    {backlinks.map(link => (
                      <Link key={link.id} href={`/notes/${link.id}`} style={{ color: 'var(--accent)' }}>
                        [[{link.content.title}]]
                      </Link>
                    ))}
                  </div>
                </div>
              )}

              {/* Content */}
              <div style={{ minHeight: '500px', fontSize: '1.1rem' }}>
                <MarkdownEditor 
                  value={note.content.body} 
                  readonly={true}
                  className="read-only-editor"
                />
              </div>
              
              <div style={{ 
                marginTop: '4rem', 
                paddingTop: '1rem', 
                borderTop: '1px solid var(--border)',
                color: 'var(--text-muted)',
                fontSize: '0.85rem',
                display: 'flex',
                gap: '1rem',
              }}>
                <span>Created: {new Date(note.content.created_at).toLocaleDateString()}</span>
                <span>Last updated: {new Date(note.content.updated_at).toLocaleDateString()}</span>
              </div>
            </div>
          )}
        </div>

        {/* Right Sidebar (Backlinks/Graph) - Desktop Only ideally */}
        {/* Keeping simple for now, can add collapsible right sidebar later */}
        
      </div>
    </PageLayout>
  );
}
