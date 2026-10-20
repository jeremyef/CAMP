# AGENTS.md — CAMP v2.0.0-dev (2026-10-18)
<!-- CAMP: Context And Memory Protocol -->
<!-- CLAUDE.md is a symlink to this file -->
<!-- For a plain-language overview of CAMP, see HOW-TO-USE.md -->

## Files and their rules
- memory/BRIEF.md      — owned by `brief` skill only (write access).
                          Versioned (MAJOR.MINOR.PATCH — see
                          BRIEF-TEMPLATE.md for section format and bump
                          rules). Freely readable/quotable.
- memory/CONTEXT.md    — owned by `wrap-up` skill only (write access).
                          Fully overwritten each time. Hard cap: 40 lines.
                          Internal structure, ordering, and truncation
                          rules are defined in CONTEXT-SCHEMA.md, not here.
- memory/DECISIONS.md  — owned by `decide` skill only (write access).
                          APPEND ONLY, entries never deleted, never
                          edited — only superseded. Once the file passes
                          40 entries, `decide` archives the older ones to
                          memory/DECISIONS-ARCHIVE/<year>-<quarter>.md,
                          kept intact, and keeps a one-line index at the
                          top (see DECISIONS-SCHEMA.md). Citing an
                          archived DEC-ID as grounds for a new decision
                          requires opening and reading that entry in full
                          first — the index line alone is not
                          sufficient grounds to treat something as
                          settled.
- memory/SESSIONS.md   — owned by `wrap-up` skill (write access). `brief`
                          also appends an entry for a project's first brief
                          and for a MAJOR or MINOR revision (see the `brief`
                          skill).
                          APPEND ONLY. Once past 10 entries, move entries
                          older than the most recent 5 to
                          memory/SESSIONS-ARCHIVE/<year>-<quarter>.md.

"Non-memory file", used throughout this file and the skills, means any file
outside the memory/ folder.

## Memory ID check
DEC-NNN, SESS-NNN and ITEM-NNN numbers are never reused. Where the project
has it, `scripts/check-memory-ids.sh memory` checks this, and also that each
Closed entry in SESSIONS.md is one of the allowed forms. The same check runs
in CI on pull requests and on pushes where the project has
`.github/workflows/memory-id-check.yml`. Two branches that each add the
next number will collide: the check reports it, and whoever merges second
gives their new entry the next free number before it reaches the default
branch. Collisions are caught by this check and fixed by hand, not prevented
by construction. An entry already on the default branch is never renumbered.

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
6. Phase-transition check: apply the exact same detection mechanism,
   comparison target, and base case defined in the `wrap-up` skill's
   "Phase-transition detection" section — that section is the single
   source of truth for how this comparison works; do not reimplement
   or restate it here. Use the BRIEF.md version already noted in step 2
   and the CONTEXT.md content already read in step 3 rather than
   re-reading either file. If that mechanism indicates the MAJOR
   version has increased since the last session, announce this to the
   user before proceeding:
   "BRIEF.md is now at vX.Y.Z (new phase). Deferred decisions that are
   now in scope were surfaced when `brief` ran — check DECISIONS.md
   index for Deferred-and-unresolved entries. Some Active decisions from
   the previous phase may also warrant review against the new scope."
   Do not skip this check or announce it mid-conversation — it belongs
   at session start only.
7. Upstream template check — weekly, best-effort, never blocks: if
   `scripts/check-template-update.sh` exists and `timeout` is available on
   this machine, run `timeout 10 bash scripts/check-template-update.sh`
   from the project root and print its output, if any, exactly as given,
   before continuing. The script decides whether the weekly check is due,
   compares this project with the template channel recorded in
   .camp-version, and updates last_checked_at; it never touches
   synced_commit or synced_at, which only projects-sync.sh sets. Swallow
   any failure silently: never surface an error or delay the response to
   the user's actual request. .camp-version is local/gitignored, not part
   of the memory/ system, so this step is outside the Skill ownership and
   Staging discipline sections below: it is never staged or committed.
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
Invoke the `decide` skill's "Scope check" section (the in/out/rebrief choice)
before logging anything — never log a scope-adjacent item as a normal decision.

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

