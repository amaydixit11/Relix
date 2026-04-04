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
      `created: ${new Date(note.created_at).toISOString()}`,
      `updated: ${new Date(note.updated_at).toISOString()}`,
      userTags ? `tags: [${note.tags.filter(t => !t.startsWith('backlink:') && !t.startsWith('outlink:')).map(t => `"${t}"`).join(', ')}]` : '',
      '---',
      '',
    ].filter(Boolean).join('\n');

    return frontmatter + note.content.body;
  }

  /**
   * Export all notes to a real ZIP file using JSZip
   */
  async exportToZip(): Promise<Blob> {
    const JSZip = (await import('jszip')).default;
    const zip = new JSZip();
    const notes = await noteService.list();

    for (const note of notes) {
      const safeName = note.content.title
        .replace(/[/\\?%*:|"<>]/g, '-')
        .slice(0, 50) || 'untitled';
      
      zip.file(`${safeName}.md`, this.noteToMarkdown(note));
    }

    return await zip.generateAsync({ type: 'blob' });
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
    this.downloadFile(blob, `relix-export-${date}.zip`);
  }
}

export const exportService = new ExportService();
