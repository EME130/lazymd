import React from 'react';
import Layout from '@theme/Layout';
import Link from '@docusaurus/Link';
import TerminalDemo from '@site/src/components/TerminalDemo';
import s from './index.module.css';

function Hero(): React.JSX.Element {
  return (
    <header className={s.hero}>
      <div>
        <h1 className={s.heroTitle}>lazy-md</h1>
        <p className={s.heroSubtitle}>
          A terminal-based markdown editor.<br />
          Fast. Vim-native. Zero dependencies.
        </p>
        <div className={s.heroActions}>
          <Link className={s.btnPrimary} to="/docs/getting-started/installation">
            Get Started
          </Link>
          <Link className={s.btnSecondary} to="/docs/getting-started/installation">
            Documentation
          </Link>
        </div>
      </div>
    </header>
  );
}

const features = [
  {icon: '\u2328\uFE0F', title: 'Vim-Native', desc: 'Modal editing with Normal, Insert, and Command modes. All the vim motions you know: hjkl, w, b, dd, u, and more.'},
  {icon: '\uD83D\uDC41\uFE0F', title: 'Live Preview', desc: 'See your markdown rendered in real-time in the side panel. Headers, bold, italic, code blocks, lists \u2014 all styled with ASCII art.'},
  {icon: '\uD83D\uDDB1\uFE0F', title: 'Mouse Support', desc: 'Click to position cursor, scroll with the mouse wheel, and click panels to switch focus. Works in modern terminal emulators.'},
  {icon: '\uD83E\uDDE9', title: 'Plugin System', desc: 'Extend lazy-md with plugins. Register commands, hook into events, add custom panels. Build and share with the community.'},
  {icon: '\u26A1', title: 'Zero Dependencies', desc: 'Pure Zig built on POSIX termios and ANSI escape codes. No external libraries. Fast startup, tiny binary.'},
  {icon: '\uD83D\uDCD0', title: '3-Panel Layout', desc: 'Inspired by lazygit \u2014 file tree, editor, and preview panels. Toggle and resize with keyboard shortcuts.'},
];

function Features(): React.JSX.Element {
  return (
    <section className={s.features}>
      <div className={s.container}>
        <h2 className={s.sectionTitle}>Why lazy-md?</h2>
        <div className={s.featureGrid}>
          {features.map(({icon, title, desc}) => (
            <div key={title} className={s.featureCard}>
              <div className={s.featureIcon}>{icon}</div>
              <h3>{title}</h3>
              <p>{desc}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

function Install(): React.JSX.Element {
  return (
    <section className={s.install}>
      <div className={s.container}>
        <h2 className={s.sectionTitle}>Installation</h2>
        <div className={s.installSteps}>
          <div className={s.installStep}>
            <h3>Prerequisites</h3>
            <p>Requires <a href="https://ziglang.org/download/">Zig</a> 0.15.1 or later.</p>
          </div>
          <div className={s.installStep}>
            <h3>Build from source</h3>
            <div className={s.codeBlock}>
              <code>{`git clone https://github.com/user/lazy-md.git
cd lazy-md
zig build
./zig-out/bin/lazy-md myfile.md`}</code>
            </div>
          </div>
          <div className={s.installStep}>
            <h3>Pre-built binaries</h3>
            <p>Download from <a href="https://github.com/user/lazy-md/releases">GitHub Releases</a> — available for Linux (x86_64) and macOS (x86_64, ARM64).</p>
          </div>
        </div>
      </div>
    </section>
  );
}

function Keybindings(): React.JSX.Element {
  return (
    <section className={s.keybindings}>
      <div className={s.container}>
        <h2 className={s.sectionTitle}>Keybindings</h2>
        <div className={s.keybindingTables}>
          <div>
            <h3>Navigation</h3>
            <table>
              <tbody>
                <tr><td><kbd>h</kbd> <kbd>j</kbd> <kbd>k</kbd> <kbd>l</kbd></td><td>Move cursor</td></tr>
                <tr><td><kbd>w</kbd> <kbd>b</kbd> <kbd>e</kbd></td><td>Word motions</td></tr>
                <tr><td><kbd>0</kbd> <kbd>$</kbd> <kbd>^</kbd></td><td>Line start/end</td></tr>
                <tr><td><kbd>gg</kbd> <kbd>G</kbd></td><td>Top/bottom</td></tr>
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
                <tr><td><kbd>:w</kbd></td><td>Save</td></tr>
                <tr><td><kbd>:q</kbd></td><td>Quit</td></tr>
                <tr><td><kbd>:wq</kbd></td><td>Save & quit</td></tr>
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

export default function Home(): React.JSX.Element {
  return (
    <Layout
      title="Terminal Markdown Editor"
      description="A fast, terminal-based markdown editor with vim keybindings, live preview, and plugin system. Written in Zig with zero dependencies.">
      <Hero />
      <div className={s.terminalDemo}>
        <TerminalDemo />
      </div>
      <Features />
      <Install />
      <Keybindings />
    </Layout>
  );
}
