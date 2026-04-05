'use client';

import { useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { useGraph } from '@relix/core';
import { PageLayout } from '@/components';

interface PhysicsNode {
  id: string;
  title: string;
  x: number;
  y: number;
  vx: number;
  vy: number;
  radius: number;
}

interface Edge {
  source: string;
  target: string;
}

export default function GraphPage() {
  const router = useRouter();
  const { data: graph, isLoading } = useGraph();
  
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const nodesRef = useRef<PhysicsNode[]>([]);
  const edgesRef = useRef<Edge[]>([]);
  const panStartRef = useRef<{ x: number; y: number; panX: number; panY: number } | null>(null);
  const panMovedRef = useRef(false);
  
  // UI State
  const [search, setSearch] = useState('');
  const [zoom, setZoom] = useState(1);
  const [pan, setPan] = useState({ x: 0, y: 0 });
  const [isPanning, setIsPanning] = useState(false);

  // Initialize
  useEffect(() => {
    if (!graph) return;

    nodesRef.current = graph.nodes.map(n => ({
      ...n,
      x: Math.random() * 800 + 100,
      y: Math.random() * 600 + 100,
      vx: (Math.random() - 0.5) * 5,
      vy: (Math.random() - 0.5) * 5,
      radius: 5,
    }));
    edgesRef.current = graph.edges as Edge[];
  }, [graph]);

  // Simulation & Rendering loop
  useEffect(() => {
    let frameId: number;
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const tick = () => {
      const nodes = nodesRef.current;
      const edges = edgesRef.current;
      if (nodes.length === 0) {
        frameId = requestAnimationFrame(tick);
        return;
      }

      // 1. Force Simulation (In-place on refs)
      // Repulsion
      for (let i = 0; i < nodes.length; i++) {
        for (let j = i + 1; j < nodes.length; j++) {
          const a = nodes[i];
          const b = nodes[j];
          const dx = b.x - a.x;
          const dy = b.y - a.y;
          const d2 = dx * dx + dy * dy + 1;
          const force = 1000 / d2;
          const fx = (dx / Math.sqrt(d2)) * force;
          const fy = (dy / Math.sqrt(d2)) * force;
          a.vx -= fx; a.vy -= fy;
          b.vx += fx; b.vy += fy;
        }
      }

      // Attraction
      const nodeMap = new Map(nodes.map(n => [n.id, n]));
      edges.forEach(e => {
        const s = nodeMap.get(e.source);
        const t = nodeMap.get(e.target);
        if (!s || !t) return;
        const dx = t.x - s.x;
        const dy = t.y - s.y;
        const dist = Math.sqrt(dx * dx + dy * dy) || 1;
        const f = (dist - 150) * 0.05;
        const fx = (dx / dist) * f;
        const fy = (dy / dist) * f;
        s.vx += fx; s.vy += fy;
        t.vx -= fx; t.vy -= fy;
      });

      // Update positions
      const cx = canvas.width / 2;
      const cy = canvas.height / 2;
      nodes.forEach(n => {
        n.vx += (cx - n.x) * 0.005;
        n.vy += (cy - n.y) * 0.005;
        n.vx *= 0.9;
        n.vy *= 0.9;
        n.x += n.vx;
        n.y += n.vy;
      });

      // 2. Clear & Draw
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      ctx.save();
      ctx.translate(pan.x, pan.y);
      ctx.scale(zoom, zoom);

      // Draw Edges
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.1)';
      ctx.lineWidth = 1 / zoom;
      ctx.beginPath();
      edges.forEach(e => {
        const s = nodeMap.get(e.source);
        const t = nodeMap.get(e.target);
        if (s && t) {
          ctx.moveTo(s.x, s.y);
          ctx.lineTo(t.x, t.y);
        }
      });
      ctx.stroke();

      // Draw Nodes
      nodes.forEach(n => {
        const isSelected = search && n.title.toLowerCase().includes(search.toLowerCase());
        ctx.fillStyle = isSelected ? '#6366f1' : 'rgba(255, 255, 255, 0.4)';
        ctx.beginPath();
        ctx.arc(n.x, n.y, n.radius / zoom, 0, Math.PI * 2);
        ctx.fill();
        
        if (nodes.length < 50 || isSelected) {
          ctx.fillStyle = isSelected ? '#fff' : 'rgba(255, 255, 255, 0.6)';
          ctx.font = `${12 / zoom}px Inter, sans-serif`;
          ctx.textAlign = 'center';
          ctx.fillText(n.title, n.x, n.y + 15 / zoom);
        }
      });

      ctx.restore();
      frameId = requestAnimationFrame(tick);
    };

    frameId = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frameId);
  }, [pan, zoom, search]);

  const handleResize = () => {
    if (!canvasRef.current) return;
    canvasRef.current.width = window.innerWidth;
    canvasRef.current.height = window.innerHeight;
  };

  useEffect(() => {
    handleResize();
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  const clampZoom = (value: number) => Math.max(0.35, Math.min(2.5, value));

  const screenToWorld = (clientX: number, clientY: number) => {
    const rect = canvasRef.current?.getBoundingClientRect();
    if (!rect) return null;

    return {
      x: (clientX - rect.left - pan.x) / zoom,
      y: (clientY - rect.top - pan.y) / zoom,
    };
  };

  const handlePointerDown = (event: React.MouseEvent<HTMLCanvasElement>) => {
    if (event.button !== 0) return;
    panMovedRef.current = false;
    panStartRef.current = {
      x: event.clientX,
      y: event.clientY,
      panX: pan.x,
      panY: pan.y,
    };
    setIsPanning(true);
  };

  const handlePointerMove = (event: React.MouseEvent<HTMLCanvasElement>) => {
    if (!panStartRef.current) return;
    const deltaX = event.clientX - panStartRef.current.x;
    const deltaY = event.clientY - panStartRef.current.y;
    if (Math.abs(deltaX) > 3 || Math.abs(deltaY) > 3) {
      panMovedRef.current = true;
    }
    setPan({
      x: panStartRef.current.panX + deltaX,
      y: panStartRef.current.panY + deltaY,
    });
  };

  const endPan = () => {
    panStartRef.current = null;
    setIsPanning(false);
  };

  const handleWheel = (event: React.WheelEvent<HTMLCanvasElement>) => {
    event.preventDefault();
    const worldPoint = screenToWorld(event.clientX, event.clientY);
    if (!worldPoint) return;

    const nextZoom = clampZoom(zoom * (event.deltaY < 0 ? 1.1 : 0.9));
    const rect = canvasRef.current?.getBoundingClientRect();
    if (!rect) return;

    setPan({
      x: event.clientX - rect.left - worldPoint.x * nextZoom,
      y: event.clientY - rect.top - worldPoint.y * nextZoom,
    });
    setZoom(nextZoom);
  };

  return (
    <PageLayout noPadding>
      <div style={{ position: 'relative', width: '100%', height: '100%', background: '#0a0a0a', overflow: 'hidden' }}>
        <canvas 
          ref={canvasRef} 
          style={{ cursor: isPanning ? 'grabbing' : 'grab', display: 'block' }}
          onMouseDown={handlePointerDown}
          onMouseMove={handlePointerMove}
          onMouseUp={endPan}
          onMouseLeave={endPan}
          onWheel={handleWheel}
          onClick={(e) => {
            if (panMovedRef.current) return;
            const worldPoint = screenToWorld(e.clientX, e.clientY);
            if (!worldPoint) return;
            const { x, y } = worldPoint;
            const clicked = nodesRef.current.find(n => {
              const dx = n.x - x;
              const dy = n.y - y;
              return Math.sqrt(dx * dx + dy * dy) < 20 / zoom;
            });
            if (clicked) router.push(`/notes/${clicked.id}`);
          }}
        />
        
        {/* Overlay Controls */}
        <div style={{ position: 'absolute', top: 20, left: 20, zIndex: 10 }}>
          <div style={{ display: 'grid', gap: 12 }}>
            <input 
              value={search}
              onChange={e => setSearch(e.target.value)}
              placeholder="Search graph..."
              style={{ 
                background: 'rgba(255,255,255,0.05)', 
                border: '1px solid rgba(255,255,255,0.1)',
                backdropFilter: 'blur(10px)',
                color: '#fff',
                padding: '8px 16px',
                borderRadius: '8px',
                width: '250px'
              }}
            />
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: 8,
                background: 'rgba(9, 9, 11, 0.72)',
                border: '1px solid rgba(255,255,255,0.1)',
                borderRadius: 12,
                padding: 8,
                width: 'fit-content',
              }}
            >
              <button
                onClick={() => setZoom((value) => clampZoom(value * 0.9))}
                style={{ minWidth: 36 }}
              >
                -
              </button>
              <span style={{ minWidth: 64, textAlign: 'center', color: '#fff', fontSize: 12 }}>
                {(zoom * 100).toFixed(0)}%
              </span>
              <button
                onClick={() => setZoom((value) => clampZoom(value * 1.1))}
                style={{ minWidth: 36 }}
              >
                +
              </button>
              <button
                onClick={() => {
                  setZoom(1);
                  setPan({ x: 0, y: 0 });
                }}
              >
                Reset
              </button>
            </div>
          </div>
        </div>
      </div>
    </PageLayout>
  );
}
