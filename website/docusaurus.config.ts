import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

const config: Config = {
  title: 'lazy-md — Terminal Markdown Editor with Vim Keybindings',
  tagline: 'A fast, terminal-based markdown editor written in Zig. Vim-native modal editing, live preview, syntax highlighting, and a plugin system — all with zero dependencies.',
  favicon: 'img/favicon.ico',

  url: 'https://lazymd.com',
  baseUrl: '/',
  trailingSlash: false,

  organizationName: 'user',
  projectName: 'lazy-md',

  onBrokenLinks: 'throw',
  onBrokenMarkdownLinks: 'warn',

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  headTags: [
    {
      tagName: 'meta',
      attributes: {name: 'keywords', content: 'markdown editor, terminal markdown editor, vim markdown editor, zig markdown editor, cli markdown editor, tui markdown editor, lazy-md, lazymd, terminal text editor, vim keybindings, live preview markdown, MCP server markdown'},
    },
    {
      tagName: 'meta',
      attributes: {name: 'author', content: 'lazy-md'},
    },
    {
      tagName: 'link',
      attributes: {rel: 'canonical', href: 'https://lazymd.com'},
    },
    {
      tagName: 'script',
      attributes: {type: 'application/ld+json'},
      innerHTML: JSON.stringify({
        '@context': 'https://schema.org',
        '@type': 'SoftwareApplication',
        name: 'lazy-md',
        url: 'https://lazymd.com',
        description: 'A fast, terminal-based markdown editor with vim keybindings, live preview, syntax highlighting for 16+ languages, and a plugin system. Written in Zig with zero dependencies.',
        applicationCategory: 'DeveloperApplication',
        operatingSystem: 'Linux, macOS',
        offers: {
          '@type': 'Offer',
          price: '0',
          priceCurrency: 'USD',
        },
        license: 'https://opensource.org/licenses/MIT',
        programmingLanguage: 'Zig',
        codeRepository: 'https://github.com/user/lazy-md',
      }),
    },
    {
      tagName: 'script',
      attributes: {type: 'application/ld+json'},
      innerHTML: JSON.stringify({
        '@context': 'https://schema.org',
        '@type': 'WebSite',
        name: 'lazy-md',
        url: 'https://lazymd.com',
        potentialAction: {
          '@type': 'SearchAction',
          target: 'https://lazymd.com/search?q={search_term_string}',
          'query-input': 'required name=search_term_string',
        },
      }),
    },
  ],

  metadata: [
    {name: 'description', content: 'lazy-md is a fast, terminal-based markdown editor with vim keybindings, live preview, syntax highlighting, and a plugin system. Built in Zig with zero dependencies.'},
    {property: 'og:type', content: 'website'},
    {property: 'og:site_name', content: 'lazy-md'},
    {property: 'og:title', content: 'lazy-md — Terminal Markdown Editor with Vim Keybindings'},
    {property: 'og:description', content: 'A fast, terminal-based markdown editor with vim keybindings, live preview, syntax highlighting, and a plugin system. Built in Zig with zero dependencies.'},
    {property: 'og:url', content: 'https://lazymd.com'},
    {name: 'twitter:card', content: 'summary_large_image'},
    {name: 'twitter:title', content: 'lazy-md — Terminal Markdown Editor with Vim Keybindings'},
    {name: 'twitter:description', content: 'A fast, terminal-based markdown editor with vim keybindings, live preview, and zero dependencies. Written in Zig.'},
    {name: 'robots', content: 'index, follow'},
    {name: 'theme-color', content: '#58a6ff'},
  ],

  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
          editUrl: 'https://github.com/user/lazy-md/tree/main/website/',
        },
        blog: {
          showReadingTime: true,
          feedOptions: {
            type: ['rss', 'atom'],
            xslt: true,
          },
          editUrl: 'https://github.com/user/lazy-md/tree/main/website/',
        },
        theme: {
          customCss: './src/css/custom.css',
        },
        sitemap: {
          lastmod: 'date',
          changefreq: 'weekly',
          priority: 0.5,
          filename: 'sitemap.xml',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    colorMode: {
      defaultMode: 'dark',
      disableSwitch: false,
      respectPrefersColorScheme: true,
    },
    navbar: {
      title: 'lazy-md',
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'docsSidebar',
          position: 'left',
          label: 'Docs',
        },
        {to: '/blog', label: 'Blog', position: 'left'},
        {
          href: 'https://github.com/user/lazy-md',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Docs',
          items: [
            {label: 'Getting Started', to: '/docs/getting-started/installation'},
            {label: 'Usage Guide', to: '/docs/usage/editing-modes'},
            {label: 'Plugin System', to: '/docs/plugins/overview'},
            {label: 'MCP Server', to: '/docs/mcp-server/overview'},
          ],
        },
        {
          title: 'Community',
          items: [
            {label: 'GitHub Discussions', href: 'https://github.com/user/lazy-md/discussions'},
            {label: 'Issues', href: 'https://github.com/user/lazy-md/issues'},
          ],
        },
        {
          title: 'More',
          items: [
            {label: 'Blog', to: '/blog'},
            {label: 'GitHub', href: 'https://github.com/user/lazy-md'},
            {label: 'Releases', href: 'https://github.com/user/lazy-md/releases'},
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} lazy-md. Open source under the MIT License.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ['bash', 'zig', 'json', 'yaml'],
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
