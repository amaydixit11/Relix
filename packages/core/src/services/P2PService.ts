import { acorde } from '../client/acorde';
import type { LocalIdentity, PeerInfo, SyncStatus } from '../models';

/**
 * P2P & Sync Service
 * Manages device identity, peer connections, and pairing flows.
 */
export class P2PService {
  /**
   * Get this device's P2P identity
   */
  async getLocalIdentity(): Promise<LocalIdentity> {
    return acorde.getIdentity();
  }

  /**
   * Update the backend connection URL (e.g. from local to bridge IP)
   */
  setBaseUrl(url: string) {
    acorde.setBaseUrl(url);
  }

  /**
   * Get list of connected peers
   */
  async getConnectedPeers(): Promise<PeerInfo[]> {
    return acorde.getPeers();
  }

  /**
   * Generate an invite code for this device
   */
  async generateInvite(): Promise<string> {
    return acorde.generateInvite();
  }

  /**
   * Pair with a remote device using an invite code
   */
  async pairDevice(code: string): Promise<void> {
    return acorde.pairDevice(code);
  }

  /**
   * Get overall vault/sync status
   */
  async getStatus(): Promise<SyncStatus> {
    const status = await acorde.getStatus();
    return status;
  }

  /**
   * Subscribe to P2P events (connections, syncs)
   */
  subscribeToEvents(onEvent: (event: any) => void) {
    return acorde.subscribeToEvents(onEvent);
  }
}

export const p2pService = new P2PService();
