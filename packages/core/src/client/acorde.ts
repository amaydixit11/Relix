import type { Entry, EntryType, LocalIdentity, NoteFilter, PeerInfo, SyncStatus, VaultInfo } from '../models';

const API_BASE =
  process.env.ACORDE_BASE_URL ||
  process.env.NEXT_PUBLIC_ACORDE_BASE_URL ||
  process.env.NEXT_PUBLIC_ACORDE_URI ||
  'http://localhost:7331';

/**
 * ACORDE REST API Client
 * Wraps the published ACORDE daemon REST API contract.
 */
export class AcordeClient {
  private baseUrl: string;
  private capabilities = new Map<string, boolean>();
  private capabilityEpoch = 0;

  constructor(baseUrl: string = API_BASE) {
    this.baseUrl = baseUrl;
  }

  /**
   * Update the API base URL at runtime.
   * Useful for mobile apps switching between local and remote daemons.
   */
  setBaseUrl(url: string) {
    this.baseUrl = url;
    this.capabilities.clear();
    this.capabilityEpoch += 1;
  }

  getBaseUrl() {
    return this.baseUrl;
  }

  async listEntries<T>(filter?: NoteFilter): Promise<Entry<T>[]> {
    const params = new URLSearchParams();
    if (filter?.type) params.set('type', filter.type);
    if (filter?.tag) params.set('tag', filter.tag);
    if (filter?.limit) params.set('limit', filter.limit.toString());
    if (filter?.offset) params.set('offset', filter.offset.toString());

    const res = await fetch(`${this.baseUrl}/entries?${params}`);
    if (!res.ok) throw new Error(`Failed to list entries: ${res.statusText}`);

    const data = await res.json();
    return this.decodeEntries<T>(data);
  }

  async getEntry<T>(id: string): Promise<Entry<T>> {
    const res = await fetch(`${this.baseUrl}/entries/${id}`);
    if (!res.ok) throw new Error(`Entry not found: ${id}`);

    const data = await res.json();
    return this.decodeEntry<T>(data);
  }