Plan files at `Status: Complete` or `Status: Superseded` are immutable.
The agent does not append to, reopen, or modify them under any
circumstance, including direct revisions to a feature just delivered.
Only the user can reopen one, by editing its header by hand. If you
believe a plan was closed in error, stop and tell the user. Follow-on
work always requires a new plan file; reference the closed plan in the new
file's Why section. This applies regardless of how obvious or small the
change seems: "already diagnosed" is not a waiver. The six plan statuses
are defined in the `plan-writer` skill's "Update the status line" section.

## Skill ownership (write access only)
- New or revised BRIEF.md       → `brief` skill only (it also appends the
                                  SESSIONS entry for a first brief or a MAJOR
                                  or MINOR revision)
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

This section governs a different case than a non-interactive
invocation (see "Commit ordering" below, under "Git integration"): it's about how much
latitude a present user grants within an interactive session, not
about whether a human is reachable at all. A documented
non-interactive fallback isn't the user granting autonomy that
overrides governance — it's the skill behaving correctly when the
premise of "a user to ask" doesn't hold, which this section was never
written to address.

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
- `brief` version bumps: `chore(brief): bump to vX.Y.Z: <one-line
  reason>`, then an annotated tag (`git tag -a brief-vX.Y -m "<reason>"`)
  — annotated, not lightweight, since this marks a real milestone, not a
  transient pointer. Tag is always `brief-vX.Y`, never bare `vX.Y`, to
  avoid collision with any automated semantic-release versioning in the
  same repo.
- Skills commit locally only. Never run `git push` from a skill under
  any circumstance — pushing stays a manual, user-initiated action.
- Branch awareness: memory/ commits land on whatever branch is currently
  checked out. If that branch is not the repo's default branch,
  `decide` (in its commit report) and `wrap-up` (when it finishes) must
  say so explicitly (e.g. "this session's memory commits are on
  feature/xyz, not main") rather than committing silently. The
  merged-branch check and cleanup rules in the Feature-branch workflow
  section guard against losing that work.
- Commit ordering: non-memory file changes must be committed before
  `decide`, `wrap-up` or `brief` commits. This applies unconditionally —
  even when no decision was logged this session. Before any skill's git
  step, check whether any non-memory files are dirty or staged. If any are
  found, stop — do not proceed with the skill's commit. Surface the
  list of dirty file paths to the user and ask: "These non-memory files
  are uncommitted — commit them first, or proceed with the memory-only
  commit?" Wait for an explicit answer. Do not commit the dirty files
  silently under any circumstance. This assumes a human is reachable
  to answer. In a non-interactive invocation (no live user to ask),
  the acting skill's own documented fallback applies instead — e.g.
  the `wrap-up` skill's "Non-interactive invocation" section, which
  defaults to a memory-only commit without waiting. That default is
  governance adapting to a context where the usual safeguard (a
  reachable human) doesn't exist — it is not a bypass of this rule,
  and it never licenses expanding what gets committed beyond the
  skill's own documented default.
- None of the above applies to projects without a git repository —
  memory/ functions identically either way.

## Feature-branch workflow (when the project uses git)
In any project that uses git:

- Memory commits (brief, decide, wrap-up) land on the branch that is checked
  out (see Branch awareness above) and are reconciled when it merges. ID
  collisions between branches are caught by the memory ID check and fixed
  before the second branch merges.
- A branch that has already merged: before committing memory files on a
  non-default branch, check whether it has already merged. If so, stop and
  ask before doing anything; the `wrap-up` skill's "Merged-branch check"
  section has the procedure and says what counts as merged.
- Cleanup: offer to delete a merged branch and its worktree. Never delete
  unmerged work without showing what would be lost and getting confirmation,
  and never delete remote branches unasked.
- Regular checkout: the skills run from a regular checkout, or a linked
  worktree, on a named branch, never from a detached HEAD. If HEAD is
  detached, stop and ask the user to switch to a named branch before anything
  is written or committed. Unattended runs follow a skill's non-interactive
  fallback where it has one (see Commit ordering).

The rules after this paragraph apply when the project's BRIEF.md has a
"Working agreements" line that turns branches on (`brief` offers it when a
project is set up, or at a later revision if the line is missing), or an Active logged decision about how the project uses
branches says so. If both exist, the Working agreements line governs. If
neither exists, behaviour is unchanged (work stays on the current branch) and
nothing below is required. To change the setting, run `/brief` if there is a
Working agreements line, otherwise supersede the decision with `decide`.

- When work gets a branch: work on something in BRIEF.md's In list (or that
  directly extends an In item), or an idea being tried that might be dropped,
  gets its own branch (`feature/<slug>`). If the brief has no In list, any
  change to what the project delivers counts. Housekeeping (README,
  .gitignore, tooling config that no In item covers), memory files, and
  trivial fixes stay on the current branch. When unsure which bucket a task
  is in, use a branch. Before starting, say which bucket the task is in and
  what you will do ("in-scope work on <item>, creating feature/<slug>" or
  "housekeeping, staying on main"); the user can correct it in a sentence.
  This choice is only about branches. Whether a plan is needed is C0's
  question, and the agent still may not judge a task too small for a plan.
