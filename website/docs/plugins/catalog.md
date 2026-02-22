---
title: Plugin Catalog
sidebar_position: 2
description: All 62 built-in plugins for lazy-md — note-taking, productivity, writing modes, markdown extensions, integrations, and export tools. Zettelkasten, kanban, pomodoro, and more.
keywords: [lazy-md plugins, zettelkasten, kanban, pomodoro, markdown plugins, note taking plugins, built-in plugins, zen mode, daily notes]
---

# Plugin Catalog

lazy-md ships with **62 built-in plugins** covering note-taking, productivity, integrations, and more. All plugins follow the vtable interface pattern.

## Core Editing

| Plugin | Commands | Description |
|--------|----------|-------------|
| word-count | `:wc` | Word, line, and character counts |
| outline | `:outline` `:toc` | Document outline / table of contents |
| search | `:search` `:search.replace` `:search.vault` | Full-text search in file and vault |
| bookmarks | `:bm.set` `:bm.list` `:bm.clear` | Bookmark positions in files |
| command-palette | `:palette` `:commands` | Fuzzy command palette |
| quick-switcher | `:switcher` `:open` | Fuzzy file switcher |
| recent-files | `:recent` | Recently opened files list |
| auto-complete | `:autocomplete` | Auto-complete for links and tags |
| auto-link | `:autolink` | Auto-convert URLs to links |
| checklist | `:check` `:check.progress` | Checklist management and progress |

## Writing Modes

| Plugin | Commands | Description |
|--------|----------|-------------|
| zen-mode | `:zen` `:zen.off` | Distraction-free writing |
| typewriter | `:typewriter` | Cursor always centered on screen |
| focus-mode | `:focus` `:focus.para` `:focus.sentence` | Highlight current paragraph/sentence |

## Markdown Extensions

| Plugin | Commands | Description |
|--------|----------|-------------|
| table-editor | `:table` `:table.fmt` `:table.add-col` `:table.add-row` | Table creation and formatting |
| footnotes | `:fn.add` `:fn.list` | Footnote management |
| citations | `:cite` `:cite.bib` `:cite.list` | Academic citations and BibTeX |
| admonitions | `:callout` `:callout.tip` `:callout.warn` | Callout blocks (tip, warning, note) |
| emoji | `:emoji` `:emoji.search` | Emoji shortcode insertion |
| math | `:math` `:math.insert` | LaTeX math expression support |
| mermaid | `:mermaid` `:mermaid.insert` | Mermaid diagram support |
| frontmatter | `:fm` `:fm.add` `:fm.edit` | YAML frontmatter management |

## Note Management

| Plugin | Commands | Description |
|--------|----------|-------------|
| templates | `:tpl.meeting` `:tpl.daily` `:tpl.readme` `:tpl.blog` | Document templates |
| daily-notes | `:daily` `:daily.yesterday` `:daily.tomorrow` | Daily journal notes |
| periodic-notes | `:weekly` `:monthly` | Weekly and monthly notes |
| zettelkasten | `:zk.new` `:zk.link` `:zk.index` | Zettelkasten note-taking method |
| note-refactor | `:refactor.extract` `:refactor.split` | Extract and split notes |
| folder-notes | `:folder.index` `:folder.create` | Auto-generate folder index notes |
| tag-manager | `:tags` `:tags.search` `:tags.rename` | Manage and search #tags |
| backlinks | `:backlinks` | Find files linking to current note |
| graph-view | `:graph` `:graph.local` | ASCII graph of note connections |
| random-note | `:random` | Open a random note |

## Productivity

| Plugin | Commands | Description |
|--------|----------|-------------|
| pomodoro | `:pomo.start` `:pomo.stop` `:pomo.status` | Pomodoro focus timer |
| kanban | `:kanban` `:kanban.add` `:kanban.move` | Markdown-based kanban board |
| habit-tracker | `:habit` `:habit.check` `:habit.add` | Daily habit tracking |
| day-planner | `:plan` `:plan.today` `:plan.template` | Time-blocked daily planning |
| meeting-notes | `:meeting` `:meeting.new` | Structured meeting notes |
| journal | `:journal` `:journal.new` `:journal.search` | Chronological journal entries |
| calendar | `:cal` `:cal.today` | Visual calendar navigation |
| project-manager | `:project` `:project.switch` `:project.new` | Switch between project vaults |
| flashcards | `:flash` `:flash.review` `:flash.add` | Spaced repetition flashcards |
| reading-time | `:reading-time` | Estimate document reading time |

## Text Tools

| Plugin | Commands | Description |
|--------|----------|-------------|
| snippet-manager | `:snip` `:snip.add` `:snip.list` | Reusable text snippets |
| text-expander | `:expand` `:expand.add` | Shorthand text expansion |
| linter | `:lint` `:lint.fix` | Markdown linting and style checks |
| spell-check | `:spell` `:spell.add` `:spell.ignore` | Spell checking |
| dictionary | `:define` | Word definition lookup |
| thesaurus | `:synonyms` | Synonym and antonym lookup |

## Integrations

| Plugin | Commands | Description |
|--------|----------|-------------|
| todoist | `:todoist` `:todoist.add` `:todoist.sync` `:todoist.inbox` | Todoist task integration |
| slack | `:slack` `:slack.send` `:slack.share` | Slack messaging integration |
| git-sync | `:git` `:git.commit` `:git.push` `:git.pull` | Git-based note synchronization |
| mcp-connector | `:mcp` `:mcp.connect` `:mcp.status` | MCP protocol for AI agent access |
| taskwarrior | `:tw.list` `:tw.add` `:tw.done` | TaskWarrior TUI integration |

## Export & Publishing

| Plugin | Commands | Description |
|--------|----------|-------------|
| export-html | `:export.html` `:export.pdf` | Export to HTML and PDF |
| publish | `:publish` `:publish.build` `:publish.preview` | Publish notes as static site |
| slides | `:slides` `:slides.start` `:slides.export` | Terminal presentation slides |
| web-clipper | `:clip` `:clip.url` | Clip web pages to markdown |
| paste-image | `:paste.img` | Paste images from clipboard |

## Advanced

| Plugin | Commands | Description |
|--------|----------|-------------|
| dataview | `:dv` `:dv.query` `:dv.table` | Query note metadata and frontmatter |
| mind-map | `:mindmap` | ASCII mind map from headings |
| version-history | `:history` `:history.diff` `:history.restore` | Document version tracking |
| file-recovery | `:recover` `:recover.list` | Auto-save snapshots and crash recovery |
| theme-chooser | `:theme.chooser` `:theme.preview` `:theme.info` | Interactive theme browser |