  async createEntry<T>(
    type: EntryType,
    content: T,
    tags: string[] = []
  ): Promise<Entry<T>> {
    const res = await fetch(`${this.baseUrl}/entries`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        type,
        content: JSON.stringify(content),
        tags,
      }),
    });

    if (!res.ok) throw new Error(`Failed to create entry: ${res.statusText}`);
    const data = await res.json();
    return this.decodeEntry<T>(data);
  }

  async updateEntry<T>(
    id: string,
    content?: T,
    tags?: string[]
  ): Promise<Entry<T>> {
    const body: Record<string, unknown> = {};
    if (content !== undefined) body.content = JSON.stringify(content);
    if (tags !== undefined) body.tags = tags;

    const res = await fetch(`${this.baseUrl}/entries/${id}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });

    if (!res.ok) throw new Error(`Failed to update entry: ${res.statusText}`);
    const data = await this.readJsonBody<Record<string, unknown>>(res);
    if (data) {
      return this.decodeEntry<T>(data);
    }

    // Some ACORDE builds return 200/204 with an empty body on update.
    // Re-fetch the entry so callers still receive the updated resource.
    return this.getEntry<T>(id);
  }

  async deleteEntry(id: string): Promise<void> {
    const res = await fetch(`${this.baseUrl}/entries/${id}`, {
      method: 'DELETE',
    });
    if (!res.ok) throw new Error(`Failed to delete entry: ${res.statusText}`);
  }

  async authorizeWriter(entryId: string, peerId: string): Promise<void> {
    const res = await fetch(`${this.baseUrl}/entries/${entryId}/authorize`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ peer_id: peerId }),
    });
    if (!res.ok) throw new Error(`Failed to authorize writer access: ${res.statusText}`);
  }

  async searchEntries<T>(query: string, type?: EntryType): Promise<Entry<T>[]> {
    if (!(await this.hasCapability('search'))) {
      const entries = await this.listEntries<T>(type ? { type } : undefined);
      const lowered = query.trim().toLowerCase();
      if (!lowered) return entries;

      return entries.filter((entry) =>
        JSON.stringify(entry.content).toLowerCase().includes(lowered) ||
        entry.tags.some((tag) => tag.toLowerCase().includes(lowered))
      );
    }

    const params = new URLSearchParams();
    params.set('q', query);
    if (type) params.set('type', type);

    const res = await fetch(`${this.baseUrl}/search?${params}`);
    if (!res.ok) throw new Error(`Search failed: ${res.statusText}`);

    const data = await res.json();
    return this.decodeEntries<T>(data);
  }

  async generateInvite(): Promise<string> {
    await this.requireCapability('invite', 'This ACORDE runtime does not expose /invite.');
    const res = await fetch(`${this.baseUrl}/invite`, { method: 'POST' });
    if (!res.ok) throw new Error(`Failed to generate invite: ${res.statusText}`);
    const data = await res.json();
    return data.code;
  }

  async pairDevice(code: string): Promise<void> {
    await this.requireCapability('pair', 'This ACORDE runtime does not expose /pair.');
    const res = await fetch(`${this.baseUrl}/pair`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ code }),
    });
    if (!res.ok) throw new Error(`Failed to pair device: ${res.statusText}`);
  }

  async getIdentity(): Promise<LocalIdentity> {
    await this.requireCapability('identity', 'This ACORDE runtime does not expose /identity.');
    const res = await fetch(`${this.baseUrl}/identity`);
    if (!res.ok) throw new Error(`Failed to get identity: ${res.statusText}`);
    return res.json();
  }

  async getPeers(): Promise<PeerInfo[]> {
    await this.requireCapability('peers', 'This ACORDE runtime does not expose /peers.');
    const res = await fetch(`${this.baseUrl}/peers`);
    if (!res.ok) throw new Error(`Failed to get peers: ${res.statusText}`);
    return res.json();
  }

  async getStatus(): Promise<VaultInfo & SyncStatus> {
    const res = await fetch(`${this.baseUrl}/status`);
    if (!res.ok) throw new Error(`Failed to get status: ${res.statusText}`);
    return res.json();
  }

  async healthCheck(): Promise<boolean> {
    try {
      const res = await fetch(`${this.baseUrl}/status`);
      return res.ok;
    } catch {
      return false;
    }
  }

  async uploadBlob(file: Blob): Promise<string> {
    await this.requireCapability('blobs', 'This ACORDE runtime does not expose /blobs.');
    const res = await fetch(`${this.baseUrl}/blobs`, {
      method: 'POST',
      body: file,
    });
    if (!res.ok) throw new Error(`Failed to upload blob: ${res.statusText}`);
    const data = await res.json();
    return data.cid;
  }

  async getBlob(cid: string): Promise<Blob> {
    await this.requireCapability('blobs', 'This ACORDE runtime does not expose /blobs.');
    const res = await fetch(`${this.baseUrl}/blobs/${cid}`);
    if (!res.ok) throw new Error(`Blob not found: ${res.statusText}`);
    return res.blob();
  }

  async hasCapability(route: string): Promise<boolean> {
    if (this.capabilities.has(route)) {
      return this.capabilities.get(route)!;
    }

    const epoch = this.capabilityEpoch;
    try {
      const res = await fetch(`${this.baseUrl}/${route}`, { method: 'GET' });
      const supported = res.status !== 404;
      if (epoch === this.capabilityEpoch) {
        this.capabilities.set(route, supported);
      }
      return supported;
    } catch {
      return false;
    }
  }

  private async requireCapability(route: string, message: string): Promise<void> {
    if (await this.hasCapability(route)) return;
    throw new Error(message);
  }

  subscribeToEvents(
    onEvent: (event: { type: string; entry_id: string }) => void
  ): EventSource {
    const eventSource = new EventSource(`${this.baseUrl}/events`);
    eventSource.onmessage = (e) => {
      try {
        const event = JSON.parse(e.data);
        onEvent(event);
      } catch {
        console.error('Failed to parse event:', e.data);
      }
    };
    return eventSource;
  }

  private decodeEntry<T>(data: Record<string, unknown>): Entry<T> {
    return {
      id: this.pick(data, 'id', 'ID') as string,
      type: this.pick(data, 'type', 'Type') as EntryType,
      content: this.decodeContent<T>(this.pick(data, 'content', 'Content')),
      tags: ((this.pick(data, 'tags', 'Tags') as string[]) || []),
      created_at: (this.pick(data, 'created_at', 'CreatedAt') as number) ?? 0,
      updated_at: (this.pick(data, 'updated_at', 'UpdatedAt') as number) ?? 0,
      deleted: Boolean(this.pick(data, 'deleted', 'Deleted')),
      owner: (this.pick(data, 'owner', 'Owner') as string) ?? '',
    };
  }

  private decodeEntries<T>(data: unknown[]): Entry<T>[] {
    if (!Array.isArray(data)) return [];
    return data.map((item) => this.decodeEntry<T>(item as Record<string, unknown>));
  }

  private pick(data: Record<string, unknown>, ...keys: string[]): unknown {
    for (const key of keys) {
      if (key in data) return data[key];
    }
    return undefined;
  }

  private decodeContent<T>(rawContent: unknown): T {
    if (typeof rawContent !== 'string') {
      return ((rawContent ?? {}) as T);
    }

    const decoded = this.decodeBase64(rawContent);
    return this.parseStructuredContent<T>(decoded ?? rawContent);
  }

  private parseStructuredContent<T>(value: string): T {
    try {
      return JSON.parse(value) as T;
    } catch {
      return ({ raw: value } as unknown) as T;
    }
  }

  private decodeBase64(value: string): string | null {
    try {
      if (typeof atob === 'function') {
        const binary = atob(value);
        const bytes = Uint8Array.from(binary, (char) => char.charCodeAt(0));
        return new TextDecoder().decode(bytes);
      }
    } catch {
      return null;
    }

    try {
      if (typeof Buffer !== 'undefined') {
        return Buffer.from(value, 'base64').toString('utf-8');
      }
    } catch {
      return null;
    }

    return null;
  }

  private async readJsonBody<T>(res: Response): Promise<T | null> {
    const text = await res.text();
    if (!text.trim()) return null;
    return JSON.parse(text) as T;
  }
}

export const acorde = new AcordeClient();
