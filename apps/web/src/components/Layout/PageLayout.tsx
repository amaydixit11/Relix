'use client';

import { ReactNode } from 'react';
import { useConnectionState } from '@relix/core';

interface PageLayoutProps {
  children: ReactNode;
  noPadding?: boolean;
}

export function PageLayout({ children, noPadding = false }: PageLayoutProps) {
  const connection = useConnectionState();

  return (
    <div className="animate-in" style={{
      height: '100%',
      display: 'flex',
      flexDirection: 'column',
      overflow: 'hidden',
      position: 'relative',
    }}>
      {connection.initialized && !connection.daemonReachable && (
        <div
          style={{
            position: 'absolute',
            top: 0,
            left: 0,
            right: 0,
            zIndex: 100,
            padding: '0.375rem 0.5rem',
            background: 'rgba(251, 113, 133, 0.1)',
            borderBottom: '1px solid rgba(251, 113, 133, 0.2)',
            backdropFilter: 'blur(12px)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: '0.5rem',
          }}
        >
          <div
            style={{
              width: '0.375rem',
              height: '0.375rem',
              borderRadius: '999px',
              background: 'var(--error)',
            }}
          />
          <span
            style={{
              fontSize: '0.625rem',
              fontWeight: 700,
              color: 'var(--error)',
              textTransform: 'uppercase',
              letterSpacing: '0.2em',
            }}
          >
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
