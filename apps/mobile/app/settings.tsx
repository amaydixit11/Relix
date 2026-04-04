import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  Alert,
  Modal,
  ScrollView,
} from 'react-native';
import { Stack } from 'expo-router';
import { useState, useEffect, type ReactNode } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import {
  connectionService,
  useConnectionState,
} from '@relix/core';
import { BarCodeScanner } from 'expo-barcode-scanner';

export default function SettingsScreen() {
  const connection = useConnectionState();
  const [inviteCode, setInviteCode] = useState('');
  const [isSyncing, setIsSyncing] = useState(false);
  const [showScanner, setShowScanner] = useState(false);
  const [hasPermission, setHasPermission] = useState<boolean | null>(null);
  const [bridgeUrl, setBridgeUrl] = useState('http://localhost:7331');
  const [showAdvanced, setShowAdvanced] = useState(false);
  const [editingPeerId, setEditingPeerId] = useState<string | null>(null);
  const [nicknameDraft, setNicknameDraft] = useState('');

  useEffect(() => {
    void AsyncStorage.getItem('@relix/server_url').then((url) => {
      if (url) {
        setBridgeUrl(url);
        connectionService.setBaseUrl(url);
      }
    });

    void (async () => {
      const { status } = await BarCodeScanner.requestPermissionsAsync();
      setHasPermission(status === 'granted');
    })();
  }, []);

  const saveBridge = async (url: string) => {
    setBridgeUrl(url);
    await AsyncStorage.setItem('@relix/server_url', url);
    connectionService.setBaseUrl(url);
  };

  const handlePair = async (code: string = inviteCode) => {
    const finalCode = typeof code === 'string' ? code : inviteCode;
    if (!finalCode) return;

    setIsSyncing(true);
    try {
      await connectionService.pairDevice(finalCode);
      setInviteCode('');
      setShowScanner(false);
      Alert.alert('Success', 'Successfully paired with device!');
    } catch (err: any) {
      Alert.alert('Pairing Failed', err.message);
    }
    setIsSyncing(false);
  };

  const handleBarCodeScanned = ({ data }: { data: string }) => {
    setShowScanner(false);
    void handlePair(data);
  };

  const handleRename = async (peerId: string) => {
    await connectionService.renamePeer(peerId, nicknameDraft);
    setEditingPeerId(null);
    setNicknameDraft('');
  };

  return (
    <View style={styles.container}>
      <Stack.Screen options={{ title: 'Settings' }} />
      <ScrollView contentContainerStyle={styles.scroll}>
        <Section title="Sync & Pairing">
          <View style={styles.badge}>
            <View style={styles.badgeDot} />
            <Text style={styles.badgeText}>Local Network Only Until Relay Is Verified</Text>
          </View>

          {connection.identity ? (
            <View style={styles.idCard}>
              <Text style={styles.idTitle}>This Device</Text>
              <Text style={styles.idValue}>{connection.identity.peer_id}</Text>
              <Text style={styles.idHint}>
                {connection.connectionType === 'relay'
                  ? 'Connected through relay'
                  : connection.connectionType === 'direct'
                    ? 'Connected directly'
                    : 'Ready to pair on your local network'}
              </Text>
            </View>
          ) : (
            <TouchableOpacity
              style={styles.connectState}
              onPress={() => {
                setIsSyncing(true);
                void connectionService.refresh().finally(() => setIsSyncing(false));
              }}
            >
              <Text style={styles.statusOffline}>○ No Active Connection</Text>
              <Text style={styles.hint}>Tap to retry connecting to the daemon</Text>
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
            <TouchableOpacity style={styles.pairButton} onPress={() => void handlePair()}>
              <Text style={styles.pairButtonText}>{isSyncing ? '...' : 'Pair'}</Text>
            </TouchableOpacity>
          </View>

          <TouchableOpacity style={styles.scannerTrigger} onPress={() => setShowScanner(true)}>
            <Text style={styles.scannerText}>Scan QR Code</Text>
          </TouchableOpacity>

          <TouchableOpacity style={styles.advancedToggle} onPress={() => setShowAdvanced((current) => !current)}>
            <Text style={styles.advancedToggleText}>
              {showAdvanced ? 'Hide Advanced Connection Settings' : 'Show Advanced Connection Settings'}
            </Text>
          </TouchableOpacity>

          {showAdvanced ? (
            <View style={styles.advancedPanel}>
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
                <TouchableOpacity style={styles.pairButton} onPress={() => void saveBridge(bridgeUrl)}>
                  <Text style={styles.pairButtonText}>Set</Text>
                </TouchableOpacity>
              </View>
              <Text style={styles.hint}>
                Use manual bridge configuration only if QR pairing is unavailable.
              </Text>
            </View>
          ) : null}
        </Section>

        <Section title="Paired Devices">
          {connection.peers.length > 0 ? (
            connection.peers.map((peer) => (
              <View key={peer.id} style={styles.peerCard}>
                <View style={styles.peerHeader}>
                  <View style={styles.peerInfo}>
                    <Text style={styles.peerId}>{peer.display_name}</Text>
                    <Text style={styles.peerMeta}>{peer.id.slice(0, 12)}...{peer.id.slice(-6)}</Text>
                  </View>
                  <Text style={peer.is_connected ? styles.statusOnline : styles.statusMuted}>
                    {peer.is_connected ? peer.connection_type || 'connected' : 'saved'}
                  </Text>
                </View>

                <Text style={styles.peerMeta}>First paired: {formatTimestamp(peer.first_paired_at)}</Text>
                <Text style={styles.peerMeta}>Last seen: {formatTimestamp(peer.last_seen_at)}</Text>
                <Text style={styles.peerMeta}>Last sync: {formatTimestamp(peer.last_sync_at)}</Text>

                {editingPeerId === peer.id ? (
                  <View style={styles.pairRow}>
                    <TextInput
                      style={styles.input}
                      value={nicknameDraft}
                      onChangeText={setNicknameDraft}
                      placeholder="Peer nickname"
                      placeholderTextColor="#666"
                    />
                    <TouchableOpacity style={styles.pairButton} onPress={() => void handleRename(peer.id)}>
                      <Text style={styles.pairButtonText}>Save</Text>
                    </TouchableOpacity>
                  </View>
                ) : (
                  <TouchableOpacity
                    style={styles.renameButton}
                    onPress={() => {
                      setEditingPeerId(peer.id);
                      setNicknameDraft(peer.nickname ?? '');
                    }}
                  >
                    <Text style={styles.renameButtonText}>Rename Peer</Text>
                  </TouchableOpacity>
                )}
              </View>
            ))
          ) : (
            <Text style={styles.muted}>No paired peers recorded yet.</Text>
          )}
        </Section>

        <Section title="About">
          <InfoRow label="Vault Status" value={connection.daemonReachable ? 'Online' : 'Offline'} />
          <InfoRow
            label="Peers"
            value={String(connection.peers.filter((peer) => peer.is_connected).length)}
          />
          <InfoRow label="Pending Changes" value={String(connection.pendingChanges)} />
          <InfoRow label="Reachability" value="Local network only" />
        </Section>
      </ScrollView>

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
          <TouchableOpacity style={styles.closeScanner} onPress={() => setShowScanner(false)}>
            <Text style={styles.closeScannerText}>Cancel</Text>
          </TouchableOpacity>
        </View>
      </Modal>
    </View>
  );
}

function Section({ title, children }: { title: string; children: ReactNode }) {
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

function formatTimestamp(value?: number) {
  if (!value) return 'Never';
  return new Date(value * 1000).toLocaleString();
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
  badge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    backgroundColor: 'rgba(245, 158, 11, 0.1)',
    borderWidth: 1,
    borderColor: 'rgba(245, 158, 11, 0.2)',
    borderRadius: 999,
    paddingVertical: 8,
    paddingHorizontal: 12,
    marginBottom: 16,
  },
  badgeDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: '#f59e0b',
  },
  badgeText: {
    color: '#f59e0b',
    fontSize: 11,
    fontWeight: '700',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
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
  statusOnline: {
    color: '#22c55e',
    fontSize: 12,
    fontWeight: '700',
    textTransform: 'uppercase',
  },
  statusOffline: {
    color: '#ef4444',
    fontSize: 14,
    fontWeight: '600',
  },
  statusMuted: {
    color: '#71717a',
    fontSize: 12,
    fontWeight: '700',
    textTransform: 'uppercase',
  },
  hint: {
    fontSize: 12,
    color: '#666',
    textAlign: 'center',
  },
  pairRow: {
    flexDirection: 'row',
    gap: 8,
    marginTop: 12,
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
  advancedToggle: {
    marginTop: 12,
    alignItems: 'center',
  },
  advancedToggleText: {
    color: '#a1a1aa',
    fontSize: 12,
    textDecorationLine: 'underline',
  },
  advancedPanel: {
    marginTop: 12,
    paddingTop: 12,
    borderTopWidth: 1,
    borderTopColor: '#262626',
  },
  peerCard: {
    borderTopWidth: 1,
    borderTopColor: '#262626',
    paddingTop: 12,
    marginTop: 12,
  },
  peerHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: 8,
  },
  peerInfo: {
    flex: 1,
    marginRight: 12,
  },
  peerId: {
    fontSize: 14,
    color: '#fafafa',
    fontWeight: '600',
  },
  peerMeta: {
    fontSize: 11,
    color: '#666',
    marginTop: 2,
  },
  renameButton: {
    marginTop: 10,
    alignSelf: 'flex-start',
  },
  renameButtonText: {
    color: '#6366f1',
    fontSize: 12,
    fontWeight: '600',
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
