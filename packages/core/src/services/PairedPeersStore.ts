import type { PairedPeerMetadata, PeerInfo, RemotePeer } from '../models';
import { getRuntimeStorage } from './runtimeStorage';

const PAIRED_PEERS_KEY = '@relix/paired_peers';

function nowSeconds() {
  return Math.floor(Date.now() / 1000);
}

export class PairedPeersStore {
  private async readAll(): Promise<PairedPeerMetadata[]> {
    const raw = await getRuntimeStorage().getItem(PAIRED_PEERS_KEY);
    if (!raw) return [];

    try {
      const parsed = JSON.parse(raw) as PairedPeerMetadata[];
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  }

  private async writeAll(peers: PairedPeerMetadata[]): Promise<void> {
    await getRuntimeStorage().setItem(PAIRED_PEERS_KEY, JSON.stringify(peers));
  }

  async list(): Promise<PairedPeerMetadata[]> {
    return this.readAll();
  }

  async get(peerId: string): Promise<PairedPeerMetadata | null> {
    const peers = await this.readAll();
    return peers.find((peer) => peer.peer_id === peerId) ?? null;
  }

  async upsert(
    peerId: string,
    patch: Partial<PairedPeerMetadata> = {}
  ): Promise<PairedPeerMetadata> {
    const peers = await this.readAll();
    const existing = peers.find((peer) => peer.peer_id === peerId);
    const next: PairedPeerMetadata = {
      peer_id: peerId,
      first_paired_at: existing?.first_paired_at ?? nowSeconds(),
      nickname: patch.nickname ?? existing?.nickname,
      last_seen_at: patch.last_seen_at ?? existing?.last_seen_at,
      last_sync_at: patch.last_sync_at ?? existing?.last_sync_at,
      last_connection_type: patch.last_connection_type ?? existing?.last_connection_type,
    };

    const updated = [...peers.filter((peer) => peer.peer_id !== peerId), next];
    await this.writeAll(updated.sort((a, b) => a.peer_id.localeCompare(b.peer_id)));
    return next;
  }

  async touch(
    peerId: string,
    patch: Partial<PairedPeerMetadata> = {}
  ): Promise<PairedPeerMetadata> {
    const peers = await this.readAll();
    const existing = peers.find((peer) => peer.peer_id === peerId);
    const next: PairedPeerMetadata = {
      peer_id: peerId,
      first_paired_at: existing?.first_paired_at ?? nowSeconds(),
      nickname: existing?.nickname,
      last_seen_at: patch.last_seen_at ?? existing?.last_seen_at,
      last_sync_at: patch.last_sync_at ?? existing?.last_sync_at,
      last_connection_type: patch.last_connection_type ?? existing?.last_connection_type,
    };

    const changed =
      !existing ||
      existing.last_seen_at !== next.last_seen_at ||
      existing.last_sync_at !== next.last_sync_at ||
      existing.last_connection_type !== next.last_connection_type;

    if (changed) {
      const updated = [...peers.filter((peer) => peer.peer_id !== peerId), next];
      await this.writeAll(updated.sort((a, b) => a.peer_id.localeCompare(b.peer_id)));
    }

    return next;
  }

  async forget(peerId: string): Promise<void> {
    const peers = await this.readAll();
    await this.writeAll(peers.filter((peer) => peer.peer_id !== peerId));
  }

  async mergeConnectedPeers(peers: PeerInfo[], lastSyncAt?: number): Promise<RemotePeer[]> {
    const metadata = await this.readAll();
    const metadataMap = new Map(metadata.map((item) => [item.peer_id, item]));

    const merged: RemotePeer[] = await Promise.all(
      peers.map(async (peer) => {
        const metadata = metadataMap.get(peer.id);
        const entry = await this.touch(peer.id, {
          last_seen_at: peer.last_seen ?? nowSeconds(),
          last_sync_at: lastSyncAt,
          last_connection_type: peer.connection_type,
        });

        return {
          ...peer,
          ...entry,
          is_connected: true,
          display_name: metadata?.nickname || peer.name || peer.id,
        } satisfies RemotePeer;
      })
    );

    for (const item of metadata) {
      if (!peers.find((peer) => peer.id === item.peer_id)) {
        merged.push({
          id: item.peer_id,
          addrs: [],
          ...item,
          is_connected: false,
          display_name: item.nickname || item.peer_id,
        });
      }
    }

    return merged.sort((a, b) => {
      if (a.is_connected !== b.is_connected) return a.is_connected ? -1 : 1;
      return a.display_name.localeCompare(b.display_name);
    });
  }
}

export const pairedPeersStore = new PairedPeersStore();
