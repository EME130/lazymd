import React from 'react';
import Layout from '@theme/Layout';
import Head from '@docusaurus/Head';
import Link from '@docusaurus/Link';
import TerminalDemo from '@site/src/components/TerminalDemo';
import s from './index.module.css';

function Hero(): React.JSX.Element {
  return (
    <header className={s.hero}>
      <div>
        <h1 className={s.heroTitle}>lazy-md</h1>
        <p className={s.heroSubtitle}>
          The terminal-based markdown editor with vim keybindings.<br />
          Fast. Vim-native. Zero dependencies.
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

const features = [
  {icon: '\u2328\uFE0F', title: 'Vim-Native Modal Editing', desc: 'Full vim keybindings with Normal, Insert, and Command modes. Navigate with hjkl, move by word with w/b, delete lines with dd, undo with u, and more — all muscle-memory compatible with vim and neovim.'},
  {icon: '\uD83D\uDC41\uFE0F', title: 'Live Markdown Preview', desc: 'See your markdown rendered in real-time in a side panel. Headers, bold, italic, code blocks with syntax highlighting for 16+ languages, and lists — all styled inline as you type.'},
  {icon: '\uD83C\uDFA8', title: 'Syntax Highlighting for 16+ Languages', desc: 'Built-in syntax highlighting for Zig, Python, JavaScript, TypeScript, Rust, Go, C, C++, Java, and more. Theme-aware colors with a pluggable highlighter backend.'},
  {icon: '\uD83D\uDDB1\uFE0F', title: 'Mouse Support', desc: 'Click to position the cursor, scroll with the mouse wheel, and click panels to switch focus. Works out of the box in modern terminal emulators like iTerm2, Alacritty, and kitty.'},
  {icon: '\uD83E\uDDE9', title: 'Extensible Plugin System', desc: 'Extend lazy-md with plugins. Register custom commands, hook into editor events, and add custom panels. Build, share, and install community plugins.'},
  {icon: '\u26A1', title: 'Zero Dependencies', desc: 'Written in pure Zig using only POSIX termios and ANSI escape codes. No external libraries, no runtime dependencies. Fast startup and a tiny single binary.'},
  {icon: '\uD83D\uDCD0', title: '3-Panel TUI Layout', desc: 'Inspired by lazygit — file tree, editor, and preview panels side by side. Toggle and resize panels with keyboard shortcuts. A familiar layout for terminal power users.'},
  {icon: '\uD83E\uDD16', title: 'MCP Server for AI Agents', desc: 'Built-in MCP (Model Context Protocol) server with 15 tools. Connect AI agents like Claude Code and Gemini CLI to read, navigate, and edit markdown documents via JSON-RPC 2.0 over stdio.'},
];

function Features(): React.JSX.Element {
  return (
    <section className={s.features} id="features">
      <div className={s.container}>
        <h2 className={s.sectionTitle}>Why Choose lazy-md?</h2>
        <p className={s.sectionDesc}>
          lazy-md is a terminal markdown editor designed for developers who live in the terminal.
          If you use vim, tmux, and the command line daily, lazy-md fits right into your workflow.
        </p>
        <div className={s.featureGrid}>
          {features.map(({icon, title, desc}) => (
            <article key={title} className={s.featureCard}>
              <div className={s.featureIcon} aria-hidden="true">{icon}</div>
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
    <section className={s.install} id="installation">
      <div className={s.container}>
        <h2 className={s.sectionTitle}>Install lazy-md</h2>
        <p className={s.sectionDesc}>
          Get up and running in seconds. lazy-md compiles to a single binary with no runtime dependencies.
        </p>
        <div className={s.installSteps}>
          <div className={s.installStep}>
            <h3>Prerequisites</h3>
            <p>Requires <a href="https://ziglang.org/download/">Zig</a> 0.15.1 or later.</p>
          </div>
          <div className={s.installStep}>
            <h3>Build from Source</h3>
            <div className={s.codeBlock}>
              <code>{`git clone https://github.com/user/lazy-md.git
cd lazy-md
zig build
./zig-out/bin/lazy-md myfile.md`}</code>
            </div>
          </div>
          <div className={s.installStep}>
            <h3>Pre-built Binaries</h3>
            <p>Download from <a href="https://github.com/user/lazy-md/releases">GitHub Releases</a> — available for Linux (x86_64) and macOS (x86_64, ARM64).</p>
          </div>
        </div>
      </div>
    </section>
  );
}

function Keybindings(): React.JSX.Element {
  return (
    <section className={s.keybindings} id="keybindings">
      <div className={s.container}>
        <h2 className={s.sectionTitle}>Vim Keybindings Reference</h2>
        <p className={s.sectionDesc}>
          lazy-md supports the vim keybindings you already know. No learning curve if you use vim or neovim.
        </p>
        <div className={s.keybindingTables}>
          <div>
            <h3>Navigation</h3>
            <table>
              <tbody>
                <tr><td><kbd>h</kbd> <kbd>j</kbd> <kbd>k</kbd> <kbd>l</kbd></td><td>Move cursor</td></tr>
                <tr><td><kbd>w</kbd> <kbd>b</kbd> <kbd>e</kbd></td><td>Word motions</td></tr>
                <tr><td><kbd>0</kbd> <kbd>$</kbd> <kbd>^</kbd></td><td>Line start/end</td></tr>
                <tr><td><kbd>gg</kbd> <kbd>G</kbd></td><td>Top/bottom of file</td></tr>
                <tr><td><kbd>Ctrl+D</kbd> <kbd>Ctrl+U</kbd></td><td>Half-page scroll</td></tr>
              </tbody>
            </table>
          </div>
          <div>
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
          <div>
            <h3>Commands</h3>
            <table>
              <tbody>
                <tr><td><kbd>:w</kbd></td><td>Save file</td></tr>
                <tr><td><kbd>:q</kbd></td><td>Quit editor</td></tr>
                <tr><td><kbd>:wq</kbd></td><td>Save and quit</td></tr>
                <tr><td><kbd>Tab</kbd></td><td>Cycle panels</td></tr>
                <tr><td><kbd>Alt+1</kbd> <kbd>Alt+2</kbd></td><td>Toggle panels</td></tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </section>
  );
}

function MCPSection(): React.JSX.Element {
  return (
    <section className={s.install} id="mcp-server">
      <div className={s.container}>
        <h2 className={s.sectionTitle}>MCP Server for AI Agents</h2>
        <p className={s.sectionDesc}>
          lazy-md doubles as an MCP (Model Context Protocol) server. AI coding agents like Claude Code
          and Gemini CLI can connect via stdio to read, navigate, and edit markdown documents programmatically.
        </p>
        <div className={s.installSteps}>
          <div className={s.installStep}>
            <h3>Start the MCP Server</h3>
            <div className={s.codeBlock}>
              <code>{`lazy-md --mcp-server              # Start server
lazy-md --mcp-server myfile.md    # Start with file`}</code>
            </div>
          </div>
          <div className={s.installStep}>
            <h3>15 Built-in Tools</h3>
            <p>Document tools (open, read, write, search, edit sections) and navigation tools (read by heading path, list tasks, toggle checkboxes, get breadcrumbs, move sections).</p>
          </div>
          <div className={s.installStep}>
            <h3>Connect Claude Code</h3>
            <div className={s.codeBlock}>
              <code>{`claude mcp add lazy-md -- /path/to/lazy-md --mcp-server`}</code>
            </div>
          </div>
        </div>
        <div className={s.heroActions} style={{marginTop: '2rem'}}>
          <Link className={s.btnSecondary} to="/docs/mcp-server/overview">
            MCP Documentation
          </Link>
        </div>
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
        <Features />
        <Install />
        <Keybindings />
        <MCPSection />
      </main>
    </Layout>
  );
}
