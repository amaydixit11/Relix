import { View, Text, FlatList, TouchableOpacity, StyleSheet } from 'react-native';
import { Link, Stack } from 'expo-router';
import { useQuery } from '@tanstack/react-query';

// Simplified API for mobile (would connect to desktop via LAN)
const ACORDE_URL = 'http://localhost:7331';

async function fetchNotes() {
  try {
    const res = await fetch(`${ACORDE_URL}/entries?type=note`);
    if (!res.ok) throw new Error('Failed to fetch');
    return res.json();
  } catch {
    return [];
  }
}

export default function HomeScreen() {
  const { data: notes = [], isLoading, error } = useQuery({
    queryKey: ['notes'],
    queryFn: fetchNotes,
  });

  return (
    <View style={styles.container}>
      <Stack.Screen options={{ title: 'Relix' }} />
      
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.title}>Your Notes</Text>
        <Text style={styles.subtitle}>
          {isLoading ? 'Loading...' : `${notes.length} notes`}
        </Text>
      </View>

      {/* Notes List */}
      {error ? (
        <View style={styles.center}>
          <Text style={styles.muted}>
            Connect to desktop to sync notes
          </Text>
        </View>
      ) : (
        <FlatList
          data={notes}
          keyExtractor={(item: any) => item.ID}
          contentContainerStyle={styles.list}
          renderItem={({ item }: { item: any }) => {
            let content = { title: 'Untitled', body: '' };
            try {
              content = JSON.parse(atob(item.Content));
            } catch {}
            
            return (
              <Link href={`/note/${item.ID}`} asChild>
                <TouchableOpacity style={styles.card}>
                  <Text style={styles.cardTitle}>{content.title}</Text>
                  <Text style={styles.cardBody} numberOfLines={2}>
                    {content.body}
                  </Text>
                </TouchableOpacity>
              </Link>
            );
          }}
          ListEmptyComponent={
            <View style={styles.center}>
              <Text style={styles.muted}>No notes yet</Text>
            </View>
          }
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0a0a0a',
  },
  header: {
    padding: 20,
    paddingTop: 10,
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#fafafa',
  },
  subtitle: {
    fontSize: 14,
    color: '#666',
    marginTop: 4,
  },
  list: {
    padding: 16,
    gap: 12,
  },
  card: {
    backgroundColor: '#141414',
    padding: 16,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#262626',
  },
  cardTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#fafafa',
  },
  cardBody: {
    fontSize: 14,
    color: '#a3a3a3',
    marginTop: 8,
  },
  center: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 40,
  },
  muted: {
    color: '#666',
    textAlign: 'center',
  },
});
