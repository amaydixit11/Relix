import type { Metadata } from 'next';
import { Providers } from './providers';
import { Sidebar } from '@/components';
import './globals.css';

export const metadata: Metadata = {
  title: 'Relix',
  description: 'Privacy-first personal knowledge management',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>
        <Providers>
          <Sidebar>{children}</Sidebar>
        </Providers>
      </body>
    </html>
  );
}
