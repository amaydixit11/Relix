import { ReactNode } from 'react';
import { NavRail } from './NavRail';

interface SidebarProps {
  children: ReactNode;
}

export function Sidebar({ children }: SidebarProps) {
  return (
    <div style={{ display: 'flex', height: '100vh', width: '100vw', overflow: 'hidden' }}>
      <NavRail />

      {/* Main Content Area */}
      <main style={{ 
        flex: 1, 
        overflow: 'hidden', 
        display: 'flex', 
        flexDirection: 'column',
        position: 'relative',
        background: 'transparent', // Let aurora shine through
      }}>
        {children}
      </main>
    </div>
  );
}

export default Sidebar;
