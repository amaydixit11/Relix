import 'dart:math';
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
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: CustomPaint(painter: _TechnicalGridPainter()),
            ),
          ),
          if (_loading)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else if (_data == null || _data!.nodes.isEmpty)
            const Center(
              child: Text(
                'NO CONNECTIONS INDEXED',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: Colors.white10,
                  letterSpacing: 1,
                ),
              ),
            )
          else
            _InteractiveGraphView(
              data: _data!,
              controller: widget.controller,
            ),
          // Stats overlay
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF131313).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1F1F1F)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'NEURAL NETWORK',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: Color(0xFF7B88FF),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${_data?.nodes.length ?? 0} NODES',
                    style: const TextStyle(
                      fontSize: 9,
                      fontFamily: 'monospace',
                      color: Colors.white54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_data?.edges.length ?? 0} EDGES',
                    style: const TextStyle(
                      fontSize: 9,
                      fontFamily: 'monospace',
                      color: Colors.white54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractiveGraphView extends StatefulWidget {
  const _InteractiveGraphView({
    required this.data,
    required this.controller,
  });

  final GraphData data;
  final RelixController controller;

  @override
  State<_InteractiveGraphView> createState() => _InteractiveGraphViewState();
}

class _InteractiveGraphViewState extends State<_InteractiveGraphView>
    with SingleTickerProviderStateMixin {
  late List<_GraphNodeState> _nodeStates;
  late AnimationController _animController;
  int _tickCount = 0;
  static const _maxTicks = 200; // Stop simulation after settling
  Offset _panOffset = Offset.zero;
  double _scale = 1.0;
  Offset _lastPanPoint = Offset.zero;
  bool _isPanning = false;
  String? _dragNodeId;
  String? _hoveredNodeId;
  String? _selectedNodeId;
  final double _nodeRadius = 30;
  final double _minScale = 0.3;
  final double _maxScale = 3.0;

  @override
  void initState() {
    super.initState();
    _initNodeStates();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(minutes: 10),
    )..addListener(_tick)
      ..repeat();
  }

  void _initNodeStates() {
    final rng = Random(42); // Seed for reproducibility
    _nodeStates = widget.data.nodes.map((node) {
      final angle = rng.nextDouble() * 2 * pi;
      final radius = rng.nextDouble() * 200;
      return _GraphNodeState(
        id: node.id,
        x: cos(angle) * radius,
        y: sin(angle) * radius,
        vx: 0,
        vy: 0,
      );
    }).toList();
  }

  void _tick() {
    if (!mounted || _tickCount >= _maxTicks) {
      _animController.stop();
      return;
    }
    _tickCount++;
    _applyForces(iterations: 1);
    setState(() {});
  }

  void _applyForces({int iterations = 1}) {
    final nodeMap = {for (final n in _nodeStates) n.id: n};
    final edgeList = widget.data.edges;

    for (int iter = 0; iter < iterations; iter++) {
      // Repulsion between all nodes
      for (int i = 0; i < _nodeStates.length; i++) {
        for (int j = i + 1; j < _nodeStates.length; j++) {
          final a = _nodeStates[i];
          final b = _nodeStates[j];
          double dx = b.x - a.x;
          double dy = b.y - a.y;
          double dist = sqrt(dx * dx + dy * dy);
          if (dist < 1) {
            dx = 1;
            dy = 0;
            dist = 1;
          }
          final force = 8000 / (dist * dist);
          final fx = (dx / dist) * force;
          final fy = (dy / dist) * force;
          if (a.id != _dragNodeId) {
            a.vx -= fx;
            a.vy -= fy;
          }
          if (b.id != _dragNodeId) {
            b.vx += fx;
            b.vy += fy;
          }
        }
      }

      // Attraction along edges
      for (final edge in edgeList) {
        final source = nodeMap[edge.source];
        final target = nodeMap[edge.target];
        if (source == null || target == null) continue;

        double dx = target.x - source.x;
        double dy = target.y - source.y;
        double dist = sqrt(dx * dx + dy * dy);
        if (dist < 1) dist = 1;
        final force = (dist - 120) * 0.008;
        final fx = (dx / dist) * force;
        final fy = (dy / dist) * force;
        if (source.id != _dragNodeId) {
          source.vx += fx;
          source.vy += fy;
        }
        if (target.id != _dragNodeId) {
          target.vx -= fx;
          target.vy -= fy;
        }
      }

      // Center gravity
      for (final node in _nodeStates) {
        if (node.id == _dragNodeId) continue;
        node.vx -= node.x * 0.0008;
        node.vy -= node.y * 0.0008;
      }

      // Apply velocities with damping
      for (final node in _nodeStates) {
        if (node.id == _dragNodeId) continue;
        node.vx *= 0.85;
        node.vy *= 0.85;
        // Clamp velocity
        final maxV = 8.0;
        node.vx = node.vx.clamp(-maxV, maxV);
        node.vy = node.vy.clamp(-maxV, maxV);
        node.x += node.vx;
        node.y += node.vy;
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onNodeTap(String nodeId) {
    setState(() {
      _selectedNodeId = _selectedNodeId == nodeId ? null : nodeId;
    });

    // Navigate to note
    final note = widget.controller.snapshot.notes
        .cast<NoteEntry?>()
        .firstWhere((n) => n?.id == nodeId, orElse: () => null);
    if (note != null && mounted) {
      // We signal via the controller's listener — parent picks it up
      // For now, show the note in a dialog as fallback
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF131313),
          title: Text(
            (note.content as NoteContent?)?.title ?? 'Untitled',
            style: const TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 400,
            child: Text(
              (note.content as NoteContent?)?.body ?? '',
              style: const TextStyle(color: Colors.white70),
              maxLines: 10,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final centerX = constraints.maxWidth / 2;
        final centerY = constraints.maxHeight / 2;

        return GestureDetector(
          onScaleStart: (details) {
            _lastPanPoint = details.focalPoint;
          },
          onScaleUpdate: (details) {
            if (details.pointerCount == 1 && !_isPanning) {
              final delta = details.focalPoint - _lastPanPoint;
              setState(() {
                _panOffset += delta;
                _lastPanPoint = details.focalPoint;
              });
            } else if (details.pointerCount >= 2) {
              setState(() {
                _scale = (_scale * details.scale).clamp(_minScale, _maxScale);
              });
            }
          },
          onScaleEnd: (_) {
            _isPanning = false;
          },
          child: Container(
            color: Colors.transparent,
            child: Transform.translate(
              offset: _panOffset,
              child: Transform.scale(
                scale: _scale,
                child: CustomPaint(
                  size: Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  ),
                  painter: _GraphCanvasPainter(
                    nodes: _nodeStates,
                    edges: widget.data.edges,
                    nodeLabels: {
                      for (final node in widget.data.nodes) node.id: node.title
                    },
                    hoveredNodeId: _hoveredNodeId,
                    selectedNodeId: _selectedNodeId,
                    nodeRadius: _nodeRadius,
                    centerX: centerX,
                    centerY: centerY,
                  ),
                  child: Stack(
                    children: [
                      // Hit areas for nodes
                      for (final nodeState in _nodeStates)
                        Positioned(
                          left: centerX + nodeState.x - _nodeRadius,
                          top: centerY + nodeState.y - _nodeRadius,
                          child: GestureDetector(
                            onTap: () => _onNodeTap(nodeState.id),
                            onPanStart: (details) {
                              setState(() => _dragNodeId = nodeState.id);
                            },
                            onPanUpdate: (details) {
                              setState(() {
                                nodeState.x += details.delta.dx / _scale;
                                nodeState.y += details.delta.dy / _scale;
                                nodeState.vx = 0;
                                nodeState.vy = 0;
                              });
                            },
                            onPanEnd: (_) {
                              setState(() => _dragNodeId = null);
                            },
                            child: MouseRegion(
                              onEnter: (_) {
                                setState(
                                  () => _hoveredNodeId = nodeState.id,
                                );
                              },
                              onExit: (_) {
                                if (_hoveredNodeId == nodeState.id) {
                                  setState(() => _hoveredNodeId = null);
                                }
                              },
                              child: SizedBox(
                                width: _nodeRadius * 2,
                                height: _nodeRadius * 2,
                                child: _buildNodeTooltip(nodeState.id),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNodeTooltip(String nodeId) {
    if (_hoveredNodeId != nodeId && _selectedNodeId != nodeId) {
      return const SizedBox.shrink();
    }

    final node = widget.data.nodes.firstWhere(
      (n) => n.id == nodeId,
      orElse: () => GraphNode(
        id: nodeId,
        title: 'Unknown',
        type: 'note',
        tags: [],
      ),
    );

    return Container(
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131313),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF7B88FF)),
      ),
      child: Text(
        node.title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _GraphNodeState {
  _GraphNodeState({
    required this.id,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
  });

  final String id;
  double x, y, vx, vy;
}

class _GraphCanvasPainter extends CustomPainter {
  _GraphCanvasPainter({
    required this.nodes,
    required this.edges,
    required this.nodeLabels,
    required this.hoveredNodeId,
    required this.selectedNodeId,
    required this.nodeRadius,
    required this.centerX,
    required this.centerY,
  });

  final List<_GraphNodeState> nodes;
  final List<GraphEdge> edges;
  final Map<String, String> nodeLabels;
  final String? hoveredNodeId;
  final String? selectedNodeId;
  final double nodeRadius;
  final double centerX;
  final double centerY;

  @override
  void paint(Canvas canvas, Size size) {
    final nodePositions = {for (final n in nodes) n.id: Offset(n.x, n.y)};

    // Draw edges
    final edgePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    final highlightedEdgePaint = Paint()
      ..color = const Color(0xFF7B88FF).withValues(alpha: 0.4)
      ..strokeWidth = 2;

    for (final edge in edges) {
      final sourcePos = nodePositions[edge.source];
      final targetPos = nodePositions[edge.target];
      if (sourcePos == null || targetPos == null) continue;

      final isHighlighted = edge.source == hoveredNodeId ||
          edge.target == hoveredNodeId ||
          edge.source == selectedNodeId ||
          edge.target == selectedNodeId;

      canvas.drawLine(
        Offset(centerX + sourcePos.dx, centerY + sourcePos.dy),
        Offset(centerX + targetPos.dx, centerY + targetPos.dy),
        isHighlighted ? highlightedEdgePaint : edgePaint,
      );
    }

    // Draw nodes
    for (final node in nodes) {
      final cx = centerX + node.x;
      final cy = centerY + node.y;

      final isHovered = node.id == hoveredNodeId;
      final isSelected = node.id == selectedNodeId;
      final radius = isHovered ? nodeRadius + 4 : nodeRadius;

      // Node circle
      final nodePaint = Paint()
        ..color = isSelected
            ? const Color(0xFF7B88FF)
            : isHovered
            ? const Color(0xFFA267F6)
            : const Color(0xFF131313);

      canvas.drawCircle(Offset(cx, cy), radius, nodePaint);

      // Border
      final borderPaint = Paint()
        ..color = isSelected
            ? const Color(0xFF7B88FF)
            : isHovered
            ? const Color(0xFFA267F6)
            : const Color(0xFF1F1F1F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 2.5 : 1.5;

      canvas.drawCircle(Offset(cx, cy), radius, borderPaint);

      // Label (only if zoomed in or hovered)
      final label = nodeLabels[node.id] ?? 'Untitled';
      if (label.isNotEmpty) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: label.length > 20 ? '${label.substring(0, 20)}...' : label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            cx - textPainter.width / 2,
            cy + radius + 6,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GraphCanvasPainter oldDelegate) {
    return oldDelegate.nodes != nodes ||
        oldDelegate.edges != edges ||
        oldDelegate.hoveredNodeId != hoveredNodeId ||
        oldDelegate.selectedNodeId != selectedNodeId;
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
