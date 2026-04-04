import { useEffect, useState } from 'react';
import { acorde } from '../client/acorde';

export function useConflictDetection(entryId: string) {
  const [hasConflict, setHasConflict] = useState(false);
  const [remoteChangeCount, setRemoteChangeCount] = useState(0);

  useEffect(() => {
    if (!entryId) return;

    const sub = acorde.subscribeToEvents((event) => {
      if (event.entry_id === entryId && (event.type === 'updated' || event.type === 'synced')) {
        // Simple heuristic: if we see an update/sync event for this entry, 
        // someone else (or a sync) modified it.
        setHasConflict(true);
        setRemoteChangeCount(prev => prev + 1);
      }
    });

    return () => sub.close();
  }, [entryId]);

  return { 
    hasConflict, 
    remoteChangeCount,
    resetConflict: () => setHasConflict(false) 
  };
}
