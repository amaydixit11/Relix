import { View, Text, TextInput, TouchableOpacity, StyleSheet, Alert, Modal, ScrollView } from 'react-native';
import { Stack } from 'expo-router';
import { useState, useEffect } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { p2pService } from '@relix/core';
import type { LocalIdentity, PeerInfo, SyncStatus } from '@relix/core';
import { BarCodeScanner } from 'expo-barcode-scanner';

export default function SettingsScreen() {
  const [identity, setIdentity] = useState<LocalIdentity | null>(null);
  const [peers, setPeers] = useState<PeerInfo[]>([]);
  const [status, setStatus] = useState<SyncStatus | null>(null);
  const [inviteCode, setInviteCode] = useState('');
  const [isSyncing, setIsSyncing] = useState(false);
  const [showScanner, setShowScanner] = useState(false);
  const [hasPermission, setHasPermission] = useState<boolean | null>(null);
  const [bridgeUrl, setBridgeUrl] = useState('http://localhost:7331');

  useEffect(() => {
    AsyncStorage.getItem('@relix/server_url').then(url => {
      if (url) {
        setBridgeUrl(url);
        p2pService.setBaseUrl(url);
      }
      loadData();
    });

    (async () => {
      const { status } = await BarCodeScanner.requestPermissionsAsync();
      setHasPermission(status === 'granted');
    })();
  }, []);

  const saveBridge = async (url: string) => {
    setBridgeUrl(url);
    await AsyncStorage.setItem('@relix/server_url', url);
    p2pService.setBaseUrl(url);
    loadData();
  };

  const loadData = async () => {
    setIsSyncing(true);
    try {
      const [idRes, peersRes, statusRes] = await Promise.all([
        p2pService.getLocalIdentity().catch(() => null),
        p2pService.getConnectedPeers().catch(() => []),
        p2pService.getStatus().catch(() => null),
      ]);
      setIdentity(idRes);
      setPeers(peersRes);
      setStatus(statusRes);
    } catch (err) {
      console.warn('Failed to load P2P data:', err);
    }
    setIsSyncing(false);
  };

  const handlePair = async (code: string = inviteCode) => {
    const finalCode = typeof code === 'string' ? code : inviteCode;
    if (!finalCode) return;
    
    setIsSyncing(true);
    try {
      await p2pService.pairDevice(finalCode);
      setInviteCode('');
      setShowScanner(false);
      Alert.alert('Success', 'Successfully paired with device!');
      loadData();
    } catch (err: any) {
      Alert.alert('Pairing Failed', err.message);
    }
    setIsSyncing(false);
  };

  const handleBarCodeScanned = ({ data }: { data: string }) => {
    setShowScanner(false);
    handlePair(data);
  };

  return (
    <View style={styles.container}>
      <Stack.Screen options={{ title: 'Settings' }} />
      <ScrollView contentContainerStyle={styles.scroll}>
        
        {/* Bridge Config Section */}
        <Section title="Bridge Configuration">
          <Text style={styles.label}>ACORDE Instance URL</Text>
          <View style={styles.pairRow}>
            <TextInput
              style={styles.input}
              value={bridgeUrl}
              onChangeText={setBridgeUrl}
              placeholder="http://192.168.x.x:7331"
              placeholderTextColor="#666"
              autoCapitalize="none"
              autoCorrect={false}
            />
            <TouchableOpacity style={styles.pairButton} onPress={() => saveBridge(bridgeUrl)}>
              <Text style={styles.pairButtonText}>Set</Text>
            </TouchableOpacity>
          </View>
          <Text style={styles.hint}>
            Enter the IP address of the device running the ACORDE daemon.
          </Text>
        </Section>

        {/* Connection Section */}
        <Section title="Sync & Pairing">
          {identity ? (
            <View style={styles.idCard}>
              <Text style={styles.idTitle}>This Device</Text>
              <Text style={styles.idValue}>{identity.peer_id}</Text>
              <Text style={styles.idHint}>Device addresses visible on local network</Text>
            </View>
          ) : (
            <TouchableOpacity style={styles.connectState} onPress={loadData}>
              <Text style={styles.statusOffline}>○ No Active Connection</Text>
              <Text style={styles.hint}>Tap to retry connecting to local daemon</Text>
            </TouchableOpacity>
          )}

          <View style={styles.pairRow}>
            <TextInput
              style={styles.input}
              value={inviteCode}
              onChangeText={setInviteCode}
              placeholder="Paste invite code..."
              placeholderTextColor="#666"
              autoCapitalize="none"
              autoCorrect={false}
            />
            <TouchableOpacity style={styles.pairButton} onPress={() => handlePair()}>
              <Text style={styles.pairButtonText}>Pair</Text>
            </TouchableOpacity>
          </View>

          <TouchableOpacity 
            style={styles.scannerTrigger} 
            onPress={() => setShowScanner(true)}
          >
            <Text style={styles.scannerText}>Scan QR Code</Text>
          </TouchableOpacity>
        </Section>

        {/* Peers Section */}
        <Section title="Connected Peers">
          {peers.length > 0 ? (
            peers.map(p => (
              <View key={p.id} style={styles.peerRow}>
                <View style={styles.peerInfo}>
                  <Text style={styles.peerId}>{p.id.slice(0, 8)}...{p.id.slice(-4)}</Text>
                  <Text style={styles.peerAddrs}>{p.addrs.length} addresses</Text>
                </View>
                <View style={styles.statusDot} />
              </View>
            ))
          ) : (
            <Text style={styles.muted}>No other devices connected yet.</Text>
          )}
        </Section>

        <Section title="About">
          <InfoRow label="Vault Status" value={status?.connected ? 'Online' : 'Offline'} />
          <InfoRow label="Local Notes" value={status?.pending_changes?.toString() ?? '0'} />
          <InfoRow label="Protocol" value="ACORDE P2P v1" />
        </Section>

      </ScrollView>

      {/* QR Scanner Modal */}
      <Modal visible={showScanner} animationType="slide">
        <View style={styles.scannerContainer}>
          {hasPermission ? (
            <BarCodeScanner
              onBarCodeScanned={handleBarCodeScanned}
              style={StyleSheet.absoluteFillObject}
            />
          ) : (
            <View style={styles.center}>
              <Text style={styles.scannerOverlayText}>No camera permission</Text>
              <TouchableOpacity onPress={() => setShowScanner(false)}>
                <Text style={styles.scannerText}>Go Back</Text>
              </TouchableOpacity>
            </View>
          )}
          <TouchableOpacity 
            style={styles.closeScanner} 
            onPress={() => setShowScanner(false)}
          >
            <Text style={styles.closeScannerText}>Cancel</Text>
          </TouchableOpacity>
        </View>
      </Modal>
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
  },
  scroll: {
    padding: 20,
  },
  section: {
    backgroundColor: '#141414',
    borderRadius: 16,
    padding: 16,
    marginBottom: 20,
    borderWidth: 1,
    borderColor: '#262626',
  },
  sectionTitle: {
    fontSize: 12,
    fontWeight: '700',
    color: '#666',
    marginBottom: 16,
    textTransform: 'uppercase',
    letterSpacing: 1,
  },
  label: {
    fontSize: 13,
    color: '#a3a3a3',
    marginBottom: 8,
  },
  idCard: {
    backgroundColor: '#0a0a0a',
    borderRadius: 12,
    padding: 16,
    borderWidth: 1,
    borderColor: '#262626',
  },
  idTitle: {
    fontSize: 13,
    color: '#a3a3a3',
    marginBottom: 4,
  },
  idValue: {
    fontSize: 11,
    fontFamily: 'monospace',
    color: '#6366f1',
    fontWeight: '600',
  },
  idHint: {
    fontSize: 10,
    color: '#555',
    marginTop: 8,
  },
  connectState: {
    padding: 16,
    alignItems: 'center',
    gap: 8,
  },
  statusOnline: { color: '#22c55e', fontSize: 14, fontWeight: '600' },
  statusOffline: { color: '#ef4444', fontSize: 14, fontWeight: '600' },
  hint: { fontSize: 12, color: '#666', textAlign: 'center' },
  pairRow: {
    flexDirection: 'row',
    gap: 8,
    marginTop: 4,
  },
  input: {
    flex: 1,
    backgroundColor: '#0a0a0a',
    borderWidth: 1,
    borderColor: '#262626',
    borderRadius: 8,
    padding: 12,
    color: '#fafafa',
    fontSize: 14,
  },
  pairButton: {
    backgroundColor: '#6366f1',
    paddingHorizontal: 16,
    borderRadius: 8,
    justifyContent: 'center',
  },
  pairButtonText: {
    color: '#fff',
    fontWeight: '600',
  },
  scannerTrigger: {
    marginTop: 12,
    padding: 14,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#6366f1',
    alignItems: 'center',
  },
  scannerText: {
    color: '#6366f1',
    fontWeight: '600',
  },
  peerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 12,
    borderTopWidth: 1,
    borderTopColor: '#262626',
  },
  peerInfo: {
    flex: 1,
  },
  peerId: {
    fontSize: 14,
    color: '#fafafa',
    fontFamily: 'monospace',
  },
  peerAddrs: {
    fontSize: 11,
    color: '#666',
    marginTop: 2,
  },
  statusDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: '#22c55e',
  },
  muted: {
    color: '#666',
    fontSize: 13,
    textAlign: 'center',
    marginTop: 10,
  },
  infoRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 10,
    borderBottomWidth: 1,
    borderBottomColor: '#262626',
  },
  infoLabel: {
    color: '#a3a3a3',
    fontSize: 14,
  },
  infoValue: {
    color: '#fafafa',
    fontFamily: 'monospace',
    fontSize: 14,
  },
  scannerContainer: {
    flex: 1,
    backgroundColor: '#000',
  },
  scannerOverlayText: {
    color: '#fff',
    marginBottom: 20,
    textAlign: 'center',
  },
  center: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  closeScanner: {
    position: 'absolute',
    bottom: 40,
    alignSelf: 'center',
    backgroundColor: 'rgba(0,0,0,0.6)',
    paddingHorizontal: 30,
    paddingVertical: 12,
    borderRadius: 25,
    borderWidth: 1,
    borderColor: '#fff',
  },
  closeScannerText: {
    color: '#fff',
    fontWeight: '700',
  },
});
