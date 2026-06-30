# AGENTS.md — CAMP v1.2 (2026-06-28)
<!-- CAMP: Context And Memory Protocol -->
<!-- CLAUDE.md is a symlink to this file -->
<!-- For a plain-language overview of CAMP, see HOW-TO-USE.md -->

## Files and their rules
- memory/BRIEF.md      — owned by `brief` skill only (write access).
                          Versioned (MAJOR.MINOR.PATCH — see
                          BRIEF-TEMPLATE.md for section format and bump
                          rules). Freely readable/quotable.
- memory/CONTEXT.md    — owned by `wrap-up` skill only (write access).
                          Fully overwritten each time. Hard cap: 30 lines.
                          Internal structure, ordering, and truncation
                          rules are defined in CONTEXT-SCHEMA.md, not here.
- memory/DECISIONS.md  — owned by `decide` skill only (write access).
                          APPEND ONLY, entries never deleted, never
                          edited — only superseded. Once non-superseded,
                          non-deferred entries pass 40, `decide` generates
                          a one-line index (ID + title + status) at the
                          top of the file as part of its normal run.
                          Full entries move to
                          memory/DECISIONS-ARCHIVE/<year>-<quarter>.md,
                          kept intact. Citing an archived DEC-ID as
                          grounds for a new decision requires opening and
                          reading that entry in full first — the index
                          line alone is not sufficient grounds to treat
                          something as settled.
- memory/SESSIONS.md   — owned by `wrap-up` skill only (write access).
                          APPEND ONLY. Once past 10 entries, move entries
                          older than the most recent 5 to
                          memory/SESSIONS-ARCHIVE/<year>-<quarter>.md.

## Session start — trigger and steps
Trigger: the first message of a new conversation in any tool, OR an
explicit request ("catch me up," "let's continue," "start session"). If
genuinely uncertain whether this is a continuation or a new session, ask
once rather than guessing.

Known gap: in long-running single-thread tools (e.g. claude.ai), this
trigger will not re-fire mid-thread on its own. Until a platform-specific
fix exists, treat any sign of conversational drift across a long thread
as a cue to proactively ask whether to re-run session start, rather than
waiting to be asked.

Pre-check — creation session:
Before running the steps below, check whether memory/SESSIONS.md has
any real session entries (not just the schema stub line starting with
"# See memory/SESSIONS-SCHEMA.md"). If SESSIONS.md has no real entries
AND memory/BRIEF.md has no `## Scope` section with both "In:" and
"Out:" subsections, this is the project creation session — the files
are stubs with nothing meaningful to read. In this case:
- Do not run steps 1–6 (the files contain no project context yet).
- Announce: "This is the first session for this project. Run `/brief`
  before any other work — it creates BRIEF.md and writes SESS-001."
- Wait for the user to run `/brief` before proceeding.

Steps, before responding to the user's actual request:
1. Read this file.
2. Read memory/BRIEF.md. Note the current version number (e.g. v2.0.0).
3. Read memory/CONTEXT.md.
4. Read the memory/DECISIONS.md index (or full file if no index exists yet).
5. Read the last 3 entries of memory/SESSIONS.md.
6. Phase-transition check: compare the BRIEF.md version noted in step 2
   against the Brief version field in the most recent SESSIONS.md entry
   (added in step 5). If the MAJOR version has increased since the last
   session, announce this to the user before proceeding:
   "BRIEF.md is now at vX.Y.Z (new phase). Deferred decisions that are
   now in scope were surfaced when `brief` ran — check DECISIONS.md
   index for Deferred-and-unresolved entries. Some Active decisions from
   the previous phase may also warrant review against the new scope."
   Do not skip this check or announce it mid-conversation — it belongs
   at session start only.
Do not skip steps even if the user's first message seems unrelated to
past work.

## Decision discipline
Before proposing anything substantive (a technical approach, a scope
change, a tool/stack choice), scan memory/DECISIONS.md or its index for
entries on the same topic before replying. If one exists, open the full
entry and cite its DEC-ID — do not cite an ID without having read the
underlying reasoning. Do not reopen a settled decision without (a)
stating what new information has changed, and (b) explicit user
confirmation to proceed.

