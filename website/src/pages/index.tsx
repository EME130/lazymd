import React from 'react';
import Layout from '@theme/Layout';
import Head from '@docusaurus/Head';
import Link from '@docusaurus/Link';
import TerminalDemo from '@site/src/components/TerminalDemo';
import s from './index.module.css';

function Hero(): React.JSX.Element {
  return (
    <header className={s.hero}>
      <div className={s.heroGlow} />
      <div className={s.heroInner}>
        <div className={s.heroTag}>
          <span className={s.heroTagDot} />
          Written in Zig. Zero dependencies.
        </div>
        <h1 className={s.heroTitle}>
          Markdown editing,<br />
          reimagined for<br />
          the terminal.
        </h1>
        <p className={s.heroSubtitle}>
          A vim-native markdown editor with live preview, syntax highlighting,
          and AI agent integration. Fast by default.
        </p>
        <div className={s.heroActions}>
          <Link className={s.btnPrimary} to="/docs/getting-started/installation">
            Get Started
          </Link>
          <Link className={s.btnSecondary} to="/docs/getting-started/quick-start">
            Documentation
          </Link>
        </div>
      </div>
    </header>
  );
}

function SocialProof(): React.JSX.Element {
  return (
    <section className={s.socialProof}>
      <div className={s.socialProofInner}>
        <span className={s.badge}>
          <span className={s.badgeIcon}>&#9889;</span> Built with Zig
        </span>
        <span className={s.divider} />
        <span className={s.badge}>
          <span className={s.badgeIcon}>&#128268;</span> MCP Protocol
        </span>
        <span className={s.divider} />
        <span className={s.badge}>
          <span className={s.badgeIcon}>&#9000;</span> Vim Keybindings
        </span>
        <span className={s.divider} />
        <span className={s.badge}>
          <span className={s.badgeIcon}>&#128230;</span> Single Binary
        </span>
        <span className={s.divider} />
        <span className={s.badge}>
          <span className={s.badgeIcon}>&#129504;</span> Knowledge Graph
        </span>
      </div>
    </section>
  );
}

const features = [
  {icon: '\u2328', title: 'Vim-Native Editing', desc: 'Full modal editing with Normal, Insert, and Command modes. Navigate with hjkl, motions with w/b, delete with dd, undo with u \u2014 muscle-memory compatible.', wide: false},
  {icon: '\u25CE', title: 'Live Preview', desc: 'Rendered markdown in a side panel. Headers, bold, italic, code blocks with syntax highlighting \u2014 all updating as you type.', wide: false},
  {icon: '\u2588', title: 'Multi-Panel Layout', desc: 'Inspired by lazygit \u2014 file tree, editor, preview, and brain graph side by side. Toggle panels with Alt+1/2/3.', wide: false},
  {icon: '\u2726', title: 'Syntax Highlighting', desc: 'Built-in highlighting for Zig, Python, JavaScript, TypeScript, Rust, Go, C, C++, Java, and 16+ languages. Theme-aware colors with a pluggable highlighter backend.', wide: true},
  {icon: '\u2699', title: 'Plugin System', desc: 'Register custom commands, hook into editor events, add panels. Build and share community plugins.', wide: false},
  {icon: '\u2192', title: 'Zero Dependencies', desc: 'Pure Zig using only POSIX termios and ANSI escape codes. No runtime dependencies. Fast startup, tiny single binary.', wide: false},
  {icon: '\u2387', title: 'Mouse Support', desc: 'Click to position cursor, scroll with mouse wheel, click panels to focus. Works in iTerm2, Alacritty, kitty, and more.', wide: false},
  {icon: '\u2B21', title: 'MCP Server', desc: 'Built-in Model Context Protocol server with 22 tools. AI agents like Claude Code and Gemini CLI connect via JSON-RPC 2.0 over stdio.', wide: false},
  {icon: '\u{1F9E0}', title: 'Brain: Knowledge Graph', desc: 'Obsidian-style graph view for [[wiki-links]]. Visualize connections between notes with a force-directed ASCII layout. Navigate, explore backlinks, and find orphan notes.', wide: true},
  {icon: '\u26A1', title: 'Instant Startup', desc: 'Compiles to a single ~2MB binary. Launches in milliseconds, even on large files. No JVM, no Electron, no wait.', wide: false},
];

