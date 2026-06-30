# CAMP — Context And Memory Protocol

A structured memory system for AI-assisted projects. Solves the core problem
of working across multiple AI sessions: the model starts fresh every time, and
without a structured way to carry context forward, you end up re-explaining
decisions, relitigating settled questions, and watching scope quietly drift.

CAMP uses four Markdown files to hold a project's memory and four skills
to keep them updated reliably. It works across Claude Code, Cursor, and
Claude.ai, and it doesn't care whether your project involves code, writing,
research, or planning.

---

## What's in this repo

| File | Purpose |
|---|---|
| AGENTS.md | Master protocol — session start, file ownership, git integration, skill coordination. Copied into every project. |
| HOW-TO-USE.md | Plain-language guide for day-to-day use. Copied into every project. |
| project-init.sh | One-command scaffold for new projects. Registers the new project in `projects.txt`. |
| projects-sync.sh | Push skills and protocol files to all registered projects. |
| projects.example.txt | Template for `projects.txt` (which is gitignored — machine-specific). |
| memory/BRIEF-TEMPLATE.md | Section menu, quality bar, and versioning rules for BRIEF.md. |
| memory/CONTEXT-SCHEMA.md | Structure, line cap, truncation, and phase-transition rules for CONTEXT.md. |
| memory/DECISIONS-SCHEMA.md | Entry format, fan-in guard, index, archive, and multi-phase handling for DECISIONS.md. |
| memory/SESSIONS-SCHEMA.md | Entry format, archive rules, and staleness tracking for SESSIONS.md. |
| skills/brief/SKILL.md | Creates and revises BRIEF.md through guided elicitation. |
| skills/decide/SKILL.md | Logs decisions to DECISIONS.md after deliberation. |
| skills/wrap-up/SKILL.md | Closes sessions — updates CONTEXT.md and SESSIONS.md. |
| skills/plan-writer/SKILL.md | Writes a structured plan file before implementation begins. |

```
CAMP/                                ← this repo
├── README.md
├── AGENTS.md
├── HOW-TO-USE.md
├── project-init.sh
├── projects-sync.sh                 ← push skills and protocol files to registered projects
├── projects.example.txt             ← template for projects.txt (gitignored)
├── .gitignore
├── memory/
│   ├── BRIEF-TEMPLATE.md
│   ├── CONTEXT-SCHEMA.md
│   ├── DECISIONS-SCHEMA.md
│   └── SESSIONS-SCHEMA.md
└── skills/
    ├── brief/
    │   └── SKILL.md
    ├── decide/
    │   └── SKILL.md
    ├── wrap-up/
    │   └── SKILL.md
    └── plan-writer/
        └── SKILL.md
```

---

## What a project looks like after init

```
my-project/
├── AGENTS.md                        ← protocol (from this repo)
├── CLAUDE.md                        → symlink to AGENTS.md
├── HOW-TO-USE.md                    ← day-to-day guide (from this repo)
├── .gitignore                       ← excludes .claude/settings.local.json
├── .claude/
│   ├── settings.local.json          ← attribution setting (not committed)
│   └── skills/
│       ├── brief/SKILL.md
│       ├── decide/SKILL.md
│       ├── wrap-up/SKILL.md
│       └── plan-writer/SKILL.md
├── .cursor/
│   └── skills/
│       ├── brief/SKILL.md
│       ├── decide/SKILL.md
│       ├── wrap-up/SKILL.md
│       └── plan-writer/SKILL.md
└── memory/
    ├── BRIEF.md                     ← filled by `brief` skill
    ├── BRIEF-TEMPLATE.md            ← schema reference
    ├── CONTEXT.md                   ← updated by `wrap-up` each session
    ├── CONTEXT-SCHEMA.md            ← schema reference
    ├── DECISIONS.md                 ← append-only, updated by `decide`
    ├── DECISIONS-SCHEMA.md          ← schema reference
    ├── SESSIONS.md                  ← append-only, updated by `wrap-up`
    ├── SESSIONS-SCHEMA.md           ← schema reference
    ├── DECISIONS-ARCHIVE/
    └── SESSIONS-ARCHIVE/
```

