import { ReactNode } from 'react';
import { NavRail } from '../Sidebar/NavRail';
import { FileTree } from '../FileTree/FileTree';
import { useConnectionState } from '@relix/core';

interface DesktopLayoutProps {
  children: ReactNode;
}

export function DesktopLayout({ children }: DesktopLayoutProps) {
  const connection = useConnectionState();

  return (
    <div style={{ display: 'flex', height: '100vh', width: '100vw', overflow: 'hidden', background: '#0a0a0a' }}>
      {/* 1. Navigation Rail (Home, Graph, Settings) */}
      <NavRail />

      {/* 2. File Explorer (Obsidian-style) */}
      <FileTree />

      {/* 3. Main Content (Editor/Viewer) */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', height: '100%', overflow: 'hidden' }}>
        
        {/* Tab Bar / Breadcrumbs area */}
        <div style={{ 
          height: '40px', 
          borderBottom: '1px solid var(--border)', 
          display: 'flex', 
          alignItems: 'center', 
          padding: '0 20px',
          fontSize: '0.9rem',
          color: 'var(--text-secondary)',
          background: 'var(--bg-primary)'
        }}>
          Workplace / Notes
        </div>

        {/* Content */}
        <div style={{ flex: 1, overflow: 'auto', position: 'relative' }}>
          {children}
        </div>

        {/* Status Bar */}
        <div style={{ 
          height: '25px', 
          borderTop: '1px solid var(--border)', 
          fontSize: '0.75rem', 
          display: 'flex', 
          alignItems: 'center', 
          padding: '0 10px',
          justifyContent: 'space-between',
          color: 'var(--text-muted)',
          background: 'var(--bg-secondary)'
        }}>
          <span>
            Sync:{' '}
            {connection.daemonReachable
              ? connection.pendingChanges > 0
                ? `${connection.pendingChanges} pending`
                : connection.connectionType === 'relay'
                  ? 'Relay'
                  : 'Online'
              : 'Offline'}
          </span>
          <span>{connection.peers.filter((peer) => peer.is_connected).length} peers</span>
        </div>
      </div>
    </div>
  );
}
