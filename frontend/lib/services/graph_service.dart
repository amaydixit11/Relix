import '../models.dart';
import 'vault_store.dart';

class GraphService {
  GraphService(this.vault);

  final VaultStore vault;

  Future<GraphData> getFullGraph() async {
    final entries = await vault.readAll();
    return _buildGraph(entries);
  }

  Future<GraphData> getNeighbors(String id, {int depth = 1}) async {
    final allNotes = await vault.readAll();
    final visited = <String>{};
    final nodes = <GraphNode>[];
    final edges = <GraphEdge>[];

    await _traverseNeighbors(id, depth, visited, nodes, edges, allNotes);

    return GraphData(nodes: nodes, edges: edges);
  }

  Future<List<GraphNode>> getRelatedByTags(String id, {int limit = 10}) async {
    try {
      final entry = await vault.getNote(id);
      if (entry == null) return [];

      final userTags = entry.tags
          .where((t) => !t.startsWith('backlink:') && !t.startsWith('outlink:'))
          .toList();

      if (userTags.isEmpty) return [];

      final allEntries = await vault.readAll();
      final related = <String, _GraphScore>{};

      for (final match in allEntries) {
        if (match.id == id) continue;

        final matchTags = match.tags
            .where(
              (t) => !t.startsWith('backlink:') && !t.startsWith('outlink:'),
            )
            .toSet();

        int score = 0;
        for (final tag in userTags) {
          if (matchTags.contains(tag)) score++;
        }

        if (score > 0) {
          related[match.id] = _GraphScore(
            node: GraphNode(
              id: match.id,
              title: _extractTitle(match),
              type: match.type,
              tags: matchTags.toList(),
            ),
            score: score,
          );
        }
      }

      final sorted = related.values.toList()
        ..sort((a, b) => b.score.compareTo(a.score));
      return sorted.take(limit).map((r) => r.node).toList();
    } catch (_) {
      return [];
    }
  }

  GraphData _buildGraph(List<NoteEntry> entries) {
    final nodes = entries.map((e) {
      return GraphNode(
        id: e.id,
        title: _extractTitle(e),
        type: e.type,
        tags: e.tags
            .where(
              (t) => !t.startsWith('backlink:') && !t.startsWith('outlink:'),
            )
            .toList(),
      );
    }).toList();

    final edges = <GraphEdge>[];
    final nodeIds = nodes.map((n) => n.id).toSet();

    for (final entry in entries) {
      final outlinks = entry.tags
          .where((t) => t.startsWith('outlink:'))
          .map((t) => t.replaceFirst('outlink:', ''));

      for (final targetId in outlinks) {
        if (nodeIds.contains(targetId)) {
          edges.add(
            GraphEdge(source: entry.id, target: targetId, type: 'backlink'),
          );
        }
      }
    }

    return GraphData(nodes: nodes, edges: edges);
  }

  Future<void> _traverseNeighbors(
    String id,
    int depth,
    Set<String> visited,
    List<GraphNode> nodes,
    List<GraphEdge> edges,
    List<NoteEntry> allNotes,
  ) async {
    if (depth < 0 || visited.contains(id)) return;
    visited.add(id);

    try {
      final entry = allNotes.firstWhere((n) => n.id == id);
      nodes.add(
        GraphNode(
          id: entry.id,
          title: _extractTitle(entry),
          type: entry.type,
          tags: entry.tags
              .where(
                (t) => !t.startsWith('backlink:') && !t.startsWith('outlink:'),
              )
              .toList(),
        ),
      );

      final outlinkIds = entry.tags
          .where((t) => t.startsWith('outlink:'))
          .map((t) => t.replaceFirst('outlink:', ''))
          .toList();

      final backlinkIds = allNotes
          .where((n) => n.tags.contains('outlink:$id'))
          .map((n) => n.id)
          .toList();

      final neighbors = <String>{...outlinkIds, ...backlinkIds};

      for (final neighborId in neighbors) {
        final isOutlink = outlinkIds.contains(neighborId);

        edges.add(
          GraphEdge(
            source: isOutlink ? id : neighborId,
            target: isOutlink ? neighborId : id,
            type: 'backlink',
          ),
        );

        await _traverseNeighbors(neighborId, depth - 1, visited, nodes, edges, allNotes);
      }
    } catch (_) {
      // Note doesn't exist
    }
  }
}

String _extractTitle(NoteEntry entry) {
  final content = entry.content;
  if (content is NoteContent) return content.title;
  if (content is FileContent) return content.name;
  if (content is LogContent) return content.date;
  if (content is LinkContent) return content.title;
  return 'Untitled';
}

class _GraphScore {
  _GraphScore({required this.node, required this.score});
  final GraphNode node;
  final int score;
}
