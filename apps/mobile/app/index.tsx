import { View, Text, FlatList, TouchableOpacity, StyleSheet, RefreshControl } from 'react-native';
import { Link, Stack } from 'expo-router';
import { useQuery } from '@tanstack/react-query';
import { noteService, p2pService, useConnectionState } from '@relix/core';
import { useState, useEffect } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { drainMutationQueue, getQueueCount, getCachedNotes, mergeRemoteNotes, type CachedNote } from '../src/offline';

const URL_KEY = '@relix/server_url';

async function fetchNotes() {
  // Ensure we have last known URL configured
  const url = await AsyncStorage.getItem(URL_KEY);
  if (url) p2pService.setBaseUrl(url);

  try {
    await drainMutationQueue();
    const notes = await noteService.list();
    return mergeRemoteNotes(notes);
  } catch (err) {
    const cache = await getCachedNotes();
    if (cache.length > 0) return cache;
    throw err;
  }
}

export default function HomeScreen() {
  const connection = useConnectionState();
  const { data: notes = [], isLoading, isError, refetch } = useQuery<CachedNote[]>({
    queryKey: ['notes'],
    queryFn: fetchNotes,
    staleTime: 1000 * 60 * 5, // 5 minutes
  });

  const [isRefreshing, setIsRefreshing] = useState(false);
  const [queueCount, setQueueCount] = useState(0);

  useEffect(() => {
    const loadQueueCount = async () => {
      setQueueCount(await getQueueCount());
    };

    void loadQueueCount();
  }, [notes]);

  const onRefresh = async () => {
    setIsRefreshing(true);
    await refetch();
    setQueueCount(await getQueueCount());
    setIsRefreshing(false);
  };

  return (
    <View style={styles.container}>
      <Stack.Screen options={{ title: 'Relix' }} />
      
      {/* Sync Status Bar */}
      <View style={[styles.statusBar, connection.daemonReachable && !isError ? styles.statusOnline : styles.statusOffline]}>
        <Text style={styles.statusText}>
          {connection.daemonReachable && !isError
            ? `● ${connection.peers.filter((peer) => peer.is_connected).length > 0 ? 'Connected to Peer' : 'Daemon Online'}`
            : '● Offline / Working from cache'}
          {queueCount > 0 ? ` • ${queueCount} pending sync` : ''}
        </Text>
      </View>

      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.title}>Your Vault</Text>
        <Text style={styles.subtitle}>
          {isLoading ? 'Syncing...' : `${notes.length} notes`}
        </Text>
      </View>

      {/* Notes List */}
      <FlatList
        data={notes}
        keyExtractor={(item: any) => item.id}
        contentContainerStyle={styles.list}
        refreshControl={
          <RefreshControl refreshing={isRefreshing} onRefresh={onRefresh} tintColor="#6366f1" />
        }
        renderItem={({ item }: { item: CachedNote }) => (
          <Link href={`/note/${item.id}`} asChild>
            <TouchableOpacity style={styles.card}>
              <View style={styles.cardHeader}>
                <Text style={styles.cardTitle}>{item.content?.title || 'Untitled'}</Text>
                <View style={styles.cardMeta}>
                  {item.pending_sync ? (
                    <Text style={styles.pendingBadge}>Pending</Text>
                  ) : null}
                  <Text style={styles.cardDate}>
                    {new Date(item.updated_at * 1000).toLocaleDateString()}
                  </Text>
                </View>
              </View>
              <Text style={styles.cardBody} numberOfLines={2}>
                {item.content?.body || ''}
              </Text>
              <View style={styles.tagRow}>
                {(item.tags || [])
                  .filter((t: string) => !t.includes(':'))
                  .slice(0, 3)
                  .map((t: string) => (
                    <Text key={t} style={styles.tag}>#{t}</Text>
                  ))}
              </View>
            </TouchableOpacity>
          </Link>
        )}
        ListEmptyComponent={
          <View style={styles.center}>
            <Text style={styles.muted}>
              {isLoading ? 'Checking for notes...' : 'No notes found'}
            </Text>
          </View>
        }
      />

      {/* Action Button */}
      <Link href="/note/create" asChild>
        <TouchableOpacity style={styles.fab}>
          <Text style={styles.fabText}>+</Text>
        </TouchableOpacity>
      </Link>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0a0a0a',
  },
  statusBar: {
    paddingVertical: 4,
    paddingHorizontal: 12,
    alignItems: 'center',
  },
  statusOnline: {
    backgroundColor: 'rgba(34, 197, 94, 0.1)',
  },
  statusOffline: {
    backgroundColor: 'rgba(239, 68, 68, 0.1)',
  },
  statusText: {
    fontSize: 11,
    color: '#a3a3a3',
    fontWeight: '500',
  },
  header: {
    padding: 20,
    paddingTop: 10,
  },
  title: {
    fontSize: 32,
    fontWeight: 'bold',
    color: '#fafafa',
  },
  subtitle: {
    fontSize: 15,
    color: '#666',
    marginTop: 4,
  },
  list: {
    padding: 16,
    paddingBottom: 100,
    gap: 12,
  },
  card: {
    backgroundColor: '#141414',
    padding: 16,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: '#262626',
  },
  cardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  cardMeta: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginLeft: 8,
  },
  cardTitle: {
    fontSize: 17,
    fontWeight: '600',
    color: '#fafafa',
    flex: 1,
  },
  pendingBadge: {
    fontSize: 11,
    color: '#f59e0b',
    backgroundColor: 'rgba(245, 158, 11, 0.12)',
    paddingVertical: 2,
    paddingHorizontal: 6,
    borderRadius: 999,
    overflow: 'hidden',
  },
  cardDate: {
    fontSize: 12,
    color: '#666',
  },
  cardBody: {
    fontSize: 14,
    color: '#a3a3a3',
    lineHeight: 20,
  },
  tagRow: {
    flexDirection: 'row',
    gap: 8,
    marginTop: 12,
  },
  tag: {
    fontSize: 12,
    color: '#6366f1',
    backgroundColor: 'rgba(99, 102, 241, 0.1)',
    paddingVertical: 2,
    paddingHorizontal: 8,
    borderRadius: 4,
  },
  center: {
    marginTop: 60,
    alignItems: 'center',
  },
  muted: {
    color: '#666',
    fontSize: 16,
  },
  fab: {
    position: 'absolute',
    bottom: 24,
    right: 24,
    width: 64,
    height: 64,
    borderRadius: 32,
    backgroundColor: '#6366f1',
    justifyContent: 'center',
    alignItems: 'center',
    elevation: 8,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 6,
  },
  fabText: {
    color: '#fff',
    fontSize: 32,
    fontWeight: '300',
  },
});