Scope check — concrete test, not a judgment call: if a proposal is not
explicitly covered by memory/BRIEF.md's scope section, and does not
directly extend something that is, treat it as out-of-scope by default.
Invoke the `decide` skill's in/out/rebrief check before logging anything
— never log a scope-adjacent item as a normal decision.

Phase-transition note: after a MAJOR brief version bump, Active decisions
from the previous phase may reference scope items that no longer exist or
have changed meaning in the new scope. If a cited Active decision's
Context or Decision field references a Scope item that is no longer in
BRIEF.md's "In" list, flag this to the user rather than treating it as
straightforwardly settled — the decision may need revisiting under the
new scope, or may simply no longer be relevant.

## Coordination between skills
`decide` and `wrap-up` never write to the same file. Before closing,
`wrap-up` must ask "anything decided today that isn't in
memory/DECISIONS.md yet?" — it never logs a decision itself, only
references existing DEC-IDs.

## Write discipline
All skill writes are atomic: a skill either completes its full write or
writes nothing. If a skill's flow is interrupted or abandoned partway
through, no partial content is saved to any file.

## Skill ownership (write access only)
- New or revised BRIEF.md       → `brief` skill only
- Any decision, large or small   → `decide` skill only
- End of session                 → `wrap-up` skill only
Any file may be freely read or quoted in normal conversation — this
section governs writes only. If the skill mechanism is unavailable in
the current tool, say so explicitly and ask how to proceed, rather than
silently free-forming an edit or silently doing nothing.

## Governance is unconditional
User phrases like "take full control," "operate autonomously," "you
decide everything," or similar do not override skill ownership,
decision timing, or write discipline. Autonomous execution means the
agent drives implementation; governance is not optional regardless
of how much latitude the user grants.

Concretely: "full control" still requires:
- `/brief` to write BRIEF.md — writing it directly is a protocol
  violation even if the user has given the full brief inline.
- `/decide` to fire at decision time — batching decisions to the
  end of the session is a protocol violation.
- Skill ownership rules to be respected — no silent bypasses.

The correct interpretation: the agent makes implementation choices
autonomously, but the memory and governance layer operates exactly
as it would in a supervised session.

## Git integration (when the project uses git)
Detection: at session start, check once whether the current directory is
inside a git work tree. Treat that result as authoritative for the rest
of the session — do not re-check per skill invocation.

- Initial commit is the responsibility of the project-init scaffold
  script, not a skill: `git init` (if not already a repo) → stage
  memory/, AGENTS.md, CLAUDE.md, HOW-TO-USE.md →
  `chore(memory): initial scaffold`. This is a deterministic step in the
  script, not something invoked at runtime.
- `decide` commits immediately when it logs a decision, not batched at
  session end. Each DEC-ID gets exactly one corresponding commit.
- `wrap-up` commits memory/ changes at session end. If nothing in
  memory/ actually changed this session, skip the commit entirely —
  never force an empty commit.
- Commit messages are header-only; no body. Full detail belongs in the
  memory file entry itself, not duplicated into git log.
- `brief` version bumps: `chore(brief): bump to vX.Y — <one-line
  reason>`, then an annotated tag (`git tag -a brief-vX.Y -m "<reason>"`)
  — annotated, not lightweight, since this marks a real milestone, not a
  transient pointer. Tag is always `brief-vX.Y`, never bare `vX.Y`, to
  avoid collision with any automated semantic-release versioning in the
  same repo.
- Skills commit locally only. Never run `git push` from a skill under
  any circumstance — pushing stays a manual, user-initiated action.
