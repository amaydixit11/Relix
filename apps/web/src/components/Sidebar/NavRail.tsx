'use client';

import { useUI } from '@/context/UIContext';
import Link from 'next/link';
import { usePathname } from 'next/navigation';

export const navItems = [
  { href: '/', icon: '🏠', label: 'Home' },
  { href: '/notes', icon: '📝', label: 'Notes' },
  { href: '/graph', icon: '🕸️', label: 'Graph' },
  { href: '/files', icon: '📁', label: 'Files' },
  { href: '/settings', icon: '⚙️', label: 'Settings' },
];

export function NavRail() {
  const pathname = usePathname();
  const { setCommandPaletteOpen, setQuickCaptureOpen } = useUI();

  return (
    <nav className="glass-panel" style={{
      width: '64px',
      borderRight: '1px solid var(--border)',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      padding: '20px 0',
      gap: '12px',
      flexShrink: 0,
      zIndex: 50,
      background: 'rgba(10, 10, 15, 0.4)', // Slightly darker glass
    }}>
      {/* Animated Logo */}
      <Link href="/" style={{
        width: '40px',
        height: '40px',
        background: 'linear-gradient(135deg, var(--accent), var(--accent-cyan))',
        borderRadius: '10px',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        marginBottom: '24px',
        fontWeight: '800',
        fontSize: '18px',
        color: '#fff',
        boxShadow: '0 0 20px rgba(124, 58, 237, 0.4)',
        textDecoration: 'none',
      }}>
        R
      </Link>

      {/* Nav Items */}
      {navItems.map(item => {
        const isActive = pathname === item.href || 
          (item.href !== '/' && pathname.startsWith(item.href));
        
        return (
          <Link
            key={item.href}
            href={item.href as any}
            title={item.label}
            className={isActive ? 'nav-item-active' : ''}
            style={{
              width: '42px',
              height: '42px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              borderRadius: '10px',
              color: 'var(--text-secondary)',
              transition: 'all 0.3s cubic-bezier(0.2, 0.8, 0.2, 1)',
              fontSize: '20px',
              position: 'relative',
            }}
          >
            <span style={{ 
              transform: isActive ? 'scale(1.1)' : 'scale(1)',
              transition: 'transform 0.2s',
              textShadow: isActive ? '0 0 10px rgba(124, 58, 237, 0.5)' : 'none'
            }}>
              {item.icon}
            </span>
          </Link>
        );
      })}

      {/* Spacer */}
      <div style={{ flex: 1 }} />

      {/* Quick Capture Trigger */}
      <button
        title="Quick Capture (⌘⇧N)"
        onClick={() => setQuickCaptureOpen(true)}
        style={{
          width: '42px',
          height: '42px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          borderRadius: '10px',
          background: 'rgba(139, 92, 246, 0.1)',
          fontSize: '18px',
          border: '1px solid var(--accent)',
          color: 'var(--accent)',
          padding: 0,
          marginBottom: '10px',
        }}
      >
        +
      </button>

      {/* Command Palette Trigger */}
      <button
        title="Command Palette (⌘K)"
        onClick={() => setCommandPaletteOpen(true)}
        style={{
          width: '42px',
          height: '42px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          borderRadius: '10px',
          background: 'rgba(255,255,255,0.05)',
          fontSize: '12px',
          border: '1px solid var(--border)',
          color: 'var(--text-muted)',
          padding: 0,
          marginBottom: '10px',
        }}
      >
        ⌘K
      </button>
    </nav>
  );
}
