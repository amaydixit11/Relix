import { View, Text, TextInput, TouchableOpacity, StyleSheet, Alert } from 'react-native';
import { Stack } from 'expo-router';
import { useState, useEffect } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';

const STORAGE_KEY = '@relix/server_url';
const DEFAULT_URL = 'http://localhost:7331';

export default function SettingsScreen() {
  const [serverUrl, setServerUrl] = useState(DEFAULT_URL);
  const [isConnected, setIsConnected] = useState(false);
  const [testing, setTesting] = useState(false);

  useEffect(() => {
    // Load saved server URL
    AsyncStorage.getItem(STORAGE_KEY).then(url => {
      if (url) setServerUrl(url);
    });
  }, []);

  const testConnection = async () => {
    setTesting(true);
    try {
      const res = await fetch(`${serverUrl}/status`, { 
        method: 'GET',
        headers: { 'Accept': 'application/json' },
      });
      if (res.ok) {
        setIsConnected(true);
        Alert.alert('Connected', 'Successfully connected to ACORDE server');
      } else {
        setIsConnected(false);
        Alert.alert('Error', 'Server responded with an error');
      }
    } catch (err) {
      setIsConnected(false);
      Alert.alert('Connection Failed', 'Could not connect to server. Check the URL and ensure ACORDE is running.');
    }
    setTesting(false);
  };

  const saveServer = async () => {
    await AsyncStorage.setItem(STORAGE_KEY, serverUrl);
    Alert.alert('Saved', 'Server URL saved');
  };

  return (
    <View style={styles.container}>
      <Stack.Screen options={{ title: 'Settings' }} />

      <Section title="Server Connection">
        <Text style={styles.label}>ACORDE Server URL</Text>
        <TextInput
          style={styles.input}
          value={serverUrl}
          onChangeText={setServerUrl}
          placeholder="http://192.168.x.x:7331"
          placeholderTextColor="#666"
          autoCapitalize="none"
          autoCorrect={false}
        />
        <Text style={styles.hint}>
          Enter your desktop's IP address to sync notes.
          Find it with: hostname -I (Linux) or ipconfig (Windows)
        </Text>
        
        <View style={styles.row}>
          <TouchableOpacity 
            style={[styles.button, styles.secondaryButton]} 
            onPress={testConnection}
            disabled={testing}
          >
            <Text style={styles.buttonText}>
              {testing ? 'Testing...' : 'Test Connection'}
            </Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.button} onPress={saveServer}>
            <Text style={styles.buttonText}>Save</Text>
          </TouchableOpacity>
        </View>

        <View style={[styles.status, isConnected ? styles.connected : styles.disconnected]}>
          <Text style={styles.statusText}>
            {isConnected ? '● Connected' : '○ Not connected'}
          </Text>
        </View>
      </Section>

      <Section title="Sync">
        <Text style={styles.hint}>
          Notes sync automatically when connected to the server.
          Pull down on the notes list to manually refresh.
        </Text>
      </Section>

      <Section title="About">
        <InfoRow label="Version" value="0.0.1-alpha" />
        <InfoRow label="Platform" value="Expo / React Native" />
      </Section>
    </View>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <View style={styles.section}>
      <Text style={styles.sectionTitle}>{title}</Text>
      {children}
    </View>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.infoRow}>
      <Text style={styles.infoLabel}>{label}</Text>
      <Text style={styles.infoValue}>{value}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0a0a0a',
    padding: 20,
  },
  section: {
    backgroundColor: '#141414',
    borderRadius: 12,
    padding: 16,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: '#262626',
  },
  sectionTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: '#a3a3a3',
    marginBottom: 12,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  label: {
    fontSize: 14,
    color: '#fafafa',
    marginBottom: 8,
  },
  input: {
    backgroundColor: '#0a0a0a',
    borderWidth: 1,
    borderColor: '#262626',
    borderRadius: 8,
    padding: 12,
    color: '#fafafa',
    fontSize: 14,
    fontFamily: 'monospace',
  },
  hint: {
    fontSize: 12,
    color: '#666',
    marginTop: 8,
    lineHeight: 18,
  },
  row: {
    flexDirection: 'row',
    gap: 12,
    marginTop: 16,
  },
  button: {
    flex: 1,
    backgroundColor: '#6366f1',
    paddingVertical: 12,
    borderRadius: 8,
    alignItems: 'center',
  },
  secondaryButton: {
    backgroundColor: '#262626',
  },
  buttonText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
  },
  status: {
    marginTop: 12,
    padding: 8,
    borderRadius: 6,
    alignItems: 'center',
  },
  connected: {
    backgroundColor: 'rgba(34, 197, 94, 0.1)',
  },
  disconnected: {
    backgroundColor: 'rgba(239, 68, 68, 0.1)',
  },
  statusText: {
    fontSize: 12,
    color: '#a3a3a3',
  },
  infoRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: '#262626',
  },
  infoLabel: {
    color: '#a3a3a3',
  },
  infoValue: {
    color: '#fafafa',
    fontFamily: 'monospace',
  },
});
