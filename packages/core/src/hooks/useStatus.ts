"use client";

import { useQuery } from '@tanstack/react-query';
import { acorde } from '../client';
import type { VaultInfo, SyncStatus } from '../models';

export const statusKeys = {
  all: ['status'] as const,
  health: () => [...statusKeys.all, 'health'] as const,
  info: () => [...statusKeys.all, 'info'] as const,
};

export function useVaultStatus() {
  return useQuery<VaultInfo & SyncStatus>({
    queryKey: statusKeys.info(),
    queryFn: () => acorde.getStatus(),
    refetchInterval: 5000, // Refresh every 5s
  });
}

export function useHealthCheck() {
  return useQuery({
    queryKey: statusKeys.health(),
    queryFn: () => acorde.healthCheck(),
    refetchInterval: 3000,
    retry: false,
  });
}
