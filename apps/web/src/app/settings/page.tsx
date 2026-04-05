'use client';

import { useMemo, useState, type ReactNode } from 'react';
import {
  connectionService,
  exportService,
  useConnectionState,
} from '@relix/core';
import { PageLayout } from '@/components';
import { QRCodeSVG } from 'qrcode.react';

export default function SettingsPage() {
  const connection = useConnectionState();
  const [peerNames, setPeerNames] = useState<Record<string, string>>({});

  const connectedPeers = useMemo(
    () => connection.peers.filter((peer) => peer.is_connected),
    [connection.peers]
  );

  const handleExportMarkdown = async () => {
    try {
      await exportService.downloadAll();
    } catch (err) {
      alert('Export failed: ' + (err as Error).message);
    }
  };

  const handleRename = async (peerId: string) => {
    await connectionService.renamePeer(peerId, peerNames[peerId] ?? '');
  };

  return (
    <PageLayout>
      <h1 style={{ fontSize: '2rem', fontWeight: 700, marginBottom: '2rem' }}>Settings</h1>

      <div style={{ display: 'grid', gap: '2rem', maxWidth: '48rem' }}>
        <Section title="This Device">
          {connection.identity ? (
            <div style={styles.identityCard}>
              <div style={styles.rowBetween}>
                <span style={styles.mutedLabel}>PEER ID</span>
                <span style={styles.accentText}>{connection.identity.peer_id}</span>
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '0.25rem' }}>
                <span style={{ ...styles.mutedLabel, marginBottom: '0.25rem' }}>LOCAL ADDRESSES</span>
                {connection.identity.addrs.slice(0, 3).map((addr, index) => (
                  <div
                    key={index}
                    style={styles.addressLine}
                  >
                    {addr}
                  </div>
                ))}
              </div>
            </div>
          ) : (
            <p style={styles.subtleCopy}>Not connected to daemon</p>
          )}
        </Section>

        <Section title="Fleet Status">
          <StatusRow
            label="Daemon"
            value={connection.daemonReachable ? 'Online' : 'Offline'}
            status={connection.daemonReachable ? 'success' : 'error'}
          />
          <StatusRow
            label="Connection"
            value={connection.connectionType}
            status={connection.connectionType === 'relay' ? 'warning' : 'success'}
          />
          <StatusRow
            label="Active Peers"
            value={String(connectedPeers.length)}
          />
          <StatusRow
            label="Pending Changes"
            value={String(connection.pendingChanges)}
          />
          <StatusRow
            label="Reachability"
            value={connection.relayStatus === 'local_network_only' ? 'Local network only' : connection.relayStatus}
            status={connection.relayStatus === 'local_network_only' ? 'warning' : 'success'}
          />
        </Section>

        <Section title="Pair New Device">
          <div style={styles.warningBadge}>
            <span style={styles.warningDot} />
            Local Network Only Until Relay Is Verified
          </div>
          <p style={{ ...styles.bodyCopy, marginBottom: '1.5rem' }}>
            Pairing UI is ready. Internet reachability is still documented as unverified, so users should expect reliable pairing only on the same LAN until relay support is confirmed.
          </p>

          <div style={{ display: 'grid', gap: '2rem' }}>
            <InviteAction />

            <div style={{ paddingTop: '1.5rem', borderTop: '1px solid rgba(255, 255, 255, 0.05)' }}>
              <h3 style={{ fontSize: '0.95rem', fontWeight: 600, marginBottom: '0.75rem' }}>Join Remote Mesh</h3>
              <PairAction />
            </div>
          </div>
        </Section>

        <Section title="Paired Devices">
          {connection.peers.length === 0 ? (
            <p style={styles.subtleCopy}>No paired peers recorded yet.</p>
          ) : (
            <div style={{ display: 'grid', gap: '1rem' }}>
              {connection.peers.map((peer) => (
                <div key={peer.id} style={styles.peerCard}>
                  <div style={{ ...styles.rowBetween, alignItems: 'flex-start', gap: '1rem', marginBottom: '0.75rem' }}>
                    <div>
                      <div style={{ fontSize: '0.95rem', fontWeight: 600, color: 'var(--text-primary)' }}>{peer.display_name}</div>
                      <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontFamily: 'var(--font-mono)' }}>{peer.id}</div>
                    </div>
                    <span
                      style={{
                        fontSize: '0.625rem',
                        textTransform: 'uppercase',
                        letterSpacing: '0.18em',
                        fontWeight: 700,
                        color: peer.is_connected ? 'var(--success)' : 'var(--text-muted)',
                      }}
                    >
                      {peer.is_connected ? peer.connection_type || 'connected' : 'saved'}
                    </span>
                  </div>

                  <div style={{ display: 'grid', gap: '0.5rem', fontSize: '0.9rem', color: 'var(--text-secondary)', marginBottom: '1rem' }}>
                    <div>First paired: {formatTimestamp(peer.first_paired_at)}</div>
                    <div>Last seen: {formatTimestamp(peer.last_seen_at)}</div>
                    <div>Last sync: {formatTimestamp(peer.last_sync_at)}</div>
                  </div>

                  <div style={{ display: 'flex', gap: '0.5rem' }}>
                    <input
                      type="text"
                      value={peerNames[peer.id] ?? peer.nickname ?? ''}
                      onChange={(event) =>
                        setPeerNames((current) => ({
                          ...current,
                          [peer.id]: event.target.value,
                        }))
                      }
                      placeholder="Peer nickname"
                      style={{ ...styles.input, flex: 1 }}
                    />
                    <button
                      onClick={() => handleRename(peer.id)}
                      style={styles.secondaryButton}
                    >
                      Save
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </Section>

        <Section title="Data Export">
          <p style={{ ...styles.bodyCopy, marginBottom: '1rem' }}>
            Relix is your data. Export your entire library as standard Markdown with YAML frontmatter anytime.
          </p>
          <button
            onClick={handleExportMarkdown}
            style={{ ...styles.secondaryButton, width: '100%', justifyContent: 'center', padding: '0.85rem 1rem' }}
          >
            Export as ZIP
          </button>
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
      const generated = await connectionService.generateInvite();
      setInvite(generated.code);
    } catch (err) {
      alert('Invite failed: ' + (err as Error).message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
      {!invite ? (
        <button
          onClick={handleInvite}
          disabled={loading}
          style={{
            ...styles.primaryButton,
            width: '100%',
            justifyContent: 'center',
            padding: '0.85rem 1rem',
            opacity: loading ? 0.6 : 1,
          }}
        >
          {loading ? 'Generating...' : 'Invite to Fleet'}
        </button>
      ) : (
        <div style={styles.inviteCard}>
          <div style={styles.inviteLayout}>
            <div style={styles.qrShell}>
              <QRCodeSVG value={invite} size={160} level="M" includeMargin={false} />
            </div>
            <div style={{ flex: 1 }}>
              <h4 style={{ color: 'var(--text-primary)', fontWeight: 700, marginBottom: '0.25rem' }}>Device Invite Code</h4>
              <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginBottom: '1rem', fontFamily: 'var(--font-mono)', wordBreak: 'break-all' }}>{invite.slice(0, 32)}...</p>
              <button
                onClick={() => navigator.clipboard.writeText(invite)}
                style={{
                  ...styles.secondaryButton,
                  color: '#a5b4fc',
                  borderColor: 'rgba(129, 140, 248, 0.3)',
                  background: 'rgba(79, 70, 229, 0.15)',
                }}
              >
                Copy Full Code
              </button>
            </div>
          </div>
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
      await connectionService.pairDevice(code);
      setCode('');
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
        onChange={(event) => setCode(event.target.value)}
        placeholder="v1.p2p.invite.xxx..."
        style={{ ...styles.input, flex: 1 }}
      />
      <button
        onClick={handlePair}
        disabled={loading || !code}
        style={{
          ...styles.secondaryButton,
          opacity: loading || !code ? 0.6 : 1,
        }}
      >
        {loading ? 'Pairing...' : 'Join'}
      </button>
    </div>
  );
}

function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section style={styles.section}>
      <h2 style={styles.sectionTitle}>
        {title}
      </h2>
      <div>{children}</div>
    </section>
  );
}

