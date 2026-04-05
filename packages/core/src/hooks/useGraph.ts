"use client";

import { useQuery } from '@tanstack/react-query';
import { graphService } from '../services';
import type { Graph, GraphNode } from '../models';

export const graphKeys = {
  all: ['graph'] as const,
  full: () => [...graphKeys.all, 'full'] as const,
  neighbors: (id: string, depth: number) => [...graphKeys.all, 'neighbors', id, depth] as const,
  related: (id: string) => [...graphKeys.all, 'related', id] as const,
};

export function useGraph() {
  return useQuery({
    queryKey: graphKeys.full(),
    queryFn: () => graphService.getFullGraph(),
  });
}

export function useNeighbors(id: string, depth = 1) {
  return useQuery({
    queryKey: graphKeys.neighbors(id, depth),
    queryFn: () => graphService.getNeighbors(id, depth),
    enabled: !!id,
  });
}

export function useRelatedNotes(id: string, limit = 10) {
  return useQuery<GraphNode[]>({
    queryKey: graphKeys.related(id),
    queryFn: () => graphService.getRelatedByTags(id, limit),
    enabled: !!id,
  });
}
