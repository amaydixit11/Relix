import { View, Text, ScrollView, StyleSheet, ActivityIndicator, TextInput, TouchableOpacity, Alert, KeyboardAvoidingView, Platform } from 'react-native';
import { Stack, useLocalSearchParams, useRouter } from 'expo-router';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { noteService } from '@relix/core';
import { useState, useEffect } from 'react';
import {
  drainMutationQueue,
  getQueueCount,
  getCachedNote,
  queueDeleteNote,
  queueUpdateNote,
  resolveQueuedNoteId,
  setCachedNote,
  type CachedNote,
} from '../../src/offline';

async function fetchNote(id: string) {
  const resolvedId = await resolveQueuedNoteId(id);
  try {
    await drainMutationQueue();
    const note = await noteService.get(resolvedId);
    await setCachedNote(note);
    return note;
  } catch (err) {
    const cached = (await getCachedNote(id)) ?? (await getCachedNote(resolvedId));
    if (cached) return cached;
    throw err;
  }
}

export default function NoteScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const queryClient = useQueryClient();

  const [isEditing, setIsEditing] = useState(false);
  const [editTitle, setEditTitle] = useState('');
  const [editBody, setEditBody] = useState('');
  const [isSaving, setIsSaving] = useState(false);
  const [queueCount, setQueueCount] = useState(0);

  const { data: note, isLoading, isError, refetch } = useQuery<CachedNote>({
    queryKey: ['note', id],
    queryFn: () => fetchNote(id!),
    enabled: !!id,
    staleTime: 1000 * 60 * 10,
  });

  useEffect(() => {
    if (note) {
      setEditTitle(note.content.title);
      setEditBody(note.content.body);
    }
  }, [note]);

  useEffect(() => {
    const loadQueueCount = async () => {
      setQueueCount(await getQueueCount());
    };

    void loadQueueCount();
  }, [note]);

  const handleSave = async () => {
    if (!id) return;
    setIsSaving(true);
    try {
      await queueUpdateNote(id, { title: editTitle, body: editBody });
      await drainMutationQueue();
      setIsEditing(false);
      queryClient.invalidateQueries({ queryKey: ['note', id] });
      queryClient.invalidateQueries({ queryKey: ['notes'] });
      setQueueCount(await getQueueCount());
      await refetch();
    } catch (err: any) {
      Alert.alert('Update Failed', err.message || 'Unable to save note locally');
    }
    setIsSaving(false);
  };

  const handleDelete = async () => {
    Alert.alert(
      'Delete Note',
      'Are you sure you want to delete this note?',
      [
        { text: 'Cancel', style: 'cancel' },
        { 
          text: 'Delete', 
          style: 'destructive',
          onPress: async () => {
            if (!id) return;
            try {
              await queueDeleteNote(id);
              await drainMutationQueue();
              queryClient.invalidateQueries({ queryKey: ['notes'] });
              router.back();
            } catch (err: any) {
              Alert.alert('Delete Failed', err.message || 'Unable to queue note deletion');
            }
          }
        },
      ]
    );
  };

  if (isLoading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#6366f1" />
      </View>
    );
  }

  const content = note?.content || { title: 'Untitled', body: '' };

  if (isEditing) {
    return (
      <KeyboardAvoidingView 
        style={styles.container} 
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        keyboardVerticalOffset={100}
      >
        <Stack.Screen 
          options={{ 
            title: 'Editing...',
            headerRight: () => (
              <TouchableOpacity onPress={handleSave} disabled={isSaving}>
                <Text style={[styles.actionBtn, isSaving && { opacity: 0.5 }]}>
                  {isSaving ? '...' : 'Done'}
                </Text>
              </TouchableOpacity>
            ),
          }} 
        />
        <ScrollView contentContainerStyle={styles.editContent}>
          <TextInput
            style={styles.editTitleInput}
            value={editTitle}
            onChangeText={setEditTitle}
            placeholder="Title"
            placeholderTextColor="#666"
            autoFocus
          />
          <TextInput
            style={styles.editBodyInput}
            value={editBody}
            onChangeText={setEditBody}
            placeholder="Start writing..."
            placeholderTextColor="#444"
            multiline
            textAlignVertical="top"
          />
        </ScrollView>
      </KeyboardAvoidingView>
    );
  }

  return (
    <View style={styles.container}>
      <Stack.Screen 
        options={{ 
          title: '',
          headerRight: () => (
            <View style={styles.headerActions}>
              <TouchableOpacity onPress={handleDelete} style={styles.iconBtn}>
                <Text style={styles.deleteBtnText}>Delete</Text>
              </TouchableOpacity>
              <TouchableOpacity onPress={() => setIsEditing(true)}>
                <Text style={styles.actionBtn}>Edit</Text>
              </TouchableOpacity>
            </View>
          ),
          headerBackTitle: 'Back',
        }} 
      />
      
      <ScrollView contentContainerStyle={styles.viewContent}>
        {isError && (
          <View style={styles.offlineBanner}>
            <Text style={styles.offlineText}>Viewing offline version</Text>
          </View>
        )}

        {note?.pending_sync || queueCount > 0 ? (
          <View style={styles.pendingBanner}>
            <Text style={styles.pendingText}>
              {note?.pending_sync ? 'Changes queued for sync' : `${queueCount} queued changes pending sync`}
            </Text>
          </View>
        ) : null}

        <Text style={styles.title}>{content.title}</Text>
        
        <View style={styles.metaRow}>
          <Text style={styles.date}>
            {new Date((note?.updated_at || 0) * 1000).toLocaleDateString()}
          </Text>
          {note?.tags && note.tags.length > 0 && (
            <View style={styles.tags}>
              {note.tags
                .filter((t: string) => !t.includes(':'))
                .map((tag: string) => (
                  <Text key={tag} style={styles.tagText}>#{tag}</Text>
                ))}
            </View>
          )}
        </View>
        
        <Text style={styles.body}>{content.body}</Text>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0a0a0a',
  },
  viewContent: {
    padding: 24,
  },
  editContent: {
    padding: 20,
    flexGrow: 1,
  },
  headerActions: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 16,
    marginRight: 16,
  },
  offlineBanner: {
    backgroundColor: 'rgba(239, 68, 68, 0.1)',
    padding: 8,
    borderRadius: 8,
    marginBottom: 20,
    alignItems: 'center',
  },
  offlineText: {
    color: '#ef4444',
    fontSize: 12,
    fontWeight: '600',
  },
  pendingBanner: {
    backgroundColor: 'rgba(245, 158, 11, 0.1)',
    padding: 8,
    borderRadius: 8,
    marginBottom: 16,
    alignItems: 'center',
  },
  pendingText: {
    color: '#f59e0b',
    fontSize: 12,
    fontWeight: '600',
  },
  title: {
    fontSize: 32,
    fontWeight: 'bold',
    color: '#fafafa',
    marginBottom: 16,
  },
  editTitleInput: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#fafafa',
    marginBottom: 16,
  },
  editBodyInput: {
    fontSize: 17,
    color: '#a3a3a3',
    lineHeight: 26,
    flex: 1,
    minHeight: 400,
  },
  metaRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 24,
    gap: 12,
  },
  date: {
    fontSize: 13,
    color: '#666',
  },
  tags: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  tagText: {
    color: '#6366f1',
    fontSize: 13,
    fontWeight: '500',
  },
  body: {
    fontSize: 16,
    lineHeight: 28,
    color: '#d4d4d4',
  },
  center: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#0a0a0a',
  },
  actionBtn: {
    color: '#6366f1',
    fontSize: 17,
    fontWeight: '600',
  },
  deleteBtnText: {
    color: '#ef4444',
    fontSize: 15,
    opacity: 0.8,
  },
  iconBtn: {
    padding: 4,
  },
});
