import type { Entry, NoteFilter, VaultInfo, SyncStatus, EntryType } from '../models';

const API_BASE = 'http://localhost:7331';

/**
 * ACORDE REST API Client
 * Wraps the ACORDE daemon REST API
 */
export class AcordeClient {
  private baseUrl: string;

  constructor(baseUrl: string = API_BASE) {
    this.baseUrl = baseUrl;
  }

  // ─────────────────────────────────────────────────────────────
  // Entries
  // ─────────────────────────────────────────────────────────────

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
    const data = await res.json();
    return this.decodeEntry<T>(data);
  }

  async deleteEntry(id: string): Promise<void> {
    const res = await fetch(`${this.baseUrl}/entries/${id}`, {
      method: 'DELETE',
    });
    if (!res.ok) throw new Error(`Failed to delete entry: ${res.statusText}`);
  }

  // ─────────────────────────────────────────────────────────────
  // Search
  // ─────────────────────────────────────────────────────────────

  async search<T>(query: string, limit = 20): Promise<Entry<T>[]> {
    const params = new URLSearchParams({ q: query, limit: limit.toString() });
    const res = await fetch(`${this.baseUrl}/search?${params}`);
    if (!res.ok) throw new Error(`Search failed: ${res.statusText}`);

    const data = await res.json();
    return this.decodeEntries<T>(data);
  }

  // ─────────────────────────────────────────────────────────────
  // Status & Health
  // ─────────────────────────────────────────────────────────────

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

  // ─────────────────────────────────────────────────────────────
  // Events (SSE)
  // ─────────────────────────────────────────────────────────────

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

  // ─────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────

  private decodeEntry<T>(data: Record<string, unknown>): Entry<T> {
    let content: T;
    try {
      // ACORDE returns content as base64 string
      const raw = data.Content as string;
      const decoded = atob(raw);
      content = JSON.parse(decoded);
    } catch {
      content = data.Content as T;
    }

    return {
      id: data.ID as string,
      type: data.Type as EntryType,
      content,
      tags: (data.Tags as string[]) || [],
      created_at: data.CreatedAt as number,
      updated_at: data.UpdatedAt as number,
      deleted: data.Deleted as boolean,
    };
  }

  private decodeEntries<T>(data: unknown[]): Entry<T>[] {
    if (!Array.isArray(data)) return [];
    return data.map((item) => this.decodeEntry<T>(item as Record<string, unknown>));
  }
}

// Singleton instance
export const acorde = new AcordeClient();
