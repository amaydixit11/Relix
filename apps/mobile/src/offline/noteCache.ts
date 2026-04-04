import AsyncStorage from '@react-native-async-storage/async-storage';
import type { Note } from '@relix/core';

export interface CachedNote extends Note {
  pending_sync?: boolean;
  pending_delete?: boolean;
  local_only?: boolean;
}

const NOTES_CACHE_KEY = '@relix/notes_cache';
const NOTE_CACHE_PREFIX = '@relix/note_';

export async function getCachedNotes(): Promise<CachedNote[]> {
  const raw = await AsyncStorage.getItem(NOTES_CACHE_KEY);
  if (!raw) return [];

  try {
    const notes = JSON.parse(raw) as CachedNote[];
    return Array.isArray(notes) ? notes : [];
  } catch {
    return [];
  }
}

export async function setCachedNotes(notes: CachedNote[]): Promise<void> {
  await AsyncStorage.setItem(NOTES_CACHE_KEY, JSON.stringify(notes));
}

export async function getCachedNote(id: string): Promise<CachedNote | null> {
  const raw = await AsyncStorage.getItem(NOTE_CACHE_PREFIX + id);
  if (!raw) return null;

  try {
    return JSON.parse(raw) as CachedNote;
  } catch {
    return null;
  }
}

export async function setCachedNote(note: CachedNote): Promise<void> {
  await AsyncStorage.setItem(NOTE_CACHE_PREFIX + note.id, JSON.stringify(note));
}

export async function removeCachedNote(id: string): Promise<void> {
  await AsyncStorage.removeItem(NOTE_CACHE_PREFIX + id);
}

export async function upsertCachedNote(note: CachedNote): Promise<void> {
  const notes = await getCachedNotes();
  const next = [note, ...notes.filter((entry) => entry.id !== note.id)];
  await setCachedNotes(next);
  await setCachedNote(note);
}

export async function replaceCachedNoteId(tempId: string, note: CachedNote): Promise<void> {
  const notes = await getCachedNotes();
  const next = notes.map((entry) => (entry.id === tempId ? note : entry));
  await setCachedNotes(next);
  await removeCachedNote(tempId);
  await setCachedNote(note);
}

export async function removeCachedNoteEverywhere(id: string): Promise<void> {
  const notes = await getCachedNotes();
  const next = notes.filter((entry) => entry.id !== id);
  await setCachedNotes(next);
  await removeCachedNote(id);
}

export async function mergeRemoteNotes(remoteNotes: Note[]): Promise<CachedNote[]> {
  const localNotes = await getCachedNotes();
  const remoteMap = new Map<string, CachedNote>(
    remoteNotes.map((note) => [note.id, { ...note }])
  );

  for (const local of localNotes) {
    if (local.pending_delete) {
      remoteMap.delete(local.id);
      continue;
    }

    if (local.local_only || local.pending_sync) {
      remoteMap.set(local.id, local);
    }
  }

  const merged = Array.from(remoteMap.values()).sort((a, b) => b.updated_at - a.updated_at);
  await setCachedNotes(merged);

  await Promise.all(merged.map((note) => setCachedNote(note)));
  return merged;
}
