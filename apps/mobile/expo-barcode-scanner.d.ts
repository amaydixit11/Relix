declare module 'expo-barcode-scanner' {
  import type { ComponentType } from 'react';

  export const BarCodeScanner: ComponentType<{
    onBarCodeScanned?: (event: { data: string; type?: string }) => void;
    style?: unknown;
  }> & {
    requestPermissionsAsync: () => Promise<{ status: 'granted' | 'denied' | 'undetermined' }>;
  };
}
