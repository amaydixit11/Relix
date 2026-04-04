'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useVaultStatus, useHealthCheck, exportService, acorde } from '@relix/core';
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

        {/* Sync & Pairing */}
        <Section title="P2P Mesh & Pairing">
          <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
            <div style={{ padding: '0.5rem 0' }}>
              <h3 style={{ fontSize: '0.9rem', marginBottom: '0.5rem' }}>Invite a new device</h3>
              <p style={{ color: 'var(--text-secondary)', fontSize: '0.8rem', marginBottom: '1rem' }}>
                Generate a secure invite code to connect another system to your garden.
              </p>
              <InviteAction />
            </div>
            
            <div style={{ borderTop: '1px solid var(--border)', paddingTop: '1rem' }}>
              <h3 style={{ fontSize: '0.9rem', marginBottom: '0.5rem' }}>Join an existing mesh</h3>
              <p style={{ color: 'var(--text-secondary)', fontSize: '0.8rem', marginBottom: '1rem' }}>
                Enter an invite code from another device to pair them.
              </p>
              <PairAction />
            </div>
          </div>
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

function InviteAction() {
  const [invite, setInvite] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const handleInvite = async () => {
    setLoading(true);
    try {
      const code = await acorde.generateInvite();
      setInvite(code);
    } catch (err) {
      alert('Invite failed: ' + (err as Error).message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div>
      {!invite ? (
        <button onClick={handleInvite} disabled={loading}>
          {loading ? 'Generating...' : 'Generate Invite Link'}
        </button>
      ) : (
        <div style={{ background: 'var(--bg-tertiary)', padding: '1rem', borderRadius: '8px', border: '1px solid var(--accent)' }}>
          <p style={{ fontSize: '0.75rem', color: 'var(--accent)', marginBottom: '0.5rem' }}>Invite Code:</p>
          <code style={{ fontSize: '0.8rem', wordBreak: 'break-all' }}>{invite}</code>
          <button 
            onClick={() => { navigator.clipboard.writeText(invite); alert('Copied!'); }}
            style={{ marginTop: '0.75rem', fontSize: '0.75rem', padding: '4px 8px' }}
          >
            Copy Code
          </button>
        </div>
      )}
    </div>
  );
}

function PairAction() {
  const [code, setCode] = useState('');
  const [loading, setLoading] = useState(false);

  const handlePair = async () => {
    if (!code) return;
    setLoading(true);
    try {
      await acorde.pairDevice(code);
      alert('Device paired successfully!');
      window.location.reload(); // Refresh status
    } catch (err) {
      alert('Pairing failed: ' + (err as Error).message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ display: 'flex', gap: '0.5rem' }}>
      <input 
        type="text" 
        value={code} 
        onChange={e => setCode(e.target.value)} 
        placeholder="Paste invite code here..."
        style={{ flex: 1, fontSize: '0.85rem' }}
      />
      <button onClick={handlePair} disabled={loading || !code}>
        {loading ? 'Pairing...' : 'Join Mesh'}
      </button>
    </div>
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
