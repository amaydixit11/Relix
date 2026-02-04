'use client';

import { useState, useCallback } from 'react';
import Link from 'next/link';
import { PageLayout } from '@/components';

export default function FilesPage() {
  const [files, setFiles] = useState<Array<{ name: string; size: number; type: string }>>([]);
  const [uploading, setUploading] = useState(false);

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
    // TODO: Upload to ACORDE
    await new Promise(r => setTimeout(r, 1000)); // Sim
    const fileInfos = newFiles.map(f => ({
      name: f.name,
      size: f.size,
      type: f.type,
    }));
    setFiles(prev => [...prev, ...fileInfos]);
    setUploading(false);
  };

  return (
    <PageLayout>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2rem' }}>
        <h1 style={{ fontSize: '1.75rem', fontWeight: 700 }}>Files</h1>
      </div>

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
      {files.length > 0 && (
        <div style={{ display: 'grid', gap: '0.75rem' }}>
          {files.map((file, i) => (
            <div
              key={i}
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
                {file.type.includes('pdf') ? '📄' : file.type.includes('image') ? '🖼️' : '📝'}
              </span>
              <div style={{ flex: 1 }}>
                <div style={{ fontWeight: 500, color: 'var(--text-primary)' }}>{file.name}</div>
                <div style={{ color: 'var(--text-muted)', fontSize: '0.8rem' }}>
                  {(file.size / 1024).toFixed(1)} KB
                </div>
              </div>
              <button style={{ 
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
      )}
    </PageLayout>
  );
}
