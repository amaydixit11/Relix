// Entry Types (maps to ACORDE)
export type EntryType = 'note' | 'log' | 'file' | 'event';

// Note Content Schema
export interface NoteContent {
  title: string;
  body: string;
  format: 'md' | 'plain';
  created_at: number;
  updated_at: number;
}

// Log Content Schema  
export interface LogContent {
  date: string; // YYYY-MM-DD
  body: string;
}

// File Content Schema (PDF, images, etc.)
export interface FileContent {
  name: string;
  cid: string; // Content ID from blob store
  size: number;
  mime_type: string;
  annotations?: Annotation[];
}

export interface Annotation {
  page: number;
  x: number;
  y: number;
  text: string;
}

// Link/Bookmark Content Schema
export interface LinkContent {
  url: string;
  title: string;
  excerpt?: string;
  favicon?: string;
}

// Base Entry from ACORDE
export interface Entry<T = unknown> {
  id: string;
  type: EntryType;
  content: T;
  tags: string[];
  created_at: number;
  updated_at: number;
  deleted: boolean;
}

// Typed Entry Aliases
export type Note = Entry<NoteContent>;
export type Log = Entry<LogContent>;
export type File = Entry<FileContent>;
export type Link = Entry<LinkContent>;

// Graph Types
export interface GraphNode {
  id: string;
  title: string;
  type: EntryType;
  tags: string[];
}

export interface GraphEdge {
  source: string;
  target: string;
  type: 'backlink' | 'tag';
}

export interface Graph {
  nodes: GraphNode[];
  edges: GraphEdge[];
}

// Version History
export interface Version {
  id: string;
  entry_id: string;
  number: number;
  content: unknown;
  created_at: number;
  author: string;
}

// Filters
export interface NoteFilter {
  type?: EntryType;
  tag?: string;
  since?: number;
  until?: number;
  limit?: number;
  offset?: number;
}

// Sync Status
export interface SyncStatus {
  connected: boolean;
  peers: number;
  last_sync: number;
  pending_changes: number;
}

// Vault Info
export interface VaultInfo {
  path: string;
  encrypted: boolean;
  entries_count: number;
  blobs_count: number;
}
