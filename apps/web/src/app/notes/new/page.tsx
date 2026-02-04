'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { useCreateNote, defaultTemplates, processTemplate } from '@relix/core';
import { MarkdownEditor } from '@/components/Editor';
import { PageLayout } from '@/components';

export default function NewNotePage() {
  const router = useRouter();
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [tags, setTags] = useState('');
  
  // Template modal state
  const [showTemplates, setShowTemplates] = useState(true);

  const createNote = useCreateNote({
    onSuccess: (note) => {
      router.push(`/notes/${note.id}`);
    },
  });

  const handleTemplateSelect = (templateId: string) => {
    const template = defaultTemplates.find(t => t.id === templateId);
    if (!template) return;

    if (templateId === 'blank') {
      setShowTemplates(false);
      return;
    }

    const { content, tags: templateTags } = processTemplate(template, title || 'Untitled');
    setBody(content);
    setTags(templateTags.join(', '));
    if (!title && templateId === 'daily') setTitle(new Date().toISOString().split('T')[0]);
    setShowTemplates(false);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim()) return;

    const tagList = tags.split(',').map(t => t.trim()).filter(Boolean);
    createNote.mutate({ title, body, tags: tagList });
  };

  return (
    <PageLayout noPadding>
      <div style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
        
        {/* Template Overlay */}
        {showTemplates ? (
          <div style={{ 
            height: '100%', 
            display: 'flex', 
            flexDirection: 'column', 
            alignItems: 'center', 
            justifyContent: 'center',
            padding: '2rem'
          }}>
            <h2 style={{ fontSize: '2rem', marginBottom: '2rem', fontWeight: 300 }}>Start with...</h2>
            <div style={{ 
              display: 'grid', 
              gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))', 
              gap: '1.5rem', 
              maxWidth: '800px', 
              width: '100%' 
            }}>
              {defaultTemplates.map(t => (
                <button
                  key={t.id}
                  onClick={() => handleTemplateSelect(t.id)}
                  style={{
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: 'center',
                    padding: '2rem 1rem',
                    background: 'var(--bg-secondary)',
                    border: '1px solid var(--border)',
                    borderRadius: '12px',
                    gap: '1rem',
                    height: '100%',
                    transition: 'all 0.2s',
                  }}
                >
                  <span style={{ fontSize: '2.5rem' }}>{t.icon}</span>
                  <span style={{ fontSize: '1rem', color: 'var(--text-primary)' }}>{t.name}</span>
                </button>
              ))}
            </div>
          </div>
        ) : (
          <form onSubmit={handleSubmit} style={{ 
            flex: 1, 
            display: 'flex', 
            flexDirection: 'column', 
            maxWidth: '900px', 
            margin: '0 auto', 
            width: '100%',
            padding: '2rem',
          }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '1.5rem' }}>
              <Link href="/notes" style={{ color: 'var(--text-muted)' }}>← Cancel</Link>
              <button type="submit" className="primary" disabled={createNote.isPending || !title.trim()}>
                {createNote.isPending ? 'Creating...' : 'Create Note'}
              </button>
            </div>

            <input
              autoFocus
              value={title}
              onChange={e => setTitle(e.target.value)}
              placeholder="Untitled"
              style={{
                fontSize: '2.5rem',
                fontWeight: 800,
                background: 'transparent',
                border: 'none',
                padding: '0.5rem 0',
                marginBottom: '1rem',
                borderRadius: 0,
              }}
            />

            <div style={{ flex: 1, marginBottom: '1rem', border: '1px solid var(--border)', borderRadius: '8px', overflow: 'hidden' }}>
              <MarkdownEditor value={body} onChange={setBody} placeholder="Start writing..." />
            </div>

            <input
              value={tags}
              onChange={e => setTags(e.target.value)}
              placeholder="Tags (comma separated)..."
              style={{
                background: 'transparent',
                border: 'none',
                borderTop: '1px solid var(--border)',
                borderRadius: 0,
                padding: '1rem 0',
                color: 'var(--text-muted)',
              }}
            />
          </form>
        )}
      </div>
    </PageLayout>
  );
}
