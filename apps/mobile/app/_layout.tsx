import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useEffect, useState } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { ConnectionProvider, configureRuntimeStorage, connectionService } from '@relix/core';
import { OfflineSyncProvider } from '../src/offline';

export default function RootLayout() {
  const [queryClient] = useState(() => new QueryClient());

  useEffect(() => {
    configureRuntimeStorage({
      getItem: AsyncStorage.getItem.bind(AsyncStorage),
      setItem: async (key, value) => {
        await AsyncStorage.setItem(key, value);
      },
      removeItem: AsyncStorage.removeItem.bind(AsyncStorage),
    });

    void AsyncStorage.getItem('@relix/server_url').then((url) => {
      if (url) {
        connectionService.setBaseUrl(url);
      }
    });
  }, []);

  return (
    <QueryClientProvider client={queryClient}>
      <ConnectionProvider>
        <OfflineSyncProvider>
          <StatusBar style="light" />
          <Stack
            screenOptions={{
              headerStyle: {
                backgroundColor: '#0a0a0a',
              },
              headerTintColor: '#fafafa',
              headerTitleStyle: {
                fontWeight: 'bold',
              },
              contentStyle: {
                backgroundColor: '#0a0a0a',
              },
            }}
          />
        </OfflineSyncProvider>
      </ConnectionProvider>
    </QueryClientProvider>
  );
}
