# LazyMD Growth Plan: Becoming a Popular Obsidian Alternative

## Current State Assessment

- ~21K lines of Zig across 80+ files, 80+ plugins, 22 MCP tools
- 0 stars, 0 forks on GitHub — **you're at ground zero**
- Unique positioning: **terminal-native + AI-agent-first** (no competitor has this)
- Inspired by lazygit (52K+ stars) — proven TUI formula

---

## Phase 1: Product Readiness (Weeks 1-3)

### 1.1 Nail the Core Experience

Before any promotion, the editor must feel **solid** for daily use. Focus on:

- **File sync between devices** — This is Obsidian's #1 pain point (paid Sync at $8/mo). Offer free git-based sync out of the box via your existing `git_sync` plugin. Market this hard.
- **Smooth vim keybindings** — Your target audience expects flawless vim motions. This is table stakes.
- **Fast startup** — Zig gives you a massive advantage here. Benchmark against Obsidian's Electron startup and flaunt the numbers.

### 1.2 Fix the README & Branding

Your README currently has `github.com/EME130/lazymd` placeholder links and an ASCII mockup. This needs:

- **Real screenshots/GIF** — Record a ~15 second terminal GIF (use [vhs](https://github.com/charmbracelet/vhs) or [asciinema](https://asciinema.org)) showing the editor in action
- **Clear value proposition** at the top: *"Obsidian for the terminal. Zero dependencies. AI-native."*
- **Comparison table** vs Obsidian, Logseq, Joplin showing your advantages (speed, no Electron, MCP, free sync, truly open source)
- **One-line install**: `curl -sSf https://... | sh` or Homebrew formula
- Fix the GitHub URL to your actual repo (`EME130/lazymd`)

### 1.3 Distribution

- **Homebrew tap**: `brew install LazyMD`
- **AUR package** for Arch Linux (terminal users skew heavily Arch)
- **Nix flake** (Nix users love trying terminal tools)
- **Pre-built binaries** for macOS/Linux/Windows via GitHub Releases + CI

---

## Phase 2: Differentiation — Own Your Niche (Weeks 2-5)

You can't beat Obsidian at everything. **Win on what they can't do:**

### 2.1 "AI-Native" Knowledge Management (Your Killer Feature)

This is where you have **zero competition**. No other markdown editor is an MCP server.

- Position LazyMD as **"the markdown editor that AI agents can read, write, and navigate"**
- Create demo videos showing Claude/Gemini editing notes through MCP
- Build a landing page section: *"Your notes, accessible to any AI agent via MCP"*
- Write a blog post: *"Why your markdown editor should be an MCP server"*

### 2.2 Terminal-Native Advantage

Obsidian's biggest criticisms from the research:

| Obsidian Pain Point | LazyMD Answer |
|---|---|
| Electron bloat, slow startup | Pure Zig, instant startup |
| Not truly open source (proprietary core) | MIT licensed, fully open |
| $8/mo sync | Free git-based sync |
| Steep learning curve from plugins | Batteries-included with 80+ built-in plugins |
| No collaboration | Git = collaboration by default |
| Mobile sync costs money | SSH into your machine, it's a TUI |

### 2.3 Brain Feature — Knowledge Graph in the Terminal

You already have `[[wiki-links]]`, backlinks, graph traversal, and BFS. This matches Obsidian's most-loved feature. Polish it:

- Make `BrainView.zig` (force-directed ASCII graph) visually impressive — this will be your **screenshot magnet**
- Add unlinked mentions detection (you have a plugin stub)
- Ensure the graph MCP tools work flawlessly for AI agents

---

## Phase 3: Launch Strategy (Week 4-6)

Learn from [lazygit's story](https://jesseduffield.com/Lazygit-5-Years-On/): Jesse Duffield posted to Hacker News expecting nothing, a flamewar about TUI git clients pushed it to the front page, and it snowballed from there.

### 3.1 Pre-Launch Prep

- Clean up the GitHub repo: good README, LICENSE (MIT), CONTRIBUTING.md (you have this), issue templates, discussions enabled
- Create a **website** (you already have `/website` with Docusaurus — publish it)
- Record a **2-minute demo video** (terminal GIFs + voiceover)
- Write 2-3 blog posts for your docs site:
  - *"Why I built a markdown editor in Zig"*
  - *"Obsidian vs LazyMD: An honest comparison"*
  - *"How MCP turns your notes into an AI knowledge base"*

### 3.2 Launch Sequence

Do these in order, ~2-3 days apart:

1. **Hacker News** — "Show HN: LazyMD — A terminal-based Obsidian alternative written in Zig" (HN loves Zig projects + terminal tools + Obsidian alternatives)
2. **Reddit** — Post to r/commandline, r/vim, r/neovim, r/zig, r/ObsidianMD, r/selfhosted, r/linux
3. **Lobste.rs** — Technical crowd, similar to HN
4. **Product Hunt** — "LazyMD: Obsidian for the terminal"
5. **Twitter/X** — Tag Zig community, TUI developers, AI/MCP people
6. **Dev.to / Hashnode** — Cross-post your blog articles

### 3.3 The lazygit Playbook

From Jesse Duffield's retrospective, the key lessons:

- **Controversy drives visibility** — The "do you really need a TUI for git?" debate is what made lazygit famous. For you: *"Should your notes live in the terminal?"* will spark discussion
- **Ask issue reporters to fix it themselves** — Developer users can become contributors. Just ask: "Are you up to fixing this yourself? Happy to give pointers"
- **Consistent UX** — lazygit won because of its predictable panel-based layout. You already have this pattern

---

## Phase 4: Community Building (Ongoing)

### 4.1 Discord/Matrix Server

- Create a Discord with channels: `#general`, `#plugins`, `#mcp-agents`, `#showcase`, `#zig-dev`
- This becomes your feedback loop and contributor pipeline

### 4.2 Contributor Funnel

- Label issues with `good-first-issue` — each plugin is a natural entry point for new contributors
- Write a plugin development guide (your 80+ plugins are a goldmine for teaching)
- Run "Plugin of the Month" where community members build and share plugins

### 4.3 Content Strategy

Regular content keeps the project visible:

- **Monthly release posts** with changelogs (you have a `/changelog` skill)
- **"How I use LazyMD"** guest posts from users
- **YouTube/terminal screencasts** showing workflows
- **"LazyMD + Claude"** workflow demos (AI audience is massive right now)

---

## Phase 5: Feature Parity & Beyond (Months 2-6)

### Must-Have for Obsidian Switchers

- [ ] Search across vault (full-text)
- [ ] Tags and tag navigation
- [ ] Daily notes / periodic notes
- [ ] Templates
- [ ] Frontmatter/YAML support
- [ ] Export to PDF/HTML

### Differentiators to Double Down On

- [ ] **MCP ecosystem** — Let AI agents build your second brain
- [ ] **Speed** — Publish benchmarks: startup time, file open time, memory usage vs Obsidian
- [ ] **Multiplayer via git** — Real-time(ish) collaboration through git branches
- [ ] **ACP agent mode** (from your roadmap) — LazyMD as an agent host

---

## Phase 6: Sustainability

### Monetization (Optional, keeps project alive)

- **LazyMD Cloud** — Hosted sync service (like Obsidian Sync, but cheaper)
- **LazyMD Teams** — Shared vaults with permissions
- **Sponsors/Open Collective** — The lazygit model, donation-funded development
- Keep the core **always free and open source**

---

## Key Metrics to Track

| Metric | 3 Month Target | 6 Month Target |
|---|---|---|
| GitHub Stars | 500 | 3,000 |
| Contributors | 10 | 30 |
| Discord Members | 100 | 500 |
| Weekly Downloads | 200 | 1,000 |
| HN Front Page | 1x | 2-3x |

---

## TL;DR — The Three-Word Strategy

**"Obsidian, but terminal."**

Your wedge is the intersection of three trends: **(1)** terminal renaissance (lazygit, lazydocker, btop), **(2)** AI agents need tool access to user data (MCP), **(3)** Obsidian users frustrated with Electron bloat and paid sync. Position LazyMD at that intersection and nobody else is there.

---

## Sources

- [Lazygit Turns 5: Musings on Git, TUIs, and Open Source](https://jesseduffield.com/Lazygit-5-Years-On/)
- [3 Tips For Making a Popular Open Source Project](https://skerritt.blog/make-popular-open-source-projects/)
- [Finding Users for Your Project — Open Source Guides](https://opensource.guide/finding-users/)
- [Why Obsidian Users Are Switching — Medium](https://medium.com/@anshulkummar/why-obsidian-users-are-flocking-to-capacities-in-2025-777320abb66e)
- [Obsidian Review: What Nobody Tells You](https://thebusinessdive.com/obsidian-review)
- [Best Open Source Obsidian Alternatives](https://openalternative.co/alternatives/obsidian)
- [Terminal Markdown Tools — Terminal Trove](https://terminaltrove.com/categories/markdown/)
- [Marketing Open Source Projects — TODO Group](https://todogroup.org/resources/guides/marketing-open-source-projects/)
