'use client';

import { useState, useCallback, useEffect } from 'react';
import { acorde, fileService, type File as RelixFile } from '@relix/core';
import { PageLayout } from '@/components';

export default function FilesPage() {
  const [files, setFiles] = useState<RelixFile[]>([]);
  const [loading, setLoading] = useState(true);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    void loadFiles();
  }, []);

  const loadFiles = async () => {
    try {
      setLoading(true);
      setError(null);
      const nextFiles = await fileService.list();
      setFiles(nextFiles.sort((a, b) => b.updated_at - a.updated_at));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load files');
    } finally {
      setLoading(false);
    }
  };

  const handleDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    const droppedFiles = Array.from(e.dataTransfer.files);
    handleFiles(droppedFiles);
  }, []);

  const handleFileSelect = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files) {
      const selectedFiles = Array.from(e.target.files);
      handleFiles(selectedFiles);
    }
  }, []);

  const handleFiles = async (newFiles: File[]) => {
    setUploading(true);
    setError(null);
    try {
      const uploaded = await Promise.all(
        newFiles.map((file) => fileService.upload(file, file.name, ['file']))
      );
      setFiles((prev) =>
        [...uploaded, ...prev].sort((a, b) => b.updated_at - a.updated_at)
      );
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Upload failed');
    } finally {
      setUploading(false);
    }
  };

  return (
    <PageLayout>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2rem' }}>
        <h1 style={{ fontSize: '1.75rem', fontWeight: 700 }}>Files</h1>
        <button onClick={() => void loadFiles()} disabled={loading || uploading}>
          {loading ? 'Refreshing...' : 'Refresh'}
        </button>
      </div>

      {error && (
        <div
          style={{
            marginBottom: '1rem',
            padding: '0.9rem 1rem',
            borderRadius: '10px',
            background: 'rgba(127, 29, 29, 0.35)',
            border: '1px solid rgba(248, 113, 113, 0.35)',
            color: '#fecaca',
          }}
        >
          {error}
        </div>
      )}

      {/* Upload Area */}
      <div
        onDrop={handleDrop}
        onDragOver={(e) => e.preventDefault()}
        style={{
          padding: '4rem',
          border: '2px dashed var(--border)',
          borderRadius: '12px',
          textAlign: 'center',
          marginBottom: '2rem',
          cursor: 'pointer',
          background: 'var(--bg-secondary)',
          transition: 'all 0.2s',
          color: 'var(--text-secondary)',
        }}
        onClick={() => document.getElementById('file-input')?.click()}
      >
        <input
          id="file-input"
          type="file"
          multiple
          accept=".pdf,.png,.jpg,.jpeg,.gif,.webp,.md,.txt"
          onChange={handleFileSelect}
          style={{ display: 'none' }}
        />
        <div style={{ fontSize: '3rem', marginBottom: '1rem', opacity: 0.5 }}>📁</div>
        <p style={{ fontSize: '1.1rem', marginBottom: '0.5rem', fontWeight: 500 }}>
          {uploading ? 'Uploading...' : 'Drop files here'}
        </p>
        <p style={{ fontSize: '0.9rem', opacity: 0.7 }}>
          or click to select
        </p>
      </div>

      {/* File List */}
      {loading ? (
        <div style={{ color: 'var(--text-secondary)' }}>Loading files…</div>
      ) : files.length > 0 ? (
        <div style={{ display: 'grid', gap: '0.75rem' }}>
          {files.map((file, i) => (
            <div
              key={file.id}
              style={{
                display: 'flex',
                alignItems: 'center',
                padding: '1rem',
                background: 'var(--bg-secondary)',
                borderRadius: '8px',
                border: '1px solid var(--border)',
                gap: '1rem',
              }}
            >
              <span style={{ fontSize: '1.5rem', opacity: 0.8 }}>
                {file.content.mime_type.includes('pdf') ? '📄' : file.content.mime_type.includes('image') ? '🖼️' : '📝'}
              </span>
              <div style={{ flex: 1 }}>
                <div style={{ fontWeight: 500, color: 'var(--text-primary)' }}>{file.content.name}</div>
                <div style={{ color: 'var(--text-muted)', fontSize: '0.8rem' }}>
                  {(file.content.size / 1024).toFixed(1)} KB • {file.content.mime_type}
                </div>
              </div>
              <button
                onClick={() =>
                  window.open(
                    `${acorde.getBaseUrl()}/blobs/${file.content.cid}`,
                    '_blank',
                    'noopener,noreferrer'
                  )
                }
                style={{ 
                background: 'var(--bg-tertiary)', 
                border: '1px solid var(--border)',
                padding: '0.25rem 0.75rem',
                fontSize: '0.8rem',
              }}>
                View
              </button>
            </div>
          ))}
        </div>
      ) : (
        <div style={{ color: 'var(--text-secondary)' }}>No files uploaded yet.</div>
      )}
    </PageLayout>
  );
}
