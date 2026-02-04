import { noteService } from '../services';
import type { Note } from '../models';

/**
 * Export notes to various formats
 */
export class ExportService {
  /**
   * Export a single note to markdown
   */
  noteToMarkdown(note: Note): string {
    const userTags = note.tags
      .filter(t => !t.startsWith('backlink:') && !t.startsWith('outlink:'))
      .map(t => `#${t}`)
      .join(' ');

    const frontmatter = [
      '---',
      `title: "${note.content.title}"`,
      `created: ${new Date(note.content.created_at).toISOString()}`,
      `updated: ${new Date(note.content.updated_at).toISOString()}`,
      userTags ? `tags: [${note.tags.filter(t => !t.startsWith('backlink:') && !t.startsWith('outlink:')).map(t => `"${t}"`).join(', ')}]` : '',
      '---',
      '',
    ].filter(Boolean).join('\n');

    return frontmatter + note.content.body;
  }

  /**
   * Export all notes to a ZIP file
   */
  async exportToZip(): Promise<Blob> {
    const notes = await noteService.list();
    
    // Simple ZIP format without compression
    // In production, use a proper ZIP library like JSZip
    const files: { name: string; content: string }[] = [];

    for (const note of notes) {
      const safeName = note.content.title
        .replace(/[^a-z0-9]/gi, '_')
        .slice(0, 50);
      
      files.push({
        name: `${safeName}.md`,
        content: this.noteToMarkdown(note),
      });
    }

    // Create a simple concatenated export (for real ZIP, use JSZip)
    const manifest = files.map(f => f.name).join('\n');
    const content = files.map(f => `\n===FILE:${f.name}===\n${f.content}`).join('');
    
    return new Blob([`# Relix Export\n# ${new Date().toISOString()}\n# ${files.length} notes\n\n${manifest}\n${content}`], {
      type: 'text/plain',
    });
  }

  /**
   * Download a file in the browser
   */
  downloadFile(content: Blob | string, filename: string) {
    const blob = typeof content === 'string' 
      ? new Blob([content], { type: 'text/markdown' })
      : content;
    
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }

  /**
   * Export single note and trigger download
   */
  async downloadNote(note: Note) {
    const content = this.noteToMarkdown(note);
    const safeName = note.content.title.replace(/[^a-z0-9]/gi, '_').slice(0, 50);
    this.downloadFile(content, `${safeName}.md`);
  }

  /**
   * Export all notes and trigger download
   */
  async downloadAll() {
    const blob = await this.exportToZip();
    const date = new Date().toISOString().split('T')[0];
    this.downloadFile(blob, `relix-export-${date}.txt`);
  }
}

export const exportService = new ExportService();
