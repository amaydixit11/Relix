import { View, Text, ScrollView, StyleSheet } from 'react-native';
import { Stack, useLocalSearchParams } from 'expo-router';
import { useQuery } from '@tanstack/react-query';

const ACORDE_URL = 'http://localhost:7331';

async function fetchNote(id: string) {
  const res = await fetch(`${ACORDE_URL}/entries/${id}`);
  if (!res.ok) throw new Error('Note not found');
  return res.json();
}

export default function NoteScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();

  const { data: note, isLoading, error } = useQuery({
    queryKey: ['note', id],
    queryFn: () => fetchNote(id),
    enabled: !!id,
  });

  let content = { title: 'Loading...', body: '' };
  if (note) {
    try {
      content = JSON.parse(atob(note.Content));
    } catch {}
  }

  return (
    <View style={styles.container}>
      <Stack.Screen 
        options={{ 
          title: content.title,
          headerBackTitle: 'Back',
        }} 
      />
      
      {isLoading ? (
        <View style={styles.center}>
          <Text style={styles.muted}>Loading...</Text>
        </View>
      ) : error ? (
        <View style={styles.center}>
          <Text style={styles.error}>Note not found</Text>
        </View>
      ) : (
        <ScrollView contentContainerStyle={styles.content}>
          <Text style={styles.title}>{content.title}</Text>
          
          {/* Tags */}
          {note?.Tags && note.Tags.length > 0 && (
            <View style={styles.tags}>
              {note.Tags
                .filter((t: string) => !t.startsWith('backlink:') && !t.startsWith('outlink:'))
                .map((tag: string) => (
                  <View key={tag} style={styles.tag}>
                    <Text style={styles.tagText}>#{tag}</Text>
                  </View>
                ))}
            </View>
          )}
          
          {/* Body */}
          <Text style={styles.body}>{content.body}</Text>
        </ScrollView>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0a0a0a',
  },
  content: {
    padding: 20,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#fafafa',
    marginBottom: 12,
  },
  tags: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    marginBottom: 16,
  },
  tag: {
    backgroundColor: '#6366f1',
    paddingHorizontal: 12,
    paddingVertical: 4,
    borderRadius: 6,
  },
  tagText: {
    color: '#fff',
    fontSize: 12,
  },
  body: {
    fontSize: 16,
    lineHeight: 24,
    color: '#a3a3a3',
  },
  center: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  muted: {
    color: '#666',
  },
  error: {
    color: '#ef4444',
  },
});
