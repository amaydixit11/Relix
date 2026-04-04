import { acorde } from '../client';
import type { File, FileContent } from '../models';

/**
 * FileService - Business logic for PDFs and other files
 */
export class FileService {
  /**
   * Upload a file to blob storage and create an entry
   */
  async upload(
    file: Blob,
    name: string,
    tags: string[] = []
  ): Promise<File> {
    // Upload content to blob store
    const cid = await acorde.uploadBlob(file);

    const content: FileContent = {
      name,
      cid,
      size: file.size,
      mime_type: file.type || 'application/octet-stream',
      annotations: [],
    };

    return acorde.createEntry<FileContent>('file', content, tags);
  }

  /**
   * Get file entry by ID
   */
  async get(id: string): Promise<File> {
    return acorde.getEntry<FileContent>(id);
  }

  /**
   * List all files
   */
  async list(): Promise<File[]> {
    return acorde.listEntries<FileContent>({ type: 'file' });
  }

  /**
   * Delete a file
   */
  async delete(id: string): Promise<void> {
    await acorde.deleteEntry(id);
  }

  /**
   * Add annotation to a file
   */
  async addAnnotation(
    id: string,
    annotation: { page: number; x: number; y: number; text: string }
  ): Promise<File> {
    const file = await this.get(id);
    const annotations = [...(file.content.annotations || []), annotation];
    
    return acorde.updateEntry<FileContent>(id, {
      ...file.content,
      annotations,
    });
  }
}

export const fileService = new FileService();
