'use client';

import { useEffect, useRef, useState, useMemo } from 'react';
import { useRouter } from 'next/navigation';
import { useGraph } from '@relix/core';
import { PageLayout } from '@/components';

interface Node extends Record<string, any> {
  id: string;
  title: string;
  x: number;
  y: number;
  vx: number;
  vy: number;
}

export default function GraphPage() {
  const router = useRouter();
  const { data: graph, isLoading } = useGraph();
  
  // Simulation State
  const [nodes, setNodes] = useState<Node[]>([]);
  const [edges, setEdges] = useState<any[]>([]);
  
  // UI State
  const [search, setSearch] = useState('');
  const [zoom, setZoom] = useState(1);
  const [pan, setPan] = useState({ x: 0, y: 0 });
  const [isDragging, setIsDragging] = useState(false);
  const [dragStart, setDragStart] = useState({ x: 0, y: 0 });
  const [hoveredNode, setHoveredNode] = useState<string | null>(null);

  // Initialize nodes and edges
  useEffect(() => {
    if (!graph) return;

    const initialNodes = graph.nodes.map((n) => ({
      ...n,
      x: Math.random() * 800 + 100,
      y: Math.random() * 600 + 100,
      vx: 0,
      vy: 0,
    } as Node));

    setNodes(initialNodes);
    setEdges(graph.edges);
  }, [graph]);

  // Force Simulation Loop
  useEffect(() => {
    if (nodes.length === 0 || isDragging) return;

    let frameId: number;
    
    const tick = () => {
      setNodes(prevNodes => {
        const nextNodes = prevNodes.map(n => ({ ...n }));
        const nodeMap = new Map(nextNodes.map(n => [n.id, n]));

        // 1. Repulsion (Charge)
        for (let i = 0; i < nextNodes.length; i++) {
          for (let j = i + 1; j < nextNodes.length; j++) {
            const nodeA = nextNodes[i];
            const nodeB = nextNodes[j];
            const dx = nodeB.x - nodeA.x;
            const dy = nodeB.y - nodeA.y;
            const distSq = dx * dx + dy * dy + 100;
            const force = 3000 / distSq;
            const fx = (dx / Math.sqrt(distSq)) * force;
            const fy = (dy / Math.sqrt(distSq)) * force;
            
            nodeA.vx -= fx;
            nodeA.vy -= fy;
            nodeB.vx += fx;
            nodeB.vy += fy;
          }
        }

        // 2. Attraction (Links)
        edges.forEach(edge => {
          const source = nodeMap.get(edge.source);
          const target = nodeMap.get(edge.target);
          if (!source || !target) return;

          const dx = target.x - source.x;
          const dy = target.y - source.y;
          const distance = Math.sqrt(dx * dx + dy * dy) || 1;
          const strength = 0.08;
          const force = (distance - 140) * strength;
          const fx = (dx / distance) * force;
          const fy = (dy / distance) * force;

          source.vx += fx;
          source.vy += fy;
          target.vx -= fx;
          target.vy -= fy;
        });

        // 3. Centering & Friction
        const centerX = 500;
        const centerY = 400;
        nextNodes.forEach(n => {
          n.vx += (centerX - n.x) * 0.005;
          n.vy += (centerY - n.y) * 0.005;
          
          n.vx *= 0.85;
          n.vy *= 0.85;
          
          n.x += n.vx;
          n.y += n.vy;
        });

        return nextNodes;
      });

      frameId = requestAnimationFrame(tick);
    };

    frameId = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frameId);
  }, [edges, nodes.length, isDragging]);

  const filteredNodes = useMemo(() => 
    nodes.filter(n => !search || n.title.toLowerCase().includes(search.toLowerCase())),
    [nodes, search]
  );
  
  const filteredEdges = useMemo(() => {
    const nodeIds = new Set(filteredNodes.map(n => n.id));
    return edges
      .map(e => ({
        ...e,
        sourceNode: nodes.find(n => n.id === e.source),
        targetNode: nodes.find(n => n.id === e.target),
      }))
      .filter(e => nodeIds.has(e.source) && nodeIds.has(e.target) && e.sourceNode && e.targetNode);
  }, [edges, filteredNodes, nodes]);

  return (
    <PageLayout noPadding>
      <div style={{ position: 'relative', height: '100%', width: '100%', overflow: 'hidden', background: 'var(--bg-primary)' }}>
        
        {/* Graph Controls Overlay */}
        <div style={{
          position: 'absolute',
          top: '1.5rem',
          left: '1.5rem',
          zIndex: 10,
          background: 'var(--bg-secondary)',
          backdropFilter: 'blur(10px)',
          border: '1px solid var(--border)',
          borderRadius: '12px',
          padding: '1rem',
          display: 'flex',
          flexDirection: 'column',
          gap: '0.75rem',
          boxShadow: '0 10px 30px rgba(0,0,0,0.3)',
          width: '260px',
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '4px' }}>
            <span style={{ fontSize: '1.2rem' }}>🕸️</span>
            <h2 style={{ fontSize: '0.95rem', fontWeight: 600 }}>Knowledge Graph</h2>
          </div>
          
          <input
            type="text"
            placeholder="Search nodes..."
            value={search}
            onChange={e => setSearch(e.target.value)}
            style={{ 
              fontSize: '0.85rem',
              background: 'rgba(0,0,0,0.2)',
              border: '1px solid var(--border)',
              width: '100%'
            }}
          />
          
          <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.75rem', color: 'var(--text-muted)' }}>
            <span>{filteredNodes.length} nodes</span>
            <span>{Math.round(zoom * 100)}% zoom</span>
          </div>
          
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '8px' }}>
            <button onClick={() => setZoom(z => z * 1.2)} style={{ padding: '6px' }}>+</button>
            <button onClick={() => setZoom(z => z / 1.2)} style={{ padding: '6px' }}>-</button>
            <button onClick={() => { setZoom(1); setPan({ x: 0, y: 0 }); }} style={{ padding: '6px', fontSize: '0.7rem' }}>Reset</button>
          </div>
        </div>

        {/* Legend */}
        <div style={{
          position: 'absolute',
          bottom: '1.5rem',
          right: '1.5rem',
          background: 'rgba(0,0,0,0.3)',
          padding: '8px 12px',
          borderRadius: '8px',
          fontSize: '0.75rem',
          color: 'var(--text-muted)',
          zIndex: 10,
        }}>
          Scroll to zoom • Drag to pan • Click to open
        </div>

        {/* SVG Area */}
        <div 
          style={{ width: '100%', height: '100%', cursor: isDragging ? 'grabbing' : 'grab' }}
          onMouseDown={e => {
            setIsDragging(true);
            setDragStart({ x: e.clientX - pan.x, y: e.clientY - pan.y });
          }}
          onMouseMove={e => {
            if (isDragging) {
              setPan({ x: e.clientX - dragStart.x, y: e.clientY - dragStart.y });
            }
          }}
          onMouseUp={() => setIsDragging(false)}
          onMouseLeave={() => setIsDragging(false)}
          onWheel={e => {
            const delta = e.deltaY > 0 ? 0.9 : 1.1;
            setZoom(z => Math.min(Math.max(z * delta, 0.2), 5));
          }}
        >
          {isLoading ? (
            <div style={{ height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <span className="animate-pulse">Loading graph...</span>
            </div>
          ) : filteredNodes.length > 0 ? (
            <svg 
              width="100%" 
              height="100%"
              style={{ pointerEvents: 'none' }}
            >
              <g transform={`translate(${pan.x}, ${pan.y}) scale(${zoom})`}>
                {/* Edges */}
                {filteredEdges.map((edge, i) => (
                  <line
                    key={`${edge.source}-${edge.target}-${i}`}
                    x1={edge.sourceNode?.x}
                    y1={edge.sourceNode?.y}
                    x2={edge.targetNode?.x}
                    y2={edge.targetNode?.y}
                    stroke="var(--border)"
                    strokeWidth={1 / zoom}
                    opacity={0.3}
                  />
                ))}

                {/* Nodes */}
                {filteredNodes.map(node => {
                  const isHovered = hoveredNode === node.id;
                  const isConnected = hoveredNode && (
                    filteredEdges.some(e => e.source === node.id && e.target === hoveredNode) ||
                    filteredEdges.some(e => e.target === node.id && e.source === hoveredNode)
                  );

                  return (
                    <g 
                      key={node.id} 
                      style={{ cursor: 'pointer', pointerEvents: 'all' }}
                      onMouseEnter={() => setHoveredNode(node.id)}
                      onMouseLeave={() => setHoveredNode(null)}
                      onClick={() => router.push(`/notes/${node.id}`)}
                    >
                      <circle
                        cx={node.x}
                        cy={node.y}
                        r={isHovered ? 8 : 4}
                        fill={isHovered ? 'var(--accent)' : isConnected ? 'var(--accent-cyan)' : 'var(--text-muted)'}
                        style={{ 
                          transition: 'all 0.23s',
                          filter: isHovered || isConnected ? 'drop-shadow(0 0 4px var(--accent))' : 'none'
                        }}
                      />
                      {(isHovered || isConnected || filteredNodes.length < 20) && (
                        <text
                          x={node.x}
                          y={node.y + 16}
                          textAnchor="middle"
                          fill={isHovered ? 'var(--text-primary)' : 'var(--text-secondary)'}
                          fontSize={12 / zoom}
                          style={{ pointerEvents: 'none', fontWeight: isHovered ? 600 : 400 }}
                        >
                          {node.title}
                        </text>
                      )}
                    </g>
                  );
                })}
              </g>
            </svg>
          ) : (
             <div style={{ 
               height: '100%', 
               display: 'flex', 
               alignItems: 'center', 
               justifyContent: 'center', 
               color: 'var(--text-muted)' 
             }}>
               No notes found in your garden yet.
             </div>
          )}
        </div>
      </div>
    </PageLayout>
  );
}
