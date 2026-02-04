import {
  useQuery,
  useMutation,
  useQueryClient,
  type UseQueryOptions,
  type UseMutationOptions,
} from '@tanstack/react-query';
import { noteService } from '../services';
import type { Note, NoteContent, NoteFilter } from '../models';

// Query Keys
export const noteKeys = {
  all: ['notes'] as const,
  lists: () => [...noteKeys.all, 'list'] as const,
  list: (filter?: NoteFilter) => [...noteKeys.lists(), filter] as const,
  details: () => [...noteKeys.all, 'detail'] as const,
  detail: (id: string) => [...noteKeys.details(), id] as const,
  backlinks: (id: string) => [...noteKeys.all, 'backlinks', id] as const,
  search: (query: string) => [...noteKeys.all, 'search', query] as const,
};

// ─────────────────────────────────────────────────────────────
// Queries
// ─────────────────────────────────────────────────────────────

export function useNotes(
  filter?: NoteFilter,
  options?: Omit<UseQueryOptions<Note[]>, 'queryKey' | 'queryFn'>
) {
  return useQuery({
    queryKey: noteKeys.list(filter),
    queryFn: () => noteService.list(filter),
    ...options,
  });
}

export function useNote(
  id: string,
  options?: Omit<UseQueryOptions<Note>, 'queryKey' | 'queryFn'>
) {
  return useQuery({
    queryKey: noteKeys.detail(id),
    queryFn: () => noteService.get(id),
    enabled: !!id,
    ...options,
  });
}

export function useBacklinks(
  id: string,
  options?: Omit<UseQueryOptions<Note[]>, 'queryKey' | 'queryFn'>
) {
  return useQuery({
    queryKey: noteKeys.backlinks(id),
    queryFn: () => noteService.getBacklinks(id),
    enabled: !!id,
    ...options,
  });
}

export function useNoteSearch(
  query: string,
  options?: Omit<UseQueryOptions<Note[]>, 'queryKey' | 'queryFn'>
) {
  return useQuery({
    queryKey: noteKeys.search(query),
    queryFn: () => noteService.search(query),
    enabled: query.length >= 2,
    ...options,
  });
}

// ─────────────────────────────────────────────────────────────
// Mutations
// ─────────────────────────────────────────────────────────────

export function useCreateNote(
  options?: UseMutationOptions<Note, Error, { title: string; body: string; tags?: string[] }>
) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ title, body, tags }) => noteService.create(title, body, tags),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: noteKeys.lists() });
    },
    ...options,
  });
}

export function useUpdateNote(
  options?: UseMutationOptions<
    Note,
    Error,
    { id: string; patch: Partial<Pick<NoteContent, 'title' | 'body'>>; tags?: string[] }
  >
) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ id, patch, tags }) => noteService.update(id, patch, tags),
    onSuccess: (note) => {
      queryClient.invalidateQueries({ queryKey: noteKeys.lists() });
      queryClient.setQueryData(noteKeys.detail(note.id), note);
    },
    ...options,
  });
}

export function useDeleteNote(
  options?: UseMutationOptions<void, Error, string>
) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id) => noteService.delete(id),
    onSuccess: (_, id) => {
      queryClient.invalidateQueries({ queryKey: noteKeys.lists() });
      queryClient.removeQueries({ queryKey: noteKeys.detail(id) });
    },
    ...options,
  });
}
