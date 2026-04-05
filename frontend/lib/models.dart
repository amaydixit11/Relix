class NoteContent {
  const NoteContent({required this.title, required this.body});

  final String title;
  final String body;

  Map<String, dynamic> toJson() => {'title': title, 'body': body};

  factory NoteContent.fromJson(Map<String, dynamic> json) {
    return NoteContent(
      title: (json['title'] ?? 'Untitled') as String,
      body: (json['body'] ?? '') as String,
    );
  }
}

class LogContent {
  const LogContent({required this.date, required this.body});
  final String date;
  final String body;

  Map<String, dynamic> toJson() => {'date': date, 'body': body};

  factory LogContent.fromJson(Map<String, dynamic> json) {
    return LogContent(
      date: (json['date'] ?? '') as String,
      body: (json['body'] ?? '') as String,
    );
  }
}

class FileContent {
  const FileContent({
    required this.name,
    required this.cid,
    required this.size,
    required this.mimeType,
    this.annotations = const [],
  });

  final String name;
  final String cid;
  final int size;
  final String mimeType;
  final List<Annotation> annotations;

  Map<String, dynamic> toJson() => {
    'name': name,
    'cid': cid,
    'size': size,
    'mime_type': mimeType,
    'annotations': annotations.map((a) => a.toJson()).toList(),
  };

