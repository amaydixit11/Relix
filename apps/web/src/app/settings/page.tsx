'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
import { useVaultStatus, useHealthCheck, exportService, acorde, p2pService } from '@relix/core';
import type { LocalIdentity, PeerInfo } from '@relix/core';
import { PageLayout } from '@/components';
import { QRCodeSVG } from 'qrcode.react';

export default function SettingsPage() {
  const { data: status, refetch: refetchStatus } = useVaultStatus();
  const { data: isHealthy } = useHealthCheck();
  const [identity, setIdentity] = useState<LocalIdentity | null>(null);
  const [peers, setPeers] = useState<PeerInfo[]>([]);

  useEffect(() => {
    if (isHealthy) {
      p2pService.getLocalIdentity().then(setIdentity);
      p2pService.getConnectedPeers().then(setPeers);
    }
  }, [isHealthy]);

  const handleExportMarkdown = async () => {
    try {
      await exportService.downloadAll();
    } catch (err) {
      alert('Export failed: ' + (err as Error).message);
    }
  };

  return (
    <PageLayout>
      <h1 className="text-2xl font-bold mb-8">Settings</h1>

      <div className="grid gap-8 max-w-2xl">
        {/* P2P Identity */}
        <Section title="This Device">
          {identity ? (
            <div className="p-4 bg-black/20 rounded-lg border border-white/5 font-mono text-xs">
              <div className="mb-2 flex justify-between">
                <span className="text-zinc-500">PEER ID</span>
                <span className="text-indigo-400">{identity.peer_id}</span>
              </div>
              <div className="flex flex-col gap-1">
                <span className="text-zinc-500 mb-1">LOCAL ADDRESSES</span>
                {identity.addrs.slice(0, 3).map((a, i) => (
                  <div key={i} className="text-zinc-400 opacity-60 overflow-hidden whitespace-nowrap text-ellipsis">
                    {a}
                  </div>
                ))}
              </div>
            </div>
          ) : (
            <p className="text-zinc-500 text-sm">Not connected to daemon</p>
          )}
        </Section>

        {/* Sync Status */}
        <Section title="Fleet Status">
          <StatusRow 
            label="Daemon" 
            value={isHealthy ? 'Online' : 'Offline'} 
            status={isHealthy ? 'success' : 'error'} 
          />
          {status && (
            <>
              <StatusRow label="Local Vault" value={String(status.entries_count || 0) + ' notes'} />
              <StatusRow label="Active Peers" value={String(peers.length || 0)} />
            </>
          )}
        </Section>

        {/* Sync & Pairing */}
        <Section title="Pair New Device">
          <p className="text-sm text-zinc-400 mb-6">
            Generate an invite to peer other Relix instances. This allows seamless E2E encrypted sync over local networks or global relays.
          </p>
          
          <div className="grid gap-8">
            <InviteAction />
            
            <div className="pt-6 border-t border-white/5">
              <h3 className="text-sm font-semibold mb-3">Join Remote Mesh</h3>
              <PairAction onSuccess={refetchStatus} />
            </div>
          </div>
        </Section>

        {/* Export */}
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
      const code = await acorde.generateInvite();
      setInvite(code);
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
              <QRCodeSVG 
                value={invite} 
                size={160}
                level="M"
                includeMargin={false}
              />
            </div>
            <div className="flex-1 text-center md:text-left">
              <h4 className="text-white font-bold mb-1">Device Invite Code</h4>
              <p className="text-xs text-zinc-500 mb-4 font-mono break-all">{invite.slice(0, 32)}...</p>
              <button 
                onClick={() => { navigator.clipboard.writeText(invite); alert('Copied!'); }}
                className="px-4 py-2 bg-indigo-600/20 text-indigo-400 border border-indigo-500/30 rounded-lg text-sm hover:bg-indigo-600/30 transition-colors"
              >
                Copy Full Code
              </button>
            </div>
          </div>
          <p className="mt-6 text-[10px] text-zinc-600 uppercase tracking-widest text-center">
            Valid for 24 hours • AES-256 Secured
          </p>
        </div>
      )}
    </div>
  );
}

function PairAction({ onSuccess }: { onSuccess: () => void }) {
  const [code, setCode] = useState('');
  const [loading, setLoading] = useState(false);

  const handlePair = async () => {
    if (!code) return;
    setLoading(true);
    try {
      await acorde.pairDevice(code);
      alert('Device paired successfully!');
      onSuccess();
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
        onChange={e => setCode(e.target.value)} 
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

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="bg-zinc-900/50 rounded-xl border border-white/5 p-6 backdrop-blur-sm">
      <h2 className="text-sm font-bold text-zinc-500 uppercase tracking-wider mb-6 pb-2 border-b border-white/5">
        {title}
      </h2>
      <div>
        {children}
      </div>
    </section>
  );
}

function StatusRow({ label, value, status }: { label: string; value: string; status?: 'success' | 'warning' | 'error' }) {
  const statusColor = status === 'success' ? 'text-emerald-400' : status === 'error' ? 'text-rose-400' : 'text-zinc-200';
  return (
    <div className="flex justify-between py-3 border-b border-white/[0.03] text-sm">
      <span className="text-zinc-500">{label}</span>
      <span className={`font-mono ${statusColor}`}>{value}</span>
    </div>
  );
}
