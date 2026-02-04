import { acorde } from '../client';
import type { Graph, GraphNode, GraphEdge, NoteContent } from '../models';

/**
 * GraphService - Build and query knowledge graph
 */
export class GraphService {
  /**
   * Build complete graph of all notes and their connections
   */
  async getFullGraph(): Promise<Graph> {
    const entries = await acorde.listEntries<NoteContent>({ type: 'note' });
    
    const nodes: GraphNode[] = entries.map((e) => ({
      id: e.id,
      title: e.content.title,
      type: e.type,
      tags: e.tags.filter((t) => !t.startsWith('backlink:') && !t.startsWith('outlink:')),
    }));

    const edges: GraphEdge[] = [];
    const nodeIds = new Set(nodes.map((n) => n.id));

    for (const entry of entries) {
      // Add edges for outlinks
      const outlinks = entry.tags
        .filter((t) => t.startsWith('outlink:'))
        .map((t) => t.replace('outlink:', ''));

      for (const targetId of outlinks) {
        if (nodeIds.has(targetId)) {
          edges.push({
            source: entry.id,
            target: targetId,
            type: 'backlink',
          });
        }
      }
    }

    return { nodes, edges };
  }

  /**
   * Get subgraph around a specific node
   */
  async getNeighbors(id: string, depth = 1): Promise<Graph> {
    const visited = new Set<string>();
    const nodes: GraphNode[] = [];
    const edges: GraphEdge[] = [];

    await this.traverseNeighbors(id, depth, visited, nodes, edges);

    return { nodes, edges };
  }

  /**
   * Get nodes that share tags with given node
   */
  async getRelatedByTags(id: string, limit = 10): Promise<GraphNode[]> {
    const entry = await acorde.getEntry<NoteContent>(id);
    const userTags = entry.tags.filter(
      (t) => !t.startsWith('backlink:') && !t.startsWith('outlink:')
    );

    if (userTags.length === 0) return [];

    // Find notes with matching tags
    const related: Map<string, { node: GraphNode; score: number }> = new Map();

    for (const tag of userTags) {
      const matches = await acorde.listEntries<NoteContent>({ type: 'note', tag });
      for (const match of matches) {
        if (match.id === id) continue;

        const existing = related.get(match.id);
        if (existing) {
          existing.score += 1;
        } else {
          related.set(match.id, {
            node: {
              id: match.id,
              title: match.content.title,
              type: match.type,
              tags: match.tags.filter(
                (t) => !t.startsWith('backlink:') && !t.startsWith('outlink:')
              ),
            },
            score: 1,
          });
        }
      }
    }

    // Sort by score and limit
    return Array.from(related.values())
      .sort((a, b) => b.score - a.score)
      .slice(0, limit)
      .map((r) => r.node);
  }

  // ─────────────────────────────────────────────────────────────
  // Internal helpers
  // ─────────────────────────────────────────────────────────────

  private async traverseNeighbors(
    id: string,
    depth: number,
    visited: Set<string>,
    nodes: GraphNode[],
    edges: GraphEdge[]
  ): Promise<void> {
    if (depth < 0 || visited.has(id)) return;
    visited.add(id);

    try {
      const entry = await acorde.getEntry<NoteContent>(id);
      nodes.push({
        id: entry.id,
        title: entry.content.title,
        type: entry.type,
        tags: entry.tags.filter(
          (t) => !t.startsWith('backlink:') && !t.startsWith('outlink:')
        ),
      });

      // Get outlinks
      const outlinks = entry.tags
        .filter((t) => t.startsWith('outlink:'))
        .map((t) => t.replace('outlink:', ''));

      // Get backlinks
      const backlinks = entry.tags
        .filter((t) => t.startsWith('backlink:'))
        .map((t) => t.replace('backlink:', ''));

      const neighbors = [...new Set([...outlinks, ...backlinks])];

      for (const neighborId of neighbors) {
        edges.push({
          source: id,
          target: neighborId,
          type: 'backlink',
        });

        await this.traverseNeighbors(neighborId, depth - 1, visited, nodes, edges);
      }
    } catch {
      // Note doesn't exist
    }
  }
}

export const graphService = new GraphService();
