import { useEffect, useRef, useCallback, useState } from 'react';
import * as d3 from 'd3-force';
import type { GraphData, GraphNode } from '../types/editor';
import { client } from '../protocol/client';

interface SimNode extends GraphNode {
  x: number;
  y: number;
  vx: number;
  vy: number;
}

interface Props {
  connected: boolean;
}

export function BrainGraph({ connected }: Props) {
  const svgRef = useRef<SVGSVGElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const [data, setData] = useState<GraphData | null>(null);
  const animRef = useRef<number>();

  const fetchGraph = useCallback(async () => {
    if (!connected) return;
    try {
      const result = await client.callTool('get_graph') as { content?: Array<{ text: string }> };
      if (result?.content?.[0]?.text) {
        const parsed = JSON.parse(result.content[0].text) as GraphData;
        setData(parsed);
      }
    } catch {
      // graph tool not available
    }
  }, [connected]);

  useEffect(() => {
    fetchGraph();
  }, [fetchGraph]);

  useEffect(() => {
    if (!data || !svgRef.current || !containerRef.current) return;

    const svg = svgRef.current;
    const rect = containerRef.current.getBoundingClientRect();
    const width = rect.width || 600;
    const height = rect.height || 400;

    const nodes: SimNode[] = data.nodes.map(n => ({
      ...n,
      x: width / 2 + (Math.random() - 0.5) * 200,
      y: height / 2 + (Math.random() - 0.5) * 200,
      vx: 0,
      vy: 0,
    }));

    const nodeMap = new Map(nodes.map(n => [n.id, n]));

    const links = data.edges
      .filter(e => nodeMap.has(e.from) && nodeMap.has(e.to))
      .map(e => ({
        source: nodeMap.get(e.from)!,
        target: nodeMap.get(e.to)!,
      }));

    const simulation = d3.forceSimulation(nodes)
      .force('charge', d3.forceManyBody().strength(-120))
      .force('center', d3.forceCenter(width / 2, height / 2))
      .force('link', d3.forceLink(links).distance(80))
      .force('collision', d3.forceCollide().radius(25))
      .on('tick', render);

    function render() {
      while (svg.firstChild) svg.removeChild(svg.firstChild);

      for (const link of links) {
        const line = document.createElementNS('http://www.w3.org/2000/svg', 'line');
        line.setAttribute('x1', String((link.source as SimNode).x));
        line.setAttribute('y1', String((link.source as SimNode).y));
        line.setAttribute('x2', String((link.target as SimNode).x));
        line.setAttribute('y2', String((link.target as SimNode).y));
        line.setAttribute('class', 'brain-graph__edge');
        svg.appendChild(line);
      }

      for (const node of nodes) {
        const g = document.createElementNS('http://www.w3.org/2000/svg', 'g');
        g.setAttribute('class', 'brain-graph__node');
        g.setAttribute('transform', `translate(${node.x},${node.y})`);

        const circle = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
        const r = 4 + Math.min(node.outLinks + node.inLinks, 10);
        circle.setAttribute('r', String(r));
        circle.setAttribute('fill', 'var(--accent)');
        circle.setAttribute('opacity', '0.8');
        g.appendChild(circle);

        const text = document.createElementNS('http://www.w3.org/2000/svg', 'text');
        text.setAttribute('dy', String(r + 14));
        text.setAttribute('text-anchor', 'middle');
        text.textContent = node.name;
        g.appendChild(text);

        svg.appendChild(g);
      }
    }

    return () => {
      simulation.stop();
      if (animRef.current) cancelAnimationFrame(animRef.current);
    };
  }, [data]);

  if (!data) {
    return (
      <div className="brain-graph" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <span style={{ color: 'var(--text-muted)' }}>
          {connected ? 'Loading graph\u2026' : 'Connect to view brain graph'}
        </span>
      </div>
    );
  }

  return (
    <div className="brain-graph" ref={containerRef}>
      <svg ref={svgRef} role="img" aria-label={`Knowledge graph: ${data.stats.totalNodes} notes, ${data.stats.totalEdges} links`} />
      <div className="brain-graph__stats">
        {data.stats.totalNodes} notes, {data.stats.totalEdges} links, {data.stats.orphans} orphans
      </div>
    </div>
  );
}