function Features(): React.JSX.Element {
  return (
    <section className={s.sectionAlt} id="features">
      <div className={s.container}>
        <div style={{textAlign: 'center'}}>
          <span className={s.sectionLabel}>Features</span>
        </div>
        <h2 className={s.sectionTitle}>Everything you need,<br />nothing you don't.</h2>
        <p className={s.sectionDesc}>
          Built for developers who live in the terminal. If you use vim, tmux, and the command line daily, lazy-md fits right in.
        </p>
        <div className={s.featureGrid}>
          {features.map(({icon, title, desc, wide}) => (
            <article key={title} className={`${s.featureCard} ${wide ? s.featureCardWide : ''}`}>
              <div className={s.featureIcon}>{icon}</div>
              <h3>{title}</h3>
              <p>{desc}</p>
            </article>
          ))}
        </div>
      </div>
    </section>
  );
}

function Install(): React.JSX.Element {
  return (
    <section className={s.section} id="installation">
      <div className={s.container}>
        <div style={{textAlign: 'center'}}>
          <span className={s.sectionLabel}>Get Started</span>
        </div>
        <h2 className={s.sectionTitle}>Up and running in seconds.</h2>
        <p className={s.sectionDesc}>
          Compiles to a single binary with zero runtime dependencies.
        </p>
        <div className={s.installGrid}>
          <div className={s.installCard}>
            <div className={s.installStep}>1</div>
            <h3>Prerequisites</h3>
            <p>Install <a href="https://ziglang.org/download/">Zig</a> 0.15.1 or later from the official site.</p>
          </div>
          <div className={s.installCard}>
            <div className={s.installStep}>2</div>
            <h3>Build</h3>
            <div className={s.codeBlock}>
              <code>{`git clone https://github.com/\nuser/lazy-md.git\ncd lazy-md && zig build`}</code>
            </div>
          </div>
          <div className={s.installCard}>
            <div className={s.installStep}>3</div>
            <h3>Run</h3>
            <div className={s.codeBlock}>
              <code>{`./zig-out/bin/lazy-md myfile.md`}</code>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

function Keybindings(): React.JSX.Element {
  return (
    <section className={s.sectionAlt} id="keybindings">
      <div className={s.container}>
        <div style={{textAlign: 'center'}}>
          <span className={s.sectionLabel}>Keybindings</span>
        </div>
        <h2 className={s.sectionTitle}>The vim bindings you already know.</h2>
        <p className={s.sectionDesc}>
          No learning curve if you use vim or neovim. Jump right in.
        </p>
        <div className={s.keybindingTables}>
          <div className={s.keybindingCard}>
            <h3>Navigation</h3>
            <table>
              <tbody>
                <tr><td><kbd>h</kbd> <kbd>j</kbd> <kbd>k</kbd> <kbd>l</kbd></td><td>Move cursor</td></tr>
                <tr><td><kbd>w</kbd> <kbd>b</kbd> <kbd>e</kbd></td><td>Word motions</td></tr>
                <tr><td><kbd>0</kbd> <kbd>$</kbd> <kbd>^</kbd></td><td>Line start / end</td></tr>
                <tr><td><kbd>gg</kbd> <kbd>G</kbd></td><td>Top / bottom of file</td></tr>
                <tr><td><kbd>Ctrl+D</kbd> <kbd>Ctrl+U</kbd></td><td>Half-page scroll</td></tr>
              </tbody>
            </table>
          </div>
          <div className={s.keybindingCard}>
            <h3>Editing</h3>
            <table>
              <tbody>
                <tr><td><kbd>i</kbd> <kbd>a</kbd> <kbd>o</kbd> <kbd>O</kbd></td><td>Enter insert mode</td></tr>
                <tr><td><kbd>x</kbd></td><td>Delete character</td></tr>
                <tr><td><kbd>dd</kbd></td><td>Delete line</td></tr>
                <tr><td><kbd>u</kbd></td><td>Undo</td></tr>
                <tr><td><kbd>Ctrl+R</kbd></td><td>Redo</td></tr>
              </tbody>
            </table>
          </div>
          <div className={s.keybindingCard}>
            <h3>Commands</h3>
            <table>
              <tbody>
                <tr><td><kbd>:w</kbd></td><td>Save file</td></tr>
                <tr><td><kbd>:q</kbd></td><td>Quit editor</td></tr>
                <tr><td><kbd>:wq</kbd></td><td>Save and quit</td></tr>
                <tr><td><kbd>Tab</kbd></td><td>Cycle panels</td></tr>
                <tr><td><kbd>Alt+1</kbd> <kbd>Alt+2</kbd> <kbd>Alt+3</kbd></td><td>Toggle panels</td></tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </section>
  );
}

const mcpTools = [
  'open_file', 'read_document', 'write_document', 'list_headings',
  'edit_section', 'read_section', 'list_tasks', 'update_task',
  'get_breadcrumb', 'move_section', 'search_content', 'get_structure',
  'list_links', 'get_backlinks', 'get_graph',
  'get_neighbors', 'find_path', 'get_orphans', 'get_hub_notes',
];

function MCPSection(): React.JSX.Element {
  return (
    <section className={s.section} id="mcp-server">
      <div className={s.container}>
        <div style={{textAlign: 'center'}}>
          <span className={s.sectionLabel}>AI Integration</span>
        </div>
        <h2 className={s.sectionTitle}>An MCP server, built in.</h2>
        <p className={s.sectionDesc}>
          AI agents connect via stdio to read, navigate, and edit markdown documents programmatically.
        </p>
        <div className={s.mcpGrid}>
          <div className={s.mcpContent}>
            <h3>22 tools over JSON-RPC 2.0</h3>
            <p>
              Document tools for reading, writing, and searching. Navigation tools for
              heading-based traversal, task management, and section manipulation.
              Brain tools for wiki-link analysis, backlink discovery, and graph queries.
            </p>
            <div className={s.mcpTools}>
              {mcpTools.map(t => <span key={t} className={s.mcpTool}>{t}</span>)}
            </div>
            <Link className={s.btnSecondary} to="/docs/mcp-server/overview">
              MCP Documentation
            </Link>
          </div>
          <div className={s.mcpCode}>
            <div className={s.mcpCodeHeader}>
              <span className={`${s.mcpCodeTab} ${s.mcpCodeTabActive}`}>Claude Code</span>
              <span className={s.mcpCodeTab}>Gemini CLI</span>
            </div>
            <div className={s.mcpCodeBody}>
              <code>{`# Add lazy-md as an MCP server
claude mcp add lazy-md -- \\
  /path/to/lazy-md --mcp-server

# Start with a file preloaded
lazy-md --mcp-server myfile.md`}</code>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

function CTASection(): React.JSX.Element {
  return (
    <section className={s.ctaSection}>
      <div className={s.ctaGlow} />
      <h2 className={s.ctaTitle}>Ready to try lazy-md?</h2>
      <p className={s.ctaDesc}>
        Open source, MIT licensed, and built to last.
      </p>
      <div className={s.heroActions}>
        <Link className={s.btnPrimary} to="/docs/getting-started/installation">
          Get Started
        </Link>
        <Link className={s.btnSecondary} to="https://github.com/user/lazy-md">
          Star on GitHub
        </Link>
      </div>
    </section>
  );
}

export default function Home(): React.JSX.Element {
  return (
    <Layout
      title="Terminal Markdown Editor with Vim Keybindings"
      description="lazy-md is a fast, terminal-based markdown editor with vim keybindings, live preview, syntax highlighting for 16+ languages, and a plugin system. Written in Zig with zero dependencies. Also works as an MCP server for AI agents.">
      <Head>
        <html lang="en" />
      </Head>
      <main>
        <Hero />
        <div className={s.terminalDemo}>
          <TerminalDemo />
        </div>
        <SocialProof />
        <Features />
        <Install />
        <Keybindings />
        <MCPSection />
        <CTASection />
      </main>
    </Layout>
  );
}
