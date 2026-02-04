'use client';

import { useEffect, useCallback } from 'react';
import { useRouter } from 'next/navigation';

interface KeyboardShortcut {
  key: string;
  mod?: boolean;  // Ctrl/Cmd
  shift?: boolean;
  callback: () => void;
}

export function useKeyboardShortcuts(shortcuts: KeyboardShortcut[]) {
  const handleKeyDown = useCallback((e: KeyboardEvent) => {
    // Ignore if typing in input/textarea
    if (
      e.target instanceof HTMLInputElement ||
      e.target instanceof HTMLTextAreaElement
    ) {
      // Allow Escape to still work
      if (e.key !== 'Escape') return;
    }

    const mod = e.metaKey || e.ctrlKey;

    for (const shortcut of shortcuts) {
      if (
        e.key.toLowerCase() === shortcut.key.toLowerCase() &&
        (!shortcut.mod || mod) &&
        (!shortcut.shift || e.shiftKey)
      ) {
        e.preventDefault();
        shortcut.callback();
        return;
      }
    }
  }, [shortcuts]);

  useEffect(() => {
    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [handleKeyDown]);
}

/**
 * Hook that provides standard Relix keyboard shortcuts
 */
export function useRelixShortcuts({
  onCommandPalette,
}: {
  onCommandPalette: () => void;
}) {
  const router = useRouter();

  useKeyboardShortcuts([
    { key: 'k', mod: true, callback: onCommandPalette },
    { key: 'n', mod: true, callback: () => router.push('/notes/new') },
    { key: 'g', mod: true, callback: () => router.push('/graph') },
    { key: ',', mod: true, callback: () => router.push('/settings') },
    { key: '/', callback: onCommandPalette },
  ]);
}
