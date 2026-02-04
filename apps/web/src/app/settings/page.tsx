'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useVaultStatus, useHealthCheck, exportService } from '@relix/core';
import { PageLayout } from '@/components';

export default function SettingsPage() {
  const { data: status } = useVaultStatus();
  const { data: isHealthy } = useHealthCheck();

  const handleExportMarkdown = async () => {
    try {
      await exportService.downloadAll();
    } catch (err) {
      alert('Export failed: ' + (err as Error).message);
    }
  };

  return (
    <PageLayout>
      <h1 style={{ fontSize: '1.75rem', fontWeight: 700, marginBottom: '2rem' }}>Settings</h1>

      <div style={{ display: 'grid', gap: '2rem' }}>
        {/* Status */}
        <Section title="Sync Status">
          <StatusRow 
            label="ACORDE Daemon" 
            value={isHealthy ? 'Connected' : 'Disconnected'} 
            status={isHealthy ? 'success' : 'error'} 
          />
          {status && (
            <>
              <StatusRow label="Total Notes" value={String(status.entries_count || 0)} />
              <StatusRow label="Active Peers" value={String(status.peers || 0)} />
              <StatusRow 
                label="Last Sync" 
                value={status.last_sync ? new Date(status.last_sync).toLocaleString() : 'Never'} 
              />
            </>
          )}
        </Section>

        {/* Vault */}
        <Section title="Vault Configuration">
          {status && (
            <StatusRow label="Local Path" value={status.path || '~/.relix'} />
          )}
          <StatusRow label="Encryption" value="Enabled (AES-256)" status="success" />
        </Section>

        {/* Export */}
        <Section title="Data Management">
          <div style={{ padding: '0.5rem 0' }}>
            <p style={{ color: 'var(--text-secondary)', fontSize: '0.9rem', marginBottom: '1rem' }}>
              Download your entire digital garden as standard Markdown files.
            </p>
            <button onClick={handleExportMarkdown} style={{ width: '100%', justifyContent: 'center' }}>
              Export All Notes (ZIP)
            </button>
          </div>
        </Section>

        {/* Shortcuts */}
        <Section title="Keyboard Shortcuts">
          <div style={{ display: 'grid', gap: '0.75rem' }}>
            <Shortcut label="Command Palette" keys={['⌘', 'K']} />
            <Shortcut label="New Note" keys={['⌘', 'N']} />
            <Shortcut label="Quick Capture" keys={['⌘', '⇧', 'N']} />
            <Shortcut label="Graph View" keys={['⌘', 'G']} />
            <Shortcut label="Save Note" keys={['⌘', 'S']} />
          </div>
        </Section>
      </div>
    </PageLayout>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ 
      background: 'var(--bg-secondary)',
      borderRadius: '8px',
      border: '1px solid var(--border)',
      padding: '1.5rem',
    }}>
      <h2 style={{ 
        fontSize: '1rem', 
        fontWeight: 600, 
        marginBottom: '1rem', 
        color: 'var(--text-primary)',
        paddingBottom: '0.75rem',
        borderBottom: '1px solid var(--border)',
      }}>
        {title}
      </h2>
      <div style={{ display: 'flex', flexDirection: 'column' }}>
        {children}
      </div>
    </section>
  );
}

function StatusRow({ label, value, status }: { label: string; value: string; status?: 'success' | 'warning' | 'error' }) {
  const color = status === 'success' ? 'var(--success)' : status === 'error' ? 'var(--error)' : 'var(--text-primary)';
  return (
    <div style={{ 
      display: 'flex', 
      justifyContent: 'space-between', 
      padding: '0.75rem 0', 
      borderBottom: '1px solid var(--border-light)',
      fontSize: '0.9rem',
    }}>
      <span style={{ color: 'var(--text-secondary)' }}>{label}</span>
      <span style={{ color, fontFamily: 'var(--font-mono)' }}>{value}</span>
    </div>
  );
}

function Shortcut({ label, keys }: { label: string; keys: string[] }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
      <span style={{ color: 'var(--text-secondary)', fontSize: '0.9rem' }}>{label}</span>
      <div style={{ display: 'flex', gap: '0.25rem' }}>
        {keys.map(k => (
          <kbd key={k} style={{
            background: 'var(--bg-tertiary)',
            border: '1px solid var(--border)',
            borderRadius: '4px',
            padding: '2px 6px',
            fontSize: '0.75rem',
            fontFamily: 'var(--font-mono)',
            minWidth: '20px',
            textAlign: 'center',
          }}>{k}</kbd>
        ))}
      </div>
    </div>
  );
}
