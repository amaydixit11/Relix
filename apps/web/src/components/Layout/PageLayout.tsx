'use client';

import { ReactNode } from 'react';

interface PageLayoutProps {
  children: ReactNode;
  noPadding?: boolean;
}

import { useHealthCheck } from '@relix/core';

export function PageLayout({ children, noPadding = false }: PageLayoutProps) {
  const { data: isHealthy } = useHealthCheck();

  return (
    <div className="animate-in" style={{ 
      height: '100%', 
      display: 'flex', 
      flexDirection: 'column',
      overflow: 'hidden',
      position: 'relative'
    }}>
      {!isHealthy && isHealthy !== undefined && (
        <div className="absolute top-0 left-0 right-0 z-[100] p-1.5 bg-rose-500/10 border-b border-rose-500/20 backdrop-blur-md flex items-center justify-center gap-2">
          <div className="w-1.5 h-1.5 rounded-full bg-rose-500 animate-pulse" />
          <span className="text-[10px] font-bold text-rose-500 uppercase tracking-widest">
            Offline: Garden Daemon Unreachable
          </span>
        </div>
      )}
      <div style={{ 
        flex: 1, 
        overflowY: 'auto', 
        padding: noPadding ? 0 : '2.5rem',
        maxWidth: noPadding ? 'none' : '1100px',
        margin: noPadding ? 0 : '0 auto',
        width: '100%',
      }}>
        {children}
      </div>
    </div>
  );
}
