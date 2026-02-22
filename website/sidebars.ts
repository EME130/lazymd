import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  docsSidebar: [
    {
      type: 'category',
      label: 'Getting Started',
      items: [
        'getting-started/installation',
        'getting-started/quick-start',
        'getting-started/first-file',
      ],
    },
    {
      type: 'category',
      label: 'Usage',
      items: [
        'usage/editing-modes',
        'usage/navigation',
        'usage/editing',
        'usage/commands',
        'usage/panels-layout',
        'usage/brain-graph',
        'usage/mouse-support',
      ],
    },
    {
      type: 'category',
      label: 'Configuration',
      items: [
        'configuration/file-formats',
        'configuration/themes',
      ],
    },
    {
      type: 'category',
      label: 'Plugins',
      items: [
        'plugins/overview',
        'plugins/catalog',
        'plugins/development',
        'plugins/api-reference',
      ],
    },
    {
      type: 'category',
      label: 'Architecture',
      items: [
        'architecture/system-design',
        'architecture/module-reference',
      ],
    },
    {
      type: 'category',
      label: 'Contributing',
      items: [
        'contributing/how-to-contribute',
        'contributing/building',
        'contributing/testing',
      ],
    },
    {
      type: 'category',
      label: 'MCP Server',
      items: [
        'mcp-server/overview',
      ],
    },
  ],
};

export default sidebars;
