'use client';

import { useState } from 'react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ReactNode } from 'react';
import { CommandPalette, QuickCapture } from '@/components';
import { useRelixShortcuts, useKeyboardShortcuts } from '@/hooks';

function GlobalShortcuts({ 
  children, 
  onCommandPalette,
  onQuickCapture,
}: { 
  children: ReactNode; 
  onCommandPalette: () => void;
  onQuickCapture: () => void;
}) {
  useRelixShortcuts({ onCommandPalette });
  
  // Quick capture shortcut: Ctrl/Cmd + Shift + N
  useKeyboardShortcuts([
    { key: 'n', mod: true, shift: true, callback: onQuickCapture },
  ]);
  
  return <>{children}</>;
}

export function Providers({ children }: { children: ReactNode }) {
  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            staleTime: 1000 * 60,
            refetchOnWindowFocus: false,
          },
        },
      })
  );

  const [commandPaletteOpen, setCommandPaletteOpen] = useState(false);
  const [quickCaptureOpen, setQuickCaptureOpen] = useState(false);

  return (
    <QueryClientProvider client={queryClient}>
      <GlobalShortcuts 
        onCommandPalette={() => setCommandPaletteOpen(true)}
        onQuickCapture={() => setQuickCaptureOpen(true)}
      >
        {children}
        <CommandPalette 
          isOpen={commandPaletteOpen} 
          onClose={() => setCommandPaletteOpen(false)} 
        />
        <QuickCapture
          isOpen={quickCaptureOpen}
          onClose={() => setQuickCaptureOpen(false)}
        />
      </GlobalShortcuts>
    </QueryClientProvider>
  );
}
