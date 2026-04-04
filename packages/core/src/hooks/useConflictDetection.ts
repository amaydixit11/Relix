import { useEffect, useState } from 'react';
import { acorde } from '../client/acorde';

interface ConflictDetectionOptions {
  baselineUpdatedAt?: number;
  hasLocalChanges?: boolean;
  suppress?: boolean;
}

export function useConflictDetection(
  entryId: string,
  options: ConflictDetectionOptions = {}
) {
  const [hasConflict, setHasConflict] = useState(false);
  const [remoteChangeCount, setRemoteChangeCount] = useState(0);
  const [latestRemoteUpdatedAt, setLatestRemoteUpdatedAt] = useState<number | null>(null);

  useEffect(() => {
    if (!entryId) return;

    const sub = acorde.subscribeToEvents((event) => {
      if (event.entry_id === entryId && (event.type === 'updated' || event.type === 'synced')) {
        if (options.suppress) return;

        void acorde.getEntry(entryId).then((latest) => {
          const baseline = options.baselineUpdatedAt ?? 0;
          setLatestRemoteUpdatedAt(latest.updated_at);

          if ((options.hasLocalChanges ?? false) && latest.updated_at > baseline) {
            setHasConflict(true);
            setRemoteChangeCount((prev) => prev + 1);
          }
        }).catch(() => {
          // Ignore transient fetch failures while offline.
        });
      }
    });

    return () => sub.close();
  }, [entryId, options.baselineUpdatedAt, options.hasLocalChanges, options.suppress]);

  useEffect(() => {
    if (!options.hasLocalChanges) {
      setHasConflict(false);
    }
  }, [options.hasLocalChanges]);

  return { 
    hasConflict, 
    remoteChangeCount,
    latestRemoteUpdatedAt,
    resetConflict: () => {
      setHasConflict(false);
      setRemoteChangeCount(0);
    },
  };
}
