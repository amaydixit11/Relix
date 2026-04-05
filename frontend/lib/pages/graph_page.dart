import 'package:flutter/material.dart';
import '../models.dart';
import '../services/relix_controller.dart';

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
      body: Stack(
        children: [
          // Background Tech Grid
          Positioned.fill(
            child: Opacity(
              opacity: 0.1,
              child: CustomPaint(painter: _TechnicalGridPainter()),
            ),
          ),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 40,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NEURAL NETWORK',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: Color(0xFF7B88FF),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Knowledge Topology',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _statMicro(
                            'NODES',
                            _data?.nodes.length.toString() ?? '...',
                          ),
                          const SizedBox(width: 24),
                          _statMicro(
                            'EDGES',
                            _data?.edges.length.toString() ?? '...',
                          ),
                          const SizedBox(width: 24),
                          _statMicro('DENSITY', _calculateDensity()),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (_data == null || _data!.nodes.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'NO CONNECTIONS INDEXED',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: Colors.white10,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 400,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 1.8,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final node = _data!.nodes[index];
                      final edges = _data!.edges
                          .where(
                            (e) => e.source == node.id || e.target == node.id,
                          )
                          .toList();

                      return _buildNodeCard(node, edges);
                    }, childCount: _data!.nodes.length),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statMicro(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: Colors.white24,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  String _calculateDensity() {
    if (_data == null || _data!.nodes.isEmpty) return '0.00';
    final n = _data!.nodes.length;
    final e = _data!.edges.length;
    if (n < 2) return '0.00';
    final maxE = n * (n - 1) / 2;
    return (e / maxE).toStringAsFixed(2);
  }

  Widget _buildNodeCard(GraphNode node, List<GraphEdge> edges) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131313),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F1F1F)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.hub_outlined,
                size: 14,
                color: Color(0xFFA267F6),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  node.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            node.id.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 9,
              color: Colors.white10,
            ),
          ),
          const Spacer(),
          const Divider(color: Color(0xFF1F1F1F)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'LINKAGES',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: Colors.white24,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Text(
                '${edges.length} ACTIVE',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF7B88FF),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TechnicalGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1;

    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }

    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.2);
    for (double i = 0; i < size.width; i += 40) {
      for (double j = 0; j < size.height; j += 40) {
        canvas.drawCircle(Offset(i, j), 1, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
