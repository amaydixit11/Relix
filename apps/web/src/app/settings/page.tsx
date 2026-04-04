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
      <h1 className="text-2xl font-bold mb-8">Settings</h1>

      <div className="grid gap-8 max-w-3xl">
        <Section title="This Device">
          {connection.identity ? (
            <div className="p-4 bg-black/20 rounded-lg border border-white/5 font-mono text-xs">
              <div className="mb-2 flex justify-between">
                <span className="text-zinc-500">PEER ID</span>
                <span className="text-indigo-400">{connection.identity.peer_id}</span>
              </div>
              <div className="flex flex-col gap-1">
                <span className="text-zinc-500 mb-1">LOCAL ADDRESSES</span>
                {connection.identity.addrs.slice(0, 3).map((addr, index) => (
                  <div
                    key={index}
                    className="text-zinc-400 opacity-60 overflow-hidden whitespace-nowrap text-ellipsis"
                  >
                    {addr}
                  </div>
                ))}
              </div>
            </div>
          ) : (
            <p className="text-zinc-500 text-sm">Not connected to daemon</p>
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
          <div className="mb-4 inline-flex items-center gap-2 px-3 py-1.5 rounded-full border border-amber-500/20 bg-amber-500/10 text-amber-300 text-xs font-semibold uppercase tracking-wider">
            <span className="w-1.5 h-1.5 rounded-full bg-amber-300" />
            Local Network Only Until Relay Is Verified
          </div>
          <p className="text-sm text-zinc-400 mb-6">
            Pairing UI is ready. Internet reachability is still documented as unverified, so users should expect reliable pairing only on the same LAN until relay support is confirmed.
          </p>

          <div className="grid gap-8">
            <InviteAction />

            <div className="pt-6 border-t border-white/5">
              <h3 className="text-sm font-semibold mb-3">Join Remote Mesh</h3>
              <PairAction />
            </div>
          </div>
        </Section>

        <Section title="Paired Devices">
          {connection.peers.length === 0 ? (
            <p className="text-zinc-500 text-sm">No paired peers recorded yet.</p>
          ) : (
            <div className="grid gap-4">
              {connection.peers.map((peer) => (
                <div key={peer.id} className="rounded-xl border border-white/5 bg-black/20 p-4">
                  <div className="flex items-start justify-between gap-4 mb-3">
                    <div>
                      <div className="text-sm font-semibold text-zinc-100">{peer.display_name}</div>
                      <div className="text-xs text-zinc-500 font-mono">{peer.id}</div>
                    </div>
                    <span className={`text-[10px] uppercase tracking-widest font-bold ${peer.is_connected ? 'text-emerald-400' : 'text-zinc-500'}`}>
                      {peer.is_connected ? peer.connection_type || 'connected' : 'saved'}
                    </span>
                  </div>

                  <div className="grid gap-2 text-sm text-zinc-400 mb-4">
                    <div>First paired: {formatTimestamp(peer.first_paired_at)}</div>
                    <div>Last seen: {formatTimestamp(peer.last_seen_at)}</div>
                    <div>Last sync: {formatTimestamp(peer.last_sync_at)}</div>
                  </div>

                  <div className="flex gap-2">
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
                      className="flex-1 bg-zinc-900 border border-white/10 rounded-lg px-3 py-2 text-sm focus:ring-1 focus:ring-indigo-500 outline-none transition-shadow"
                    />
                    <button
                      onClick={() => handleRename(peer.id)}
                      className="px-4 py-2 bg-zinc-800 hover:bg-zinc-700 text-white rounded-lg text-sm font-semibold"
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
          <p className="text-sm text-zinc-400 mb-4">
            Relix is your data. Export your entire library as standard Markdown with YAML frontmatter anytime.
          </p>
          <button
            onClick={handleExportMarkdown}
            className="w-full py-3 bg-zinc-800 hover:bg-zinc-700 text-white rounded-lg transition-colors font-semibold"
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
    <div className="flex flex-col gap-4">
      {!invite ? (
        <button
          onClick={handleInvite}
          disabled={loading}
          className="w-full py-3 bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white rounded-lg transition-colors font-semibold shadow-lg shadow-indigo-500/20"
        >
          {loading ? 'Generating...' : 'Invite to Fleet'}
        </button>
      ) : (
        <div className="p-6 bg-zinc-900 ring-1 ring-white/10 rounded-xl overflow-hidden shadow-2xl">
          <div className="flex flex-col md:flex-row gap-6 items-center">
            <div className="bg-white p-4 rounded-lg">
              <QRCodeSVG value={invite} size={160} level="M" includeMargin={false} />
            </div>
            <div className="flex-1 text-center md:text-left">
              <h4 className="text-white font-bold mb-1">Device Invite Code</h4>
              <p className="text-xs text-zinc-500 mb-4 font-mono break-all">{invite.slice(0, 32)}...</p>
              <button
                onClick={() => navigator.clipboard.writeText(invite)}
                className="px-4 py-2 bg-indigo-600/20 text-indigo-400 border border-indigo-500/30 rounded-lg text-sm hover:bg-indigo-600/30 transition-colors"
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
    <div className="flex gap-2">
      <input
        type="text"
        value={code}
        onChange={(event) => setCode(event.target.value)}
        placeholder="v1.p2p.invite.xxx..."
        className="flex-1 bg-zinc-900 border border-white/10 rounded-lg px-4 py-2 text-sm focus:ring-1 focus:ring-indigo-500 outline-none transition-shadow"
      />
      <button
        onClick={handlePair}
        disabled={loading || !code}
        className="px-6 py-2 bg-zinc-800 hover:bg-zinc-700 disabled:opacity-50 text-white rounded-lg transition-colors text-sm font-semibold border border-white/5"
      >
        {loading ? 'Pairing...' : 'Join'}
      </button>
    </div>
  );
}

function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="bg-zinc-900/50 rounded-xl border border-white/5 p-6 backdrop-blur-sm">
      <h2 className="text-sm font-bold text-zinc-500 uppercase tracking-wider mb-6 pb-2 border-b border-white/5">
        {title}
      </h2>
      <div>{children}</div>
    </section>
  );
}

function StatusRow({ label, value, status }: { label: string; value: string; status?: 'success' | 'warning' | 'error' }) {
  const statusColor =
    status === 'success'
      ? 'text-emerald-400'
      : status === 'warning'
        ? 'text-amber-300'
        : status === 'error'
          ? 'text-rose-400'
          : 'text-zinc-200';

  return (
    <div className="flex justify-between py-3 border-b border-white/[0.03] text-sm">
      <span className="text-zinc-500">{label}</span>
      <span className={`font-mono ${statusColor}`}>{value}</span>
    </div>
  );
}

function formatTimestamp(value?: number) {
  if (!value) return 'Never';
  return new Date(value * 1000).toLocaleString();
}