- Plans: for branch-worthy work, create the branch before the plan's approval
  commit, so that commit is the first on the branch. The `plan-writer` skill's
  "Commit the plan as the approval record" section has the steps. If the plan
  is skipped (C0), create the branch before the first change. If the plan was
  already approved before the branch existed, create the branch now, from the
  current one, and say so; the plan stays where it was approved.
- Worktrees: use a plain branch by default. Use a separate worktree only when
  other work is active: another worktree already exists with unmerged or
  uncommitted work in it, or the user says (or it is evident) that other work
  will run at the same time. Merged, idle or stale branches do not count.

## Attaching decisions to code commits
This is separate from `decide`'s own commit, and is not a skill — it's a
standing rule for any commit that touches non-memory files.
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
              (+ memory/SESSIONS.md if it wrote an entry: a first brief, or a
              MAJOR or MINOR revision)

If a skill's run touches a file outside its own ownership list for any
reason, stop and surface this to the user rather than staging it.

If non-memory files are already dirty or staged in the working tree
when a skill is about to commit, leave them untouched and do not
include them, and do not auto-continue: ask the question in "Commit
ordering" above and wait for an explicit answer. Dirty non-memory files
at skill commit time are a protocol error, not a normal state.

A skill's run is not considered complete until both the file write and
its corresponding scoped commit have succeeded (or were correctly
skipped, per the empty-diff rule above). If the commit step fails, report the
run as failed, saying plainly that the file is fully written but not
committed. Do not undo the write or delete entries. Tell the user it still
needs committing before the next skill run.

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

Use the output as `<plans-dir>`. Check `<plans-dir>` for a plan for this
task before taking any action. A plan is for this task when its Why or TODO
list covers the work the user asked for; if more than one plan could fit, ask
which. C0 is satisfied only by a plan whose header status is Approved or In
Progress; a plan in any other status does not satisfy it.

If `<plans-dir>` does not exist or contains no plan for this task, first look
for one on branches not merged into the default branch (local, and remote as
of the last fetch; do not fetch). If a branch has a plan for this task, name
the branch and the plan instead of the prompt below. Otherwise prompt the user:
"No plan found in `<plans-dir>` — should we run `/plan-writer`
before implementing?"

If a plan for this task exists but its status is not Approved or In
Progress, stop and ask the user, naming the plan and its status: "Found
`<plan>` with status `<status>`, which does not allow implementation." Then
offer what fits that status: approve it (Draft; the `plan-writer` skill's
"Commit the plan as the approval record" section has the steps), resume it
(Paused), or, for Complete or Superseded, a new plan that cites it. Running
`/plan-writer` for a new plan is always an option. A reply that does not say
which ("ok", "sure") is not a choice; ask which.

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
