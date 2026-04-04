'use client';

import { ReactNode } from 'react';

interface PageLayoutProps {
  children: ReactNode;
  noPadding?: boolean;
}

export function PageLayout({ children, noPadding = false }: PageLayoutProps) {
  return (
    <div className="animate-in" style={{ 
      height: '100%', 
      display: 'flex', 
      flexDirection: 'column',
      overflow: 'hidden',
    }}>
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
