'use client';

import { useState, useEffect } from 'react';

interface ConflictBannerProps {
  entryId: string;
  onResolve: (choice: 'local' | 'remote' | 'merge') => void;
}

/**
 * Banner shown when a sync conflict is detected
 */
export function ConflictBanner({ entryId, onResolve }: ConflictBannerProps) {
  const [visible, setVisible] = useState(true);

  if (!visible) return null;

  return (
    <div style={{
      background: 'linear-gradient(90deg, #f59e0b22, #ef444422)',
      border: '1px solid var(--warning)',
      borderRadius: '8px',
      padding: '1rem',
      marginBottom: '1rem',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      gap: '1rem',
    }}>
      <div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
          <span style={{ fontSize: '1.25rem' }}>⚠️</span>
          <strong style={{ color: 'var(--warning)' }}>Sync Conflict Detected</strong>
        </div>
        <p style={{ color: 'var(--text-secondary)', fontSize: '0.875rem', marginTop: '0.25rem' }}>
          This note was edited on another device. Choose which version to keep.
        </p>
      </div>
      <div style={{ display: 'flex', gap: '0.5rem', flexShrink: 0 }}>
        <button 
          onClick={() => { onResolve('local'); setVisible(false); }}
          style={{ background: 'var(--bg-tertiary)', fontSize: '0.75rem' }}
        >
          Keep Local
        </button>
        <button 
          onClick={() => { onResolve('remote'); setVisible(false); }}
          style={{ background: 'var(--bg-tertiary)', fontSize: '0.75rem' }}
        >
          Use Remote
        </button>
        <button 
          onClick={() => { onResolve('merge'); setVisible(false); }}
          style={{ fontSize: '0.75rem' }}
        >
          View Diff
        </button>
      </div>
    </div>
  );
}

/**
 * Modal for viewing and resolving conflicts
 */
export function ConflictModal({ 
  localContent, 
  remoteContent, 
  onClose,
  onSave,
}: { 
  localContent: string; 
  remoteContent: string;
  onClose: () => void;
  onSave: (content: string) => void;
}) {
  const [merged, setMerged] = useState(localContent);

  return (
    <div style={{
      position: 'fixed',
      inset: 0,
      background: 'rgba(0, 0, 0, 0.8)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      padding: '2rem',
      zIndex: 1000,
    }}>
      <div style={{
        background: 'var(--bg-primary)',
        borderRadius: '12px',
        border: '1px solid var(--border)',
        width: '100%',
        maxWidth: '1200px',
        maxHeight: '80vh',
        overflow: 'hidden',
        display: 'flex',
        flexDirection: 'column',
      }}>
        <div style={{ 
          padding: '1rem', 
          borderBottom: '1px solid var(--border)',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
        }}>
          <h2 style={{ fontSize: '1.25rem' }}>Resolve Conflict</h2>
          <button 
            onClick={onClose}
            style={{ background: 'var(--bg-tertiary)', padding: '0.25rem 0.75rem' }}
          >
            Cancel
          </button>
        </div>

        <div style={{ 
          display: 'grid', 
          gridTemplateColumns: '1fr 1fr 1fr',
          gap: '1rem',
          padding: '1rem',
          flex: 1,
          overflow: 'hidden',
        }}>
          {/* Local version */}
          <div style={{ display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
            <h3 style={{ fontSize: '0.875rem', color: 'var(--text-secondary)', marginBottom: '0.5rem' }}>
              Your Version
            </h3>
            <pre style={{
              flex: 1,
              background: 'var(--bg-secondary)',
              padding: '1rem',
              borderRadius: '8px',
              overflow: 'auto',
              fontSize: '0.75rem',
              whiteSpace: 'pre-wrap',
            }}>
              {localContent}
            </pre>
            <button 
              onClick={() => setMerged(localContent)}
              style={{ marginTop: '0.5rem', background: 'var(--bg-tertiary)', fontSize: '0.75rem' }}
            >
              Use This
            </button>
          </div>

          {/* Remote version */}
          <div style={{ display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
            <h3 style={{ fontSize: '0.875rem', color: 'var(--text-secondary)', marginBottom: '0.5rem' }}>
              Remote Version
            </h3>
            <pre style={{
              flex: 1,
              background: 'var(--bg-secondary)',
              padding: '1rem',
              borderRadius: '8px',
              overflow: 'auto',
              fontSize: '0.75rem',
              whiteSpace: 'pre-wrap',
            }}>
              {remoteContent}
            </pre>
            <button 
              onClick={() => setMerged(remoteContent)}
              style={{ marginTop: '0.5rem', background: 'var(--bg-tertiary)', fontSize: '0.75rem' }}
            >
              Use This
            </button>
          </div>

          {/* Merged result */}
          <div style={{ display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
            <h3 style={{ fontSize: '0.875rem', color: 'var(--accent)', marginBottom: '0.5rem' }}>
              Final Result
            </h3>
            <textarea
              value={merged}
              onChange={(e) => setMerged(e.target.value)}
              style={{
                flex: 1,
                background: 'var(--bg-secondary)',
                padding: '1rem',
                borderRadius: '8px',
                border: '2px solid var(--accent)',
                fontSize: '0.75rem',
                resize: 'none',
                fontFamily: 'monospace',
              }}
            />
            <button 
              onClick={() => onSave(merged)}
              style={{ marginTop: '0.5rem' }}
            >
              Save This Version
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

export default ConflictBanner;
