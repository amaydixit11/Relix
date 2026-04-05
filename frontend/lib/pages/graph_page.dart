import 'package:flutter/material.dart';
import '../models.dart';
import '../services/relix_controller.dart';
import '../widgets/glass_card.dart';

class GraphPage extends StatefulWidget {
  const GraphPage({super.key, required this.controller});

  final RelixController controller;

  @override
  State<GraphPage> createState() => _GraphPageState();
}

class _GraphPageState extends State<GraphPage> {
  GraphData? _data;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadGraph();
  }

  Future<void> _loadGraph() async {
    setState(() => _loading = true);
    try {
      final data = await widget.controller.graph.getFullGraph();
      if (mounted) setState(() => _data = data);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Knowledge Neural Map',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Visualization of your linked entries and neural connections',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white38,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_loading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF2DD4BF)),
              ),
            )
          else if (_data == null || _data!.nodes.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text(
                  'No neural connections found yet.',
                  style: TextStyle(color: Colors.white10),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final node = _data!.nodes[index];
                  final edges = _data!.edges
                      .where((e) => e.source == node.id || e.target == node.id)
                      .toList();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: GlassCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                node.type == 'note'
                                    ? Icons.description_rounded
                                    : Icons.attach_file_rounded,
                                size: 16,
                                color: const Color(0xFF2DD4BF),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  node.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (edges.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'CONNECTIONS',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                                color: Colors.white24,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: edges.map((e) {
                                final isSource = e.source == node.id;
                                final otherId = isSource ? e.target : e.source;
                                final otherNode = _data!.nodes.firstWhere(
                                  (n) => n.id == otherId,
                                  orElse: () => GraphNode(
                                    id: '',
                                    title: 'Unknown',
                                    type: '',
                                    tags: [],
                                  ),
                                );

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        (isSource
                                                ? Colors.blueAccent
                                                : Colors.purpleAccent)
                                            .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color:
                                          (isSource
                                                  ? Colors.blueAccent
                                                  : Colors.purpleAccent)
                                              .withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isSource
                                            ? Icons.north_east_rounded
                                            : Icons.south_west_rounded,
                                        size: 10,
                                        color: isSource
                                            ? Colors.blueAccent
                                            : Colors.purpleAccent,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        otherNode.title,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: isSource
                                              ? Colors.blueAccent
                                              : Colors.purpleAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }, childCount: _data!.nodes.length),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}