function StatusRow({ label, value, status }: { label: string; value: string; status?: 'success' | 'warning' | 'error' }) {
  const statusColor =
    status === 'success'
      ? 'var(--success)'
      : status === 'warning'
        ? 'var(--warning)'
        : status === 'error'
          ? 'var(--error)'
          : 'var(--text-primary)';

  return (
    <div style={styles.statusRow}>
      <span style={{ color: 'var(--text-muted)' }}>{label}</span>
      <span style={{ fontFamily: 'var(--font-mono)', color: statusColor }}>{value}</span>
    </div>
  );
}

function formatTimestamp(value?: number) {
  if (!value) return 'Never';
  return new Date(value * 1000).toLocaleString();
}

const styles = {
  section: {
    background: 'rgba(17, 24, 39, 0.45)',
    borderRadius: '1rem',
    border: '1px solid rgba(255, 255, 255, 0.06)',
    padding: '1.5rem',
    backdropFilter: 'blur(10px)',
  },
  sectionTitle: {
    fontSize: '0.8rem',
    fontWeight: 700,
    color: 'var(--text-muted)',
    textTransform: 'uppercase' as const,
    letterSpacing: '0.14em',
    marginBottom: '1.5rem',
    paddingBottom: '0.5rem',
    borderBottom: '1px solid rgba(255, 255, 255, 0.05)',
  },
  identityCard: {
    padding: '1rem',
    background: 'rgba(0, 0, 0, 0.2)',
    borderRadius: '0.75rem',
    border: '1px solid rgba(255, 255, 255, 0.05)',
    fontFamily: 'var(--font-mono)',
    fontSize: '0.75rem',
  },
  rowBetween: {
    display: 'flex',
    justifyContent: 'space-between',
    marginBottom: '0.5rem',
  },
  mutedLabel: {
    color: 'var(--text-muted)',
  },
  accentText: {
    color: '#818cf8',
  },
  addressLine: {
    color: 'var(--text-secondary)',
    opacity: 0.7,
    overflow: 'hidden',
    whiteSpace: 'nowrap' as const,
    textOverflow: 'ellipsis',
  },
  subtleCopy: {
    color: 'var(--text-muted)',
    fontSize: '0.9rem',
  },
  bodyCopy: {
    color: 'var(--text-secondary)',
    fontSize: '0.95rem',
    lineHeight: 1.6,
  },
  warningBadge: {
    marginBottom: '1rem',
    display: 'inline-flex',
    alignItems: 'center',
    gap: '0.5rem',
    padding: '0.45rem 0.8rem',
    borderRadius: '999px',
    border: '1px solid rgba(251, 191, 36, 0.2)',
    background: 'rgba(251, 191, 36, 0.1)',
    color: 'var(--warning)',
    fontSize: '0.75rem',
    fontWeight: 700,
    textTransform: 'uppercase' as const,
    letterSpacing: '0.08em',
  },
  warningDot: {
    width: '0.375rem',
    height: '0.375rem',
    borderRadius: '999px',
    background: 'var(--warning)',
  },
  peerCard: {
    borderRadius: '1rem',
    border: '1px solid rgba(255, 255, 255, 0.05)',
    background: 'rgba(0, 0, 0, 0.2)',
    padding: '1rem',
  },
  input: {
    background: 'rgba(0, 0, 0, 0.3)',
    border: '1px solid rgba(255, 255, 255, 0.1)',
    borderRadius: '0.75rem',
    padding: '0.7rem 0.9rem',
    fontSize: '0.9rem',
    color: 'var(--text-primary)',
  },
  secondaryButton: {
    padding: '0.7rem 1rem',
    background: 'rgba(255, 255, 255, 0.06)',
    color: 'var(--text-primary)',
    borderRadius: '0.75rem',
    border: '1px solid rgba(255, 255, 255, 0.08)',
    fontSize: '0.875rem',
    fontWeight: 600,
  },
  primaryButton: {
    padding: '0.7rem 1rem',
    background: 'linear-gradient(135deg, var(--accent), #6d28d9)',
    color: '#ffffff',
    borderRadius: '0.75rem',
    border: '1px solid rgba(255, 255, 255, 0.1)',
    fontSize: '0.95rem',
    fontWeight: 700,
    boxShadow: '0 0 24px rgba(139, 92, 246, 0.2)',
  },
  inviteCard: {
    padding: '1.5rem',
    background: 'rgba(17, 24, 39, 0.65)',
    border: '1px solid rgba(255, 255, 255, 0.1)',
    borderRadius: '1rem',
    overflow: 'hidden',
    boxShadow: '0 24px 48px rgba(0, 0, 0, 0.2)',
  },
  inviteLayout: {
    display: 'flex',
    flexWrap: 'wrap' as const,
    gap: '1.5rem',
    alignItems: 'center',
  },
  qrShell: {
    background: '#ffffff',
    padding: '1rem',
    borderRadius: '0.75rem',
  },
  statusRow: {
    display: 'flex',
    justifyContent: 'space-between',
    padding: '0.75rem 0',
    borderBottom: '1px solid rgba(255, 255, 255, 0.03)',
    fontSize: '0.9rem',
  },
};
