import { View, Text, TextInput, TouchableOpacity, StyleSheet, Alert, KeyboardAvoidingView, Platform, ScrollView } from 'react-native';
import { Stack, useRouter } from 'expo-router';
import { useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { queueCreateNote } from '../../src/offline';

export default function CreateNoteScreen() {
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [tags, setTags] = useState('');
  const [isSaving, setIsSaving] = useState(false);
  const router = useRouter();
  const queryClient = useQueryClient();

  const handleSave = async () => {
    if (!title && !body) return;
    
    setIsSaving(true);
    try {
      const tagArray = tags
        .split(',')
        .map(t => t.trim())
        .filter(t => t.length > 0);

      const note = await queueCreateNote({
        title: title || 'Untitled',
        body,
        tags: tagArray,
      });
      
      // Invalidate queries to refresh list
      queryClient.invalidateQueries({ queryKey: ['notes'] });
      
      // Navigate to the note viewer
      router.replace(`/note/${note.id}`);
    } catch (err: any) {
      Alert.alert('Save Failed', err.message || 'Unable to save note locally');
    }
    setIsSaving(false);
  };

  return (
    <KeyboardAvoidingView 
      style={styles.container} 
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      keyboardVerticalOffset={100}
    >
      <Stack.Screen 
        options={{ 
          title: 'New Note',
          headerRight: () => (
            <TouchableOpacity onPress={handleSave} disabled={isSaving}>
              <Text style={[styles.saveAction, isSaving && { opacity: 0.5 }]}>
                {isSaving ? 'Saving...' : 'Save'}
              </Text>
            </TouchableOpacity>
          ),
        }} 
      />

      <ScrollView contentContainerStyle={styles.scroll}>
        <TextInput
          style={styles.titleInput}
          placeholder="Title"
          placeholderTextColor="#666"
          value={title}
          onChangeText={setTitle}
          autoFocus
        />
        
        <TextInput
          style={styles.tagInput}
          placeholder="Tags (comma separated)"
          placeholderTextColor="#444"
          value={tags}
          onChangeText={setTags}
          autoCapitalize="none"
        />

        <TextInput
          style={styles.bodyInput}
          placeholder="Start writing..."
          placeholderTextColor="#666"
          value={body}
          onChangeText={setBody}
          multiline
          textAlignVertical="top"
        />
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0a0a0a',
  },
  scroll: {
    padding: 20,
    flexGrow: 1,
  },
  titleInput: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#fafafa',
    marginBottom: 8,
  },
  tagInput: {
    fontSize: 14,
    color: '#6366f1',
    marginBottom: 20,
    fontFamily: Platform.OS === 'ios' ? 'Courier' : 'monospace',
  },
  bodyInput: {
    fontSize: 17,
    color: '#a3a3a3',
    lineHeight: 26,
    flex: 1,
    minHeight: 300,
  },
  saveAction: {
    color: '#6366f1',
    fontSize: 17,
    fontWeight: '600',
    marginRight: 16,
  },
});
