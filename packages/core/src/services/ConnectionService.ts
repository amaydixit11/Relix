import { acorde } from '../client';
import type {
  ConnectionState,
  LocalIdentity,
  PairingInvite,
  RelayStatus,
  RemotePeer,
  SyncStatus,
  VaultInfo,
} from '../models';
import { p2pService } from './P2PService';
import { pairedPeersStore } from './PairedPeersStore';

type Listener = () => void;

const DEFAULT_STATE: ConnectionState = {
  initialized: false,
  daemonReachable: false,
  identity: null,
  peers: [],
  connectionType: 'offline',
  lastSync: null,
  pendingChanges: 0,
  relayStatus: 'local_network_only',
};

function inferConnectionType(peers: RemotePeer[]): ConnectionState['connectionType'] {
  if (peers.length === 0) return 'offline';
  if (peers.some((peer) => peer.connection_type === 'relay')) return 'relay';
  if (peers.some((peer) => peer.is_connected)) return 'direct';
  return 'unknown';
}

export class ConnectionService {
  private state: ConnectionState = DEFAULT_STATE;
  private listeners = new Set<Listener>();
  private intervalId: ReturnType<typeof setInterval> | null = null;
  private eventSource: EventSource | null = null;
  private refreshInFlight: Promise<ConnectionState> | null = null;
  private started = false;

  getState(): ConnectionState {
    return this.state;
  }

  subscribe(listener: Listener) {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  private emit() {
    this.listeners.forEach((listener) => listener());
  }

  private setState(next: ConnectionState) {
    this.state = next;
    this.emit();
  }

  async refresh(): Promise<ConnectionState> {
    if (this.refreshInFlight) return this.refreshInFlight;

    this.refreshInFlight = (async () => {
      const isHealthy = await acorde.healthCheck();
      if (!isHealthy) {
        const peers = await pairedPeersStore.mergeConnectedPeers([]);
        const next = {
          ...DEFAULT_STATE,
          initialized: true,
          peers,
        };
        this.setState(next);
        this.refreshInFlight = null;
        return next;
      }

      const [identity, peers, status] = await Promise.all([
        p2pService.getLocalIdentity().catch(() => null as LocalIdentity | null),
        p2pService.getConnectedPeers().catch(() => []),
        p2pService.getStatus().catch(
          () =>
            ({
              connected: true,
              peers: 0,
              last_sync: 0,
              pending_changes: 0,
            } as SyncStatus & Partial<VaultInfo>)
        ),
      ]);

      const mergedPeers = await pairedPeersStore.mergeConnectedPeers(
        peers,
        status.last_sync || undefined
      );

      const next: ConnectionState = {
        initialized: true,
        daemonReachable: true,
        identity,
        peers: mergedPeers,
        connectionType: inferConnectionType(mergedPeers),
        lastSync: status.last_sync || null,
        pendingChanges: status.pending_changes || 0,
        relayStatus: 'local_network_only',
      };

      this.setState(next);
      this.refreshInFlight = null;
      return next;
    })();

    return this.refreshInFlight;
  }

  start() {
    if (this.started) return;
    this.started = true;

    void this.refresh();
    this.intervalId = setInterval(() => {
      void this.refresh();
    }, 5000);

    try {
      this.eventSource = acorde.subscribeToEvents(() => {
        void this.refresh();
      });
    } catch {
      this.eventSource = null;
    }
  }

  stop() {
    if (this.intervalId) clearInterval(this.intervalId);
    this.intervalId = null;
    this.eventSource?.close();
    this.eventSource = null;
    this.started = false;
  }

  setBaseUrl(url: string) {
    p2pService.setBaseUrl(url);
    void this.refresh();
  }

  async generateInvite(): Promise<PairingInvite> {
    const code = await p2pService.generateInvite();
    return {
      code,
      relay_status: this.state.relayStatus,
    };
  }

  async pairDevice(code: string) {
    await p2pService.pairDevice(code);
    await this.refresh();
  }

  async renamePeer(peerId: string, nickname: string) {
    await pairedPeersStore.upsert(peerId, {
      nickname: nickname.trim() || undefined,
    });
    await this.refresh();
  }

  async forgetPeer(peerId: string) {
    await pairedPeersStore.forget(peerId);
    await this.refresh();
  }
}

export const connectionService = new ConnectionService();
