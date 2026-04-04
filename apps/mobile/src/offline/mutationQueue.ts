import AsyncStorage from '@react-native-async-storage/async-storage';
import { noteService, type Note } from '@relix/core';
import {
  getCachedNote,
  getCachedNotes,
  removeCachedNoteEverywhere,
  replaceCachedNoteId,
  setCachedNote,
  setCachedNotes,
  type CachedNote,
  upsertCachedNote,
} from './noteCache';

const MUTATION_QUEUE_KEY = '@relix/mutation_queue';
const NOTE_ALIAS_KEY = '@relix/note_aliases';

type MutationKind = 'create' | 'update' | 'delete';

interface BaseMutation {
  id: string;
  kind: MutationKind;
  noteId: string;
  attempts: number;
  queuedAt: number;
}

interface CreateMutation extends BaseMutation {
  kind: 'create';
  payload: {
    title: string;
    body: string;
    tags: string[];
  };
}

interface UpdateMutation extends BaseMutation {
  kind: 'update';
  payload: {
    title?: string;
    body?: string;
  };
}

interface DeleteMutation extends BaseMutation {
  kind: 'delete';
}

export type QueuedMutation = CreateMutation | UpdateMutation | DeleteMutation;

function makeId(prefix: string) {
  return `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

function nowSeconds() {
  return Math.floor(Date.now() / 1000);
}

async function readQueue(): Promise<QueuedMutation[]> {
  const raw = await AsyncStorage.getItem(MUTATION_QUEUE_KEY);
  if (!raw) return [];

  try {
    const queue = JSON.parse(raw) as QueuedMutation[];
    return Array.isArray(queue) ? queue : [];
  } catch {
    return [];
  }
}

async function writeQueue(queue: QueuedMutation[]): Promise<void> {
  await AsyncStorage.setItem(MUTATION_QUEUE_KEY, JSON.stringify(queue));
}

async function readAliases(): Promise<Record<string, string>> {
  const raw = await AsyncStorage.getItem(NOTE_ALIAS_KEY);
  if (!raw) return {};

  try {
    return JSON.parse(raw) as Record<string, string>;
  } catch {
    return {};
  }
}

async function writeAliases(aliases: Record<string, string>): Promise<void> {
  await AsyncStorage.setItem(NOTE_ALIAS_KEY, JSON.stringify(aliases));
}

function normalizeCachedNote(note: Note): CachedNote {
  return {
    ...note,
    pending_sync: false,
    pending_delete: false,
    local_only: false,
  };
}

async function rewriteQueuedNoteId(tempId: string, nextId: string): Promise<void> {
  const queue = await readQueue();
  const aliases = await readAliases();
  let changed = false;

  const updated = queue.map((item) => {
    if (item.noteId !== tempId) return item;
    changed = true;
    return { ...item, noteId: nextId };
  });

  if (changed) {
    await writeQueue(updated);
  }

  aliases[tempId] = nextId;
  await writeAliases(aliases);
}

export async function resolveQueuedNoteId(noteId: string): Promise<string> {
  const aliases = await readAliases();
  return aliases[noteId] ?? noteId;
}

export async function getQueuedMutations(): Promise<QueuedMutation[]> {
  return readQueue();
}

export async function getQueueCount(): Promise<number> {
  const queue = await readQueue();
  return queue.length;
}

export async function queueCreateNote(input: {
  title: string;
  body: string;
  tags: string[];
}): Promise<CachedNote> {
  const tempId = makeId('local-note');
  const cachedNote: CachedNote = {
    id: tempId,
    type: 'note',
    content: {
      title: input.title,
      body: input.body,
      format: 'md',
    },
    tags: input.tags,
    created_at: nowSeconds(),
    updated_at: nowSeconds(),
    deleted: false,
    owner: 'local',
    pending_sync: true,
    local_only: true,
  };

  const queue = await readQueue();
  queue.push({
    id: makeId('mutation'),
    kind: 'create',
    noteId: tempId,
    attempts: 0,
    queuedAt: Date.now(),
    payload: input,
  });

  await upsertCachedNote(cachedNote);
  await writeQueue(queue);
  return cachedNote;
}

export async function queueUpdateNote(noteId: string, patch: {
  title?: string;
  body?: string;
}): Promise<CachedNote> {
  const resolvedId = await resolveQueuedNoteId(noteId);
  const queue = await readQueue();
  const createIndex = queue.findIndex((item) => item.kind === 'create' && item.noteId === resolvedId);

  if (createIndex >= 0) {
    const create = queue[createIndex] as CreateMutation;
    create.payload = {
      ...create.payload,
      ...patch,
      title: patch.title ?? create.payload.title,
      body: patch.body ?? create.payload.body,
    };
    queue[createIndex] = create;
  } else {
    const updateIndex = queue.findIndex((item) => item.kind === 'update' && item.noteId === resolvedId);
    if (updateIndex >= 0) {
      const update = queue[updateIndex] as UpdateMutation;
      update.payload = { ...update.payload, ...patch };
      queue[updateIndex] = update;
    } else {
      queue.push({
        id: makeId('mutation'),
        kind: 'update',
        noteId: resolvedId,
        attempts: 0,
        queuedAt: Date.now(),
        payload: patch,
      });
    }
  }

  const notes = await getCachedNotes();
  const existing =
    notes.find((note) => note.id === resolvedId || note.id === noteId) ??
    (await getCachedNote(noteId)) ??
    (await getCachedNote(resolvedId));
  if (!existing) {
    throw new Error('Note not available in local cache');
  }

  const updated: CachedNote = {
    ...existing,
    content: {
      ...existing.content,
      ...patch,
    },
    updated_at: nowSeconds(),
    pending_sync: true,
  };

  await upsertCachedNote(updated);
  await writeQueue(queue);
  return updated;
}

export async function queueDeleteNote(noteId: string): Promise<void> {
  const resolvedId = await resolveQueuedNoteId(noteId);
  const queue = await readQueue();
  const createIndex = queue.findIndex((item) => item.kind === 'create' && item.noteId === resolvedId);

  if (createIndex >= 0) {
    queue.splice(createIndex, 1);
    await removeCachedNoteEverywhere(resolvedId);
    if (resolvedId !== noteId) {
      await removeCachedNoteEverywhere(noteId);
    }
    await writeQueue(queue);
    return;
  }

  const filtered = queue.filter(
    (item) => !(item.noteId === resolvedId && item.kind === 'update')
  );

  filtered.push({
    id: makeId('mutation'),
    kind: 'delete',
    noteId: resolvedId,
    attempts: 0,
    queuedAt: Date.now(),
  });

  await removeCachedNoteEverywhere(resolvedId);
  if (resolvedId !== noteId) {
    await removeCachedNoteEverywhere(noteId);
  }
  await writeQueue(filtered);
}

export async function drainMutationQueue(): Promise<{
  processed: number;
  remaining: number;
}> {
  const queue = await readQueue();
  if (queue.length === 0) {
    return { processed: 0, remaining: 0 };
  }

  const remaining: QueuedMutation[] = [];
  let processed = 0;

  for (const item of queue) {
    try {
      if (item.kind === 'create') {
        const created = await noteService.create(
          item.payload.title,
          item.payload.body,
          item.payload.tags
        );
        const normalized = normalizeCachedNote(created);
        await replaceCachedNoteId(item.noteId, normalized);
        await rewriteQueuedNoteId(item.noteId, created.id);
      }

      if (item.kind === 'update') {
        const updated = await noteService.update(item.noteId, item.payload);
        await setCachedNote(normalizeCachedNote(updated));

        const notes = await getCachedNotes();
        const next = notes.map((note) =>
          note.id === updated.id ? normalizeCachedNote(updated) : note
        );
        await setCachedNotes(next);
      }

      if (item.kind === 'delete') {
        await noteService.delete(item.noteId);
        await removeCachedNoteEverywhere(item.noteId);
      }

      processed += 1;
    } catch {
      remaining.push({
        ...item,
        attempts: item.attempts + 1,
      });
      break;
    }
  }

  const tail = queue.slice(processed + remaining.length);
  await writeQueue([...remaining, ...tail]);

  return {
    processed,
    remaining: remaining.length + tail.length,
  };
}
