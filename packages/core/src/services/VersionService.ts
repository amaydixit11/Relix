import { acorde } from '../client';
import type { Note, NoteContent, Version } from '../models';

/**
 * VersionService - Access note version history
 */
export class VersionService {
  /**
   * Get all versions of a note
   * Note: This requires ACORDE API support for version history
   */
  async getHistory(id: string): Promise<Version[]> {
    // Try to get versions from ACORDE (endpoint may or may not exist)
    try {
      const res = await fetch(`http://localhost:7331/entries/${id}/versions`);
      if (!res.ok) return [];
      const data = await res.json();
      return data.map((v: any, i: number) => ({
        id: v.ID || `v-${i}`,
        entry_id: id,
        number: i + 1,
        content: v.Content,
        created_at: v.CreatedAt || Date.now(),
        author: v.Author || 'local',
      }));
    } catch {
      // Versions endpoint not available
      return [];
    }
  }

  /**
   * Restore a note to a previous version
   */
  async restore(id: string, versionId: string): Promise<Note> {
    const versions = await this.getHistory(id);
    const version = versions.find(v => v.id === versionId);
    
    if (!version) {
      throw new Error('Version not found');
    }

    // Update the note with the historical content
    let content: NoteContent;
    try {
      content = typeof version.content === 'string' 
        ? JSON.parse(atob(version.content))
        : version.content as NoteContent;
    } catch {
      content = version.content as NoteContent;
    }

    return acorde.updateEntry<NoteContent>(id, content);
  }
}

export const versionService = new VersionService();