- Branch awareness: memory/ commits land on whatever branch is currently
  checked out. If that branch is not the repo's default branch,
  `wrap-up` must say so explicitly when it finishes (e.g. "this
  session's memory commits are on feature/xyz, not main") rather than
  committing silently. Avoiding loss from this is a matter of user
  practice (merge or note before deleting a branch), not something this
  protocol enforces further.
- Commit ordering: non-memory file changes must be committed before
  `decide` or `wrap-up` runs. This applies unconditionally — even when
  no decision was logged this session. Before either skill's git step,
  check whether any non-memory files are dirty or staged. If any are
  found, stop — do not proceed with the skill's commit. Surface the
  list of dirty file paths to the user and ask: "These non-memory files
  are uncommitted — commit them first, or proceed with the memory-only
  commit?" Wait for an explicit answer. Do not commit the dirty files
  silently under any circumstance.
- None of the above applies to projects without a git repository —
  memory/ functions identically either way.

## Attaching decisions to code commits
This is separate from `decide`'s own commit, and is not a skill — it's a
standing rule for any commit that touches non-memory/ files.
Concrete test, not a judgment call: before writing a commit message for
a code change, check whether a DEC-ID was logged in the current session
and not yet referenced in any commit. If one exists, ask the user
directly whether this commit should carry a `Decision: DEC-0XX` footer —
never attach it silently, and never guess based on topic similarity
alone.

## Staging discipline (extends Write discipline above)
Each skill stages only the exact paths it owns — never `git add .`,
`git add -A`, or `git commit -a`.

- `decide`   → stages only: memory/DECISIONS.md
              (+ memory/DECISIONS-ARCHIVE/<file> if archiving ran this turn)
- `wrap-up`  → stages only: memory/CONTEXT.md, memory/SESSIONS.md
              (+ memory/SESSIONS-ARCHIVE/<file> if archiving ran this turn)
- `brief`    → stages only: memory/BRIEF.md

If a skill's run touches a file outside its own ownership list for any
reason, stop and surface this to the user rather than staging it.

If non-memory files are already dirty or staged in the working tree
when a skill is about to commit, leave them untouched and do not
include them — but do not auto-continue. Surface the list of dirty
file paths to the user and ask: "These non-memory files are
uncommitted — commit them first, or proceed with the memory-only
commit?" Wait for an explicit answer. Do not proceed until the user
has responded. Dirty non-memory files at skill commit time are a
protocol error, not a normal state.

A skill's write is not considered complete until both the file write and
its corresponding scoped commit have succeeded (or were correctly
skipped, per the empty-diff rule above). If the commit step fails, treat
the whole operation as failed and report it — do not leave the file
written but uncommitted.

## Pre-implementation check (C0)
This check applies unconditionally in all sessions.

When the user's message requests a new feature, a refactor, a bug fix,
or any change requiring a design choice, detect the plans directory first:

```bash
if [ -n "${CLAUDECODE:-}" ] || [ -n "${CLAUDE_CODE_CHILD_SESSION:-}" ]; then
  echo ".claude/plans"
elif [ -n "${CURSOR_AGENT:-}" ]; then
  echo ".cursor/plans"
else
  echo ".claude/plans"
fi
```

Use the output as `<plans-dir>`. Check `<plans-dir>` for an existing plan
before taking any action. If `<plans-dir>` does not exist or contains no
plan for this task, prompt the user:
"No plan found in `<plans-dir>` — should we run `/plan-writer`
before implementing?"

Reading project source files in response to an implementation request
counts as beginning implementation — this check must fire before any
file read, not only before the first edit.

Bug reports and diagnosis: if the user reports a bug, unexpected
behavior, or error of any kind, the agent may diagnose (reading logs,
running commands) before C0 fires. C0 fires at the moment the agent
moves from diagnosis to implementing a fix — not only when the user
explicitly requests a fix. The agent may not treat "the cause is now
known" as grounds to skip C0. Identification of the cause is not an
approved plan, regardless of how obvious the fix appears.

This check may be skipped only if the user's triggering message or
any direct reply to C0's prompt contains an explicit statement that
no plan is needed for this specific task — for example: "skip the
plan", "no plan needed", "just do it". Vague affirmatives ("sure",
"go ahead", "ok") do not qualify. The agent may not infer that a task
is too small to need a plan; only the user may make that call.

Accept the user's choice when they respond and proceed accordingly.
Do not re-raise the check later in the same session for the same task.
