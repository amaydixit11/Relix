'use client';

import { createContext, useContext, useState, ReactNode } from 'react';

interface UIContextType {
  commandPaletteOpen: boolean;
  setCommandPaletteOpen: (open: boolean) => void;
  quickCaptureOpen: boolean;
  setQuickCaptureOpen: (open: boolean) => void;
  fileTreeOpen: boolean;
  setFileTreeOpen: (open: boolean) => void;
}

const UIContext = createContext<UIContextType | undefined>(undefined);

export function UIProvider({ children }: { children: ReactNode }) {
  const [commandPaletteOpen, setCommandPaletteOpen] = useState(false);
  const [quickCaptureOpen, setQuickCaptureOpen] = useState(false);
  const [fileTreeOpen, setFileTreeOpen] = useState(true);

  return (
    <UIContext.Provider value={{
      commandPaletteOpen,
      setCommandPaletteOpen,
      quickCaptureOpen,
      setQuickCaptureOpen,
      fileTreeOpen,
      setFileTreeOpen,
    }}>
      {children}
    </UIContext.Provider>
  );
}

export function useUI() {
  const context = useContext(UIContext);
  if (context === undefined) {
    throw new Error('useUI must be used within a UIProvider');
  }
  return context;
}
