import '../models.dart';
import 'acorde_client.dart';

class GraphService {
  GraphService(this.client);

  final AcordeClient client;

  Future<GraphData> getFullGraph() async {
    final entries = await client.listNotes();

    final nodes = entries.map((e) {
      return GraphNode(
        id: e.id,
        title: e.content.title,
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

  Future<GraphData> getNeighbors(String id, {int depth = 1}) async {
    final visited = <String>{};
    final nodes = <GraphNode>[];
    final edges = <GraphEdge>[];

    await _traverseNeighbors(id, depth, visited, nodes, edges);

    return GraphData(nodes: nodes, edges: edges);
  }

  Future<List<GraphNode>> getRelatedByTags(String id, {int limit = 10}) async {
    try {
      final entry = await client.getNote(id);
      final userTags = entry.tags
          .where((t) => !t.startsWith('backlink:') && !t.startsWith('outlink:'))
          .toList();

      if (userTags.isEmpty) return [];

      final allEntries = await client.listNotes();

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
              title: match.content.title,
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

  Future<void> _traverseNeighbors(
    String id,
    int depth,
    Set<String> visited,
    List<GraphNode> nodes,
    List<GraphEdge> edges,
  ) async {
    if (depth < 0 || visited.contains(id)) return;
    visited.add(id);

    try {
      final entry = await client.getNote(id);
      nodes.add(
        GraphNode(
          id: entry.id,
          title: entry.content.title,
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

      // Get backlinks by checking who outlinks to this note
      final allNotes = await client.listNotes();
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

        await _traverseNeighbors(neighborId, depth - 1, visited, nodes, edges);
      }
    } catch (_) {
      // Note doesn't exist
    }
  }
}

class _GraphScore {
  _GraphScore({required this.node, required this.score});
  final GraphNode node;
  final int score;
}
