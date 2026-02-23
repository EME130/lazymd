// Editor state types

export interface EditorState {
  content: string;
  filePath: string | null;
  cursorRow: number;
  cursorCol: number;
  mode: 'normal' | 'insert' | 'command';
  dirty: boolean;
}

export interface Heading {
  level: number;
  title: string;
  line: number;
}

export interface GraphNode {
  id: number;
  name: string;
  file: string;
  outLinks: number;
  inLinks: number;
}

export interface GraphEdge {
  from: number;
  to: number;
}

export interface GraphData {
  nodes: GraphNode[];
  edges: GraphEdge[];
  stats: {
    totalNodes: number;
    totalEdges: number;
    orphans: number;
  };
}

export type ConnectionStatus = 'disconnected' | 'connecting' | 'connected' | 'error';
