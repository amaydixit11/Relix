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
    const content: NoteContent = {
      title,
      body,
      format: 'md',
    };

    // Extract wikilinks and resolve them to IDs
    const wikilinkTitles = extractWikilinks(body);
    const resolvedIds = await this.resolveTitlesToIds(wikilinkTitles);
    
    const allTags = [...tags, ...resolvedIds.map((id) => `outlink:${id}`)];

    const note = await acorde.createEntry<NoteContent>('note', content, allTags);

    // Update backlinks on target notes
    for (const targetId of resolvedIds) {
      await this.addBacklink(targetId, note.id);
    }

    return note;
  }

  /**
   * Get a note by ID
   */
  async get(id: string): Promise<Note> {
    const note = await acorde.getEntry<NoteContent>(id);
    if (note.deleted) throw new Error('Note not found (deleted)');
    return note;
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
    const oldIds = await this.resolveTitlesToIds(oldWikilinks);

    const content: NoteContent = {
      ...existing.content,
      ...patch,
    };

    // Handle wikilink changes
    const newWikilinks = extractWikilinks(content.body);
    const newIds = await this.resolveTitlesToIds(newWikilinks);
    
    const added = newIds.filter((id) => !oldIds.includes(id));
    const removed = oldIds.filter((id) => !newIds.includes(id));

    // Update outlink tags
    let allTags = tags ?? existing.tags.filter((t) => !t.startsWith('outlink:'));
    allTags = [...allTags, ...newIds.map((id) => `outlink:${id}`)];

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
    const resolvedIds = await this.resolveTitlesToIds(wikilinks);
    
    for (const targetId of resolvedIds) {
      await this.removeBacklink(targetId, id);
    }

    await acorde.deleteEntry(id);
  }

  /**
   * List notes with optional filters
   */
  async list(filter?: NoteFilter): Promise<Note[]> {
    const notes = await acorde.listEntries<NoteContent>({ 
      ...filter, 
      type: 'note'
    });
    
    return notes.filter(n => !n.deleted);
  }

  /**
   * Search notes (Client-side filtering for contract compatibility)
   */
  async search(query: string, limit = 20): Promise<Note[]> {
    const notes = await this.list();
    const q = query.toLowerCase();
    
    return notes
      .filter(n => 
        n.content.title.toLowerCase().includes(q) || 
        n.content.body.toLowerCase().includes(q)
      )
      .slice(0, limit);
  }

  /**
   * Resolve a list of wikilink titles (or IDs) to entry IDs.
   * If a title matches an existing note, it returns that ID.
   */
  private async resolveTitlesToIds(identifiers: string[]): Promise<string[]> {
    const allNotes = await this.list();
    const resolved: string[] = [];

    for (const iden of identifiers) {
      // 1. Check if it's already a valid UUID (optional, but good)
      const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
      if (uuidRegex.test(iden)) {
        resolved.push(iden);
        continue;
      }

      // 2. Resolve by title
      const matched = allNotes.find(n => n.content.title.toLowerCase() === iden.toLowerCase());
      if (matched) {
        resolved.push(matched.id);
      }
      // If not found, we don't return an ID (unresolved link)
    }

    return Array.from(new Set(resolved));
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
