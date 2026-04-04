'use client';

import { useState, useEffect } from 'react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ReactNode } from 'react';
import { CommandPalette, QuickCapture } from '@/components';
import { useRelixShortcuts, useKeyboardShortcuts } from '@/hooks';
import { pluginManager, aiPlugin } from '@relix/plugins';

import { UIProvider, useUI } from '@/context/UIContext';

// Initialize plugins
if (typeof window !== 'undefined') {
  pluginManager.register(aiPlugin);
  pluginManager.enable(aiPlugin.id).catch(console.error);
}

function GlobalShortcuts({ 
  children, 
}: { 
  children: ReactNode; 
}) {
  const { setCommandPaletteOpen, setQuickCaptureOpen } = useUI();
  
  useRelixShortcuts({ onCommandPalette: () => setCommandPaletteOpen(true) });
  
  // Quick capture shortcut: Ctrl/Cmd + Shift + N
  useKeyboardShortcuts([
    { key: 'n', mod: true, shift: true, callback: () => setQuickCaptureOpen(true) },
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

  // Re-register plugins on mount to ensure client-side execution
  useEffect(() => {
    pluginManager.register(aiPlugin);
    pluginManager.enable(aiPlugin.id).catch(console.error);
  }, []);

  return (
    <QueryClientProvider client={queryClient}>
      <UIProvider>
        <GlobalShortcuts>
          {children}
          <CommandPaletteWrapper />
          <QuickCaptureWrapper />
        </GlobalShortcuts>
      </UIProvider>
    </QueryClientProvider>
  );
}

function CommandPaletteWrapper() {
  const { commandPaletteOpen, setCommandPaletteOpen } = useUI();
  return (
    <CommandPalette 
      isOpen={commandPaletteOpen} 
      onClose={() => setCommandPaletteOpen(false)} 
    />
  );
}

function QuickCaptureWrapper() {
  const { quickCaptureOpen, setQuickCaptureOpen } = useUI();
  return (
    <QuickCapture
      isOpen={quickCaptureOpen}
      onClose={() => setQuickCaptureOpen(false)}
    />
  );
}