---

## Setup

### 1. Clone this repo as your templates directory

```bash
git clone <this-repo> ~/CAMP
export TEMPLATE_DIR=~/CAMP
```

> Add the `export` line to `~/.zshrc` or `~/.bashrc` to make it permanent.

### 2. Start a new project

```bash
TEMPLATE_DIR=~/CAMP ~/CAMP/project-init.sh my-project-name
```

> Run with `TEMPLATE_DIR` set. The script validates your environment, copies
> template files and skills, creates the git repo and initial commit, and writes
> `.claude/settings.local.json` with attribution disabled. Edit that file if you
> want Claude Code to append Co-Authored-By trailers to commits.

For Cursor-specific config, add the `--cursor` flag:

```bash
TEMPLATE_DIR=~/CAMP ~/CAMP/project-init.sh my-project-name --cursor
```

> Adds Cursor-specific attribution config (`.cursor/cli-config.json`) and
> gitignore entries for Cursor settings files. Skills are always scaffolded
> for both Claude Code and Cursor regardless of this flag.

### 3. Run `brief` to fill out BRIEF.md

Open the project in Claude Code or Cursor. The session-start protocol fires
automatically. Then invoke the `brief` skill — it guides you through
elicitation section by section and writes BRIEF.md once everything is
confirmed.

---

## Platform specifics

### Claude Code — full native support

CLAUDE.md (symlinked to AGENTS.md) is read natively. Skills in
`.claude/skills/` are auto-discovered. Memory files are on the local
filesystem — skills read and write them directly. Git operations run
automatically per the staging and commit rules in AGENTS.md.

Skills can be invoked via slash command (`/brief`, `/decide`, `/wrap-up`,
`/plan-writer`) or autonomously when Claude matches the description to the
conversation.

To disable a skill temporarily without deleting it:
```bash
mv .claude/skills/brief .claude/skills/_brief
```
> Prefixing the folder with `_` causes Claude Code to skip it. Rename back
> to re-enable. Takes effect on the next session.

### Cursor — same as Claude Code

Cursor reads AGENTS.md natively. Skills are installed in both `.claude/skills/`
and `.cursor/skills/` by default — `project-init.sh` always scaffolds both
directories. Use `--cursor` at init time to also add Cursor-specific config
files (`.cursor/cli-config.json`).

For Cursor-specific always-on rules beyond AGENTS.md, use `.cursor/rules/*.mdc`
files. The single `.cursorrules` file at the project root is deprecated but
still works.

### Claude.ai — limited; manual sync required

Claude.ai does not have local filesystem access. Skills run in a sandboxed
container, not your project directory.

**AGENTS.md:** paste contents into the Project's custom instructions field,
or upload as Project Knowledge.

**Memory files:** upload current BRIEF.md, CONTEXT.md, and the DECISIONS.md
index as Project Knowledge before each session. Claude.ai reads them but
cannot update them.

**Skill writes:** skills output updated file content as text. Copy it to
your local files manually. Log any decisions reached in claude.ai via
`decide` in your next Claude Code or Cursor session.

**Git operations:** not applicable. Skip entirely.

**Installing skills on claude.ai:**

```bash
# Package each skill as a ZIP with the folder at its root
mkdir -p /tmp/brief      && cp .claude/skills/brief/SKILL.md      /tmp/brief/SKILL.md
mkdir -p /tmp/decide     && cp .claude/skills/decide/SKILL.md     /tmp/decide/SKILL.md
mkdir -p /tmp/wrap-up    && cp .claude/skills/wrap-up/SKILL.md    /tmp/wrap-up/SKILL.md
mkdir -p /tmp/plan-writer && cp .claude/skills/plan-writer/SKILL.md /tmp/plan-writer/SKILL.md

cd /tmp
zip -r brief.zip brief/ && zip -r decide.zip decide/ && zip -r wrap-up.zip wrap-up/ && zip -r plan-writer.zip plan-writer/
```

