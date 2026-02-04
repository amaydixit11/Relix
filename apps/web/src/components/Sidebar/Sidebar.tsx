'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { ReactNode } from 'react';

interface SidebarProps {
  children: ReactNode;
}

const navItems = [
  { href: '/', icon: '🏠', label: 'Home' },
  { href: '/notes', icon: '📝', label: 'Notes' },
  { href: '/graph', icon: '🕸️', label: 'Graph' },
  { href: '/files', icon: '📁', label: 'Files' },
  { href: '/settings', icon: '⚙️', label: 'Settings' },
];

export function Sidebar({ children }: SidebarProps) {
  const pathname = usePathname();

  return (
    <div style={{ display: 'flex', height: '100vh', width: '100vw', overflow: 'hidden' }}>
      {/* Sidebar Rail */}
      <nav style={{
        width: '50px',
        background: 'var(--bg-secondary)',
        borderRight: '1px solid var(--border)',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        padding: '12px 0',
        gap: '4px',
        flexShrink: 0,
        zIndex: 50,
      }}>
        {/* Logo */}
        <div style={{
          width: '32px',
          height: '32px',
          background: 'linear-gradient(135deg, var(--accent), #a855f7)',
          borderRadius: '8px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          marginBottom: '12px',
          fontWeight: 'bold',
          fontSize: '14px',
          color: '#fff',
          boxShadow: '0 2px 5px rgba(0,0,0,0.2)',
        }}>
          R
        </div>

        {/* Nav Items */}
        {navItems.map(item => {
          const isActive = pathname === item.href || 
            (item.href !== '/' && pathname.startsWith(item.href));
          
          return (
            <Link
              key={item.href}
              href={item.href as any}
              title={item.label}
              style={{
                width: '36px',
                height: '36px',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                borderRadius: '6px',
                background: isActive ? 'var(--bg-tertiary)' : 'transparent',
                color: isActive ? 'var(--accent)' : 'var(--text-secondary)',
                transition: 'all 0.15s ease',
                fontSize: '18px',
                borderLeft: isActive ? '3px solid var(--accent)' : '3px solid transparent',
              }}
            >
              <span style={{ opacity: isActive ? 1 : 0.7 }}>{item.icon}</span>
            </Link>
          );
        })}

        {/* Spacer */}
        <div style={{ flex: 1 }} />

        {/* Help */}
        <button
          title="Command Palette (⌘K)"
          style={{
            width: '36px',
            height: '36px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            borderRadius: '6px',
            background: 'transparent',
            fontSize: '12px',
            border: 'none',
            color: 'var(--text-muted)',
            padding: 0,
          }}
        >
          ⌘K
        </button>
      </nav>

      {/* Main Content Area */}
      <main style={{ 
        flex: 1, 
        overflow: 'hidden', 
        display: 'flex', 
        flexDirection: 'column',
        background: 'var(--bg-primary)',
        position: 'relative',
      }}>
        {children}
      </main>
    </div>
  );
}

export default Sidebar;