  factory FileContent.fromJson(Map<String, dynamic> json) {
    return FileContent(
      name: (json['name'] ?? 'Untitled') as String,
      cid: (json['cid'] ?? '') as String,
      size: (json['size'] ?? 0) as int,
      mimeType: (json['mime_type'] ?? 'application/octet-stream') as String,
      annotations: ((json['annotations'] as List?) ?? const [])
          .map((a) => Annotation.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Annotation {
  const Annotation({
    required this.page,
    required this.x,
    required this.y,
    required this.text,
  });

  final int page;
  final double x;
  final double y;
  final String text;

  Map<String, dynamic> toJson() => {'page': page, 'x': x, 'y': y, 'text': text};

  factory Annotation.fromJson(Map<String, dynamic> json) {
    return Annotation(
      page: (json['page'] ?? 0) as int,
      x: (json['x'] ?? 0.0).toDouble(),
      y: (json['y'] ?? 0.0).toDouble(),
      text: (json['text'] ?? '') as String,
    );
  }
}

class LinkContent {
  const LinkContent({
    required this.url,
    required this.title,
    this.excerpt,
    this.favicon,
  });
  final String url;
  final String title;
  final String? excerpt;
  final String? favicon;

  Map<String, dynamic> toJson() => {
    'url': url,
    'title': title,
    'excerpt': excerpt,
    'favicon': favicon,
  };

  factory LinkContent.fromJson(Map<String, dynamic> json) {
    return LinkContent(
      url: (json['url'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      excerpt: json['excerpt'] as String?,
      favicon: json['favicon'] as String?,
    );
  }
}

class NoteEntry {
  const NoteEntry({
    required this.id,
    required this.type,
    required this.content,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    required this.deleted,
    required this.owner,
    this.pendingSync = false,
  });

  final String id;
  final String type;
  final dynamic content; // Usually NoteContent, but can be LogContent, etc.
  final List<String> tags;
  final int createdAt;
  final int updatedAt;
  final bool deleted;
  final String owner;
  final bool pendingSync;

  NoteEntry copyWith({
    String? id,
    String? type,
    dynamic content,
    List<String>? tags,
    int? createdAt,
    int? updatedAt,
    bool? deleted,
    String? owner,
    bool? pendingSync,
  }) {
    return NoteEntry(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      owner: owner ?? this.owner,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'content': content.toJson(),
    'tags': tags,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'deleted': deleted,
    'owner': owner,
    'pending_sync': pendingSync,
  };

  factory NoteEntry.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] ?? 'note') as String;
    final rawContent = (json['content'] ?? const {}) as Map<String, dynamic>;

    dynamic decodedContent;
    switch (type) {
      case 'note':
        decodedContent = NoteContent.fromJson(rawContent);
        break;
      case 'log':
        decodedContent = LogContent.fromJson(rawContent);
        break;
      case 'file':
        decodedContent = FileContent.fromJson(rawContent);
        break;
      case 'link':
        decodedContent = LinkContent.fromJson(rawContent);
        break;
      default:
        decodedContent = rawContent;
    }

    return NoteEntry(
      id: (json['id'] ?? '') as String,
      type: type,
      content: decodedContent,
      tags: ((json['tags'] as List?) ?? const []).cast<String>(),
      createdAt: (json['created_at'] ?? 0) as int,
      updatedAt: (json['updated_at'] ?? 0) as int,
      deleted: (json['deleted'] ?? false) as bool,
      owner: (json['owner'] ?? '') as String,
      pendingSync: (json['pending_sync'] ?? false) as bool,
    );
  }

  // Helper for quick access if it's a note
  NoteContent? get asNote =>
      content is NoteContent ? content as NoteContent : null;
}

class LocalIdentity {
  const LocalIdentity({required this.peerId, required this.addrs});

  final String peerId;
  final List<String> addrs;

  factory LocalIdentity.fromJson(Map<String, dynamic> json) {
    return LocalIdentity(
      peerId: (json['peer_id'] ?? '') as String,
      addrs: ((json['addrs'] as List?) ?? const []).cast<String>(),
    );
  }
}

class RemotePeer {
  const RemotePeer({
    required this.id,
    required this.displayName,
    this.nickname,
    this.connectionType,
    this.isConnected = false,
    this.firstPairedAt,
    this.lastSeenAt,
    this.lastSyncAt,
  });

  final String id;
  final String displayName;
  final String? nickname;
  final String? connectionType;
  final bool isConnected;
  final int? firstPairedAt;
  final int? lastSeenAt;
  final int? lastSyncAt;

  String get effectiveName =>
      (nickname?.trim().isNotEmpty ?? false) ? nickname!.trim() : displayName;

  RemotePeer copyWith({
    String? id,
    String? displayName,
    String? nickname,
    String? connectionType,
    bool? isConnected,
    int? firstPairedAt,
    int? lastSeenAt,
    int? lastSyncAt,
  }) {
    return RemotePeer(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      nickname: nickname ?? this.nickname,
      connectionType: connectionType ?? this.connectionType,
      isConnected: isConnected ?? this.isConnected,
      firstPairedAt: firstPairedAt ?? this.firstPairedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'display_name': displayName,
    'nickname': nickname,
    'connection_type': connectionType,
    'is_connected': isConnected,
    'first_paired_at': firstPairedAt,
    'last_seen_at': lastSeenAt,
    'last_sync_at': lastSyncAt,
  };

  factory RemotePeer.fromJson(Map<String, dynamic> json) {
    return RemotePeer(
      id: (json['id'] ?? '') as String,
      displayName: (json['display_name'] ?? json['id'] ?? '') as String,
      nickname: json['nickname'] as String?,
      connectionType: json['connection_type'] as String?,
      isConnected: (json['is_connected'] ?? false) as bool,
      firstPairedAt: json['first_paired_at'] as int?,
      lastSeenAt: json['last_seen_at'] as int?,
      lastSyncAt: json['last_sync_at'] as int?,
    );
  }
}

class MutationPayload {
  const MutationPayload({
    required this.type,
    required this.noteId,
    this.title,
    this.body,
    this.tags = const [],
    this.createdAt,
    this.retryCount = 0,
  });

  final String type;
  final String noteId;
  final String? title;
  final String? body;
  final List<String> tags;
  final int? createdAt;
  final int retryCount;

  MutationPayload copyWith({
    String? type,
    String? noteId,
    String? title,
    String? body,
    List<String>? tags,
    int? createdAt,
    int? retryCount,
  }) {
    return MutationPayload(
      type: type ?? this.type,
      noteId: noteId ?? this.noteId,
      title: title ?? this.title,
      body: body ?? this.body,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'note_id': noteId,
    'title': title,
    'body': body,
    'tags': tags,
    'created_at': createdAt,
    'retry_count': retryCount,
  };

  factory MutationPayload.fromJson(Map<String, dynamic> json) {
    return MutationPayload(
      type: (json['type'] ?? '') as String,
      noteId: (json['note_id'] ?? '') as String,
      title: json['title'] as String?,
      body: json['body'] as String?,
      tags: ((json['tags'] as List?) ?? const []).cast<String>(),
      createdAt: json['created_at'] as int?,
      retryCount: (json['retry_count'] ?? 0) as int,
    );
  }
}

class SyncSnapshot {
  const SyncSnapshot({
    this.identity,
    this.peers = const [],
    this.notes = const [],
    this.baseUrl = 'http://localhost:7331',
    this.pendingChanges = 0,
    this.stuckMutations = 0,
    this.daemonReachable = false,
    this.initialized = false,
    this.inviteCode,
    this.errorMessage,
    this.lastSyncAt,
  });

  final LocalIdentity? identity;
  final List<RemotePeer> peers;
  final List<NoteEntry> notes;
  final String baseUrl;
  final int pendingChanges;
  final int stuckMutations;
  final bool daemonReachable;
  final bool initialized;
  final String? inviteCode;
  final String? errorMessage;
  final int? lastSyncAt;

  String get connectionType {
    if (peers.any(
      (peer) => peer.connectionType == 'relay' && peer.isConnected,
    )) {
      return 'relay';
    }
    if (peers.any((peer) => peer.isConnected)) {
      return 'direct';
    }
    if (!daemonReachable) {
      return 'offline';
    }
    return 'unknown';
  }

  SyncSnapshot copyWith({
    LocalIdentity? identity,
    List<RemotePeer>? peers,
    List<NoteEntry>? notes,
    String? baseUrl,
    int? pendingChanges,
    int? stuckMutations,
    bool? daemonReachable,
    bool? initialized,
    String? inviteCode,
    String? errorMessage,
    int? lastSyncAt,
  }) {
    return SyncSnapshot(
      identity: identity ?? this.identity,
      peers: peers ?? this.peers,
      notes: notes ?? this.notes,
      baseUrl: baseUrl ?? this.baseUrl,
      pendingChanges: pendingChanges ?? this.pendingChanges,
      stuckMutations: stuckMutations ?? this.stuckMutations,
      daemonReachable: daemonReachable ?? this.daemonReachable,
      initialized: initialized ?? this.initialized,
      inviteCode: inviteCode ?? this.inviteCode,
      errorMessage: errorMessage,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }
}

class GraphNode {
  const GraphNode({
    required this.id,
    required this.title,
    required this.type,
    required this.tags,
  });

  final String id;
  final String title;
  final String type;
  final List<String> tags;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'type': type,
    'tags': tags,
  };

  factory GraphNode.fromJson(Map<String, dynamic> json) {
    return GraphNode(
      id: (json['id'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      type: (json['type'] ?? '') as String,
      tags: ((json['tags'] as List?) ?? const []).cast<String>(),
    );
  }
}

class GraphEdge {
  const GraphEdge({
    required this.source,
    required this.target,
    required this.type,
  });

  final String source;
  final String target;
  final String type;

  Map<String, dynamic> toJson() => {
    'source': source,
    'target': target,
    'type': type,
  };

  factory GraphEdge.fromJson(Map<String, dynamic> json) {
    return GraphEdge(
      source: (json['source'] ?? '') as String,
      target: (json['target'] ?? '') as String,
      type: (json['type'] ?? '') as String,
    );
  }
}

class GraphData {
  const GraphData({required this.nodes, required this.edges});

  final List<GraphNode> nodes;
  final List<GraphEdge> edges;

  Map<String, dynamic> toJson() => {
    'nodes': nodes.map((n) => n.toJson()).toList(),
    'edges': edges.map((e) => e.toJson()).toList(),
  };

  factory GraphData.fromJson(Map<String, dynamic> json) {
    return GraphData(
      nodes: ((json['nodes'] as List?) ?? const [])
          .map((n) => GraphNode.fromJson(n as Map<String, dynamic>))
          .toList(),
      edges: ((json['edges'] as List?) ?? const [])
          .map((e) => GraphEdge.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
