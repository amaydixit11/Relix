import { useEffect, type ReactNode } from 'react';
import { AppState } from 'react-native';
import { useQueryClient } from '@tanstack/react-query';
import { drainMutationQueue } from './mutationQueue';

const DRAIN_INTERVAL_MS = 15000;

export function OfflineSyncProvider({ children }: { children: ReactNode }) {
  const queryClient = useQueryClient();

  useEffect(() => {
    let running = false;

    const tryDrain = async () => {
      if (running) return;
      running = true;

      try {
        const result = await drainMutationQueue();
        if (result.processed > 0) {
          await queryClient.invalidateQueries({ queryKey: ['notes'] });
          await queryClient.invalidateQueries({ queryKey: ['note'] });
        }
      } finally {
        running = false;
      }
    };

    tryDrain();

    const interval = setInterval(() => {
      void tryDrain();
    }, DRAIN_INTERVAL_MS);

    const subscription = AppState.addEventListener('change', (state) => {
      if (state === 'active') {
        void tryDrain();
      }
    });

    return () => {
      clearInterval(interval);
      subscription.remove();
    };
  }, [queryClient]);

  return <>{children}</>;
}
