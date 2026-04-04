import { acorde } from '../client';
import type { Note, NoteContent, NoteFilter } from '../models';
import { extractWikilinks } from '../utils/backlinks';

/**
 * NoteService - Business logic for notes
 */
export class NoteService {
  /**
   * Create a new note
   */
  async create(
    title: string,
    body: string,
    tags: string[] = []
  ): Promise<Note> {
    const now = Date.now();
    const content: NoteContent = {
      title,
      body,
      format: 'md',
      created_at: now,
      updated_at: now,
    };

    // Extract wikilinks and add as outlink tags
    const wikilinks = extractWikilinks(body);
    const allTags = [...tags, ...wikilinks.map((id) => `outlink:${id}`)];

    const note = await acorde.createEntry<NoteContent>('note', content, allTags);

    // Update backlinks on target notes
    for (const targetId of wikilinks) {
      await this.addBacklink(targetId, note.id);
    }

    return note;
  }

  /**
   * Get a note by ID
   */
  async get(id: string): Promise<Note> {
    return acorde.getEntry<NoteContent>(id);
  }

  /**
   * Update a note
   */
  async update(
    id: string,
    patch: Partial<Pick<NoteContent, 'title' | 'body'>>,
    tags?: string[]
  ): Promise<Note> {
    const existing = await this.get(id);
    const oldWikilinks = extractWikilinks(existing.content.body);

    const content: NoteContent = {
      ...existing.content,
      ...patch,
      updated_at: Date.now(),
    };

    // Handle wikilink changes
    const newWikilinks = extractWikilinks(content.body);
    const added = newWikilinks.filter((id) => !oldWikilinks.includes(id));
    const removed = oldWikilinks.filter((id) => !newWikilinks.includes(id));

    // Update outlink tags
    let allTags = tags ?? existing.tags.filter((t) => !t.startsWith('outlink:'));
    allTags = [...allTags, ...newWikilinks.map((id) => `outlink:${id}`)];

    const note = await acorde.updateEntry<NoteContent>(id, content, allTags);

    // Update backlinks
    for (const targetId of added) {
      await this.addBacklink(targetId, id);
    }
    for (const targetId of removed) {
      await this.removeBacklink(targetId, id);
    }

    return note;
  }

  /**
   * Delete a note
   */
  async delete(id: string): Promise<void> {
    // Remove backlinks from targets
    const note = await this.get(id);
    const wikilinks = extractWikilinks(note.content.body);
    for (const targetId of wikilinks) {
      await this.removeBacklink(targetId, id);
    }

    await acorde.deleteEntry(id);
  }

  /**
   * List notes with optional filters
   */
  async list(filter?: NoteFilter): Promise<Note[]> {
    return acorde.listEntries<NoteContent>({ ...filter, type: 'note' });
  }

  /**
   * Search notes
   */
  async search(query: string, limit = 20): Promise<Note[]> {
    void limit; // Limit not easily supported by simple search wrapper yet
    return acorde.searchEntries<NoteContent>(query, 'note');
  }

  /**
   * Get notes that link TO this note (backlinks)
   */
  async getBacklinks(id: string): Promise<Note[]> {
    return acorde.listEntries<NoteContent>({ type: 'note', tag: `outlink:${id}` });
  }

  /**
   * Get notes that this note links TO (outlinks)
   */
  async getOutlinks(id: string): Promise<Note[]> {
    const note = await this.get(id);
    const outlinks = note.tags
      .filter((t) => t.startsWith('outlink:'))
      .map((t) => t.replace('outlink:', ''));

    const notes: Note[] = [];
    for (const targetId of outlinks) {
      try {
        notes.push(await this.get(targetId));
      } catch {
        // Note may have been deleted
      }
    }
    return notes;
  }

  // ─────────────────────────────────────────────────────────────
  // Internal helpers
  // ─────────────────────────────────────────────────────────────

  private async addBacklink(targetId: string, sourceId: string): Promise<void> {
    try {
      const target = await this.get(targetId);
      const tag = `backlink:${sourceId}`;
      if (!target.tags.includes(tag)) {
        await acorde.updateEntry(targetId, undefined, [...target.tags, tag]);
      }
    } catch {
      // Target note doesn't exist yet - that's ok
    }
  }

  private async removeBacklink(targetId: string, sourceId: string): Promise<void> {
    try {
      const target = await this.get(targetId);
      const tag = `backlink:${sourceId}`;
      const newTags = target.tags.filter((t) => t !== tag);
      if (newTags.length !== target.tags.length) {
        await acorde.updateEntry(targetId, undefined, newTags);
      }
    } catch {
      // Target note doesn't exist - that's ok
    }
  }
}

export const noteService = new NoteService();