> Upload each ZIP via Settings > Customize > Skills > "+" > "Create skill."
> Available on Pro, Max, Team, and Enterprise plans with code execution
> enabled. Re-upload whenever skill files change — claude.ai does not pick
> up changes automatically.

**Skill updates:** every change to a SKILL.md file requires re-zipping and
re-uploading to claude.ai. Claude Code and Cursor pick up changes on the
next session restart.

---

## Token usage estimates

> **Note — dated June 2026.** Anthropic adjusts usage limits periodically
> without publishing fixed token counts. The absolute numbers below may
> drift; the relative percentages and practical guidance hold regardless.

### What drives cost

Every message re-reads the full accumulated context from scratch, so token
cost compounds with session length. The memory system's static footprint
(the files read at session start) gets paid on every turn, not just once.

**Static footprint — steady state:**

| File | Tokens |
|---|---|
| AGENTS.md | ~1,400 |
| BRIEF.md | ~300 |
| CONTEXT.md | ~250 |
| DECISIONS.md index (mature project) | ~300 |
| SESSIONS.md (last 3 entries) | ~250 |
| **Total** | **~2,500** |

Before the DECISIONS.md index exists (first ~40 entries), the full file is
read each session. Cost at 20 entries is roughly 1,000–1,500 tokens; at 39
entries it may hit 2,000+. Once the index generates, it drops to ~300 and
stays flat regardless of project age.

### Project init (first `brief` run)

Init loads BRIEF-TEMPLATE.md on top of the standard footprint (~1,200
additional tokens). A typical elicitation takes 10–15 exchanges.

**Estimated total: 45,000–60,000 tokens.**

On Pro this sits right at or above the window — init may trigger compaction
or need a second conversation. On Max 5x it fits comfortably.

### Day-to-day sessions

| Session type | Messages | Estimate |
|---|---|---|
| Short planning / research | 10 | ~25,000 |
| Typical build session + `decide` + `wrap-up` | 20 | ~55,000 |
| Long debugging / exploration | 35 | ~92,000 |

Skills overhead (`decide` + `wrap-up` in one session) adds roughly
5,000 tokens from schema loading and confirmation exchanges.

### Against plan tiers (approximate)

| Plan | Window | Init | Short | Typical | Long |
|---|---|---|---|---|---|
| Pro | ~44K | ⚠️ Tight | ✅ | ❌ Exceeds | ❌ |
| Max 5x | ~88K | ✅ | ✅ | ✅ | ⚠️ ~105% |
| Max 20x | ~220K | ✅ | ✅ | ✅ | ✅ |

**Practical guidance:**

On Pro, keep sessions short and deliberate. Invoke `wrap-up` earlier than
feels natural and start a new conversation — the footprint resets on a new
thread. Long exploratory sessions without compaction are not viable on Pro.

On Max 5x, the system works well for sessions up to ~25–30 messages. Past
35 messages, watch for the window limit.

On Max 20x, there is comfortable headroom for nearly any working session.

The most expensive individual sessions are typically early-phase research
(many turns of back-and-forth before anything is decided), not later
implementation sessions where work is more heads-down.

---

## Further reading

- **HOW-TO-USE.md** — copied into every project. Covers the four files,
  the four skills, typical session flow, phase transitions, and tool
  choice guidance. Start here once a project is running.
- **memory/\*-SCHEMA.md** — the exact format spec for each memory file.
  Reference when something looks wrong or you want to understand a
  file's structure in detail.
- **AGENTS.md** — the full CAMP protocol. Everything the AI reads to govern
  how the system behaves.
