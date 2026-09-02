---
name: brief
description: Creates or revises memory/BRIEF.md through guided elicitation. Use for a brand-new project's first brief, when a project's scope or foundational direction genuinely changes (including phase transitions), or when invoked as a handoff from `decide` option (c). Covers both initial creation and all future revisions — this is the only skill that writes to BRIEF.md. Do not invoke for wording tweaks or cosmetic changes — those are PATCH bumps that still go through this skill but follow a shorter path.
when: When the user wants to define or revise the project scope, start a new project brief, or transition to a new phase
---

# brief

## When this fires
Two concrete cases — not a judgment call:
1. memory/BRIEF.md has no proper `## Scope` section with both "In:"
   and "Out:" subsections (new project, or stub not yet filled out).
2. A handoff from `decide` option (c) — the scope check determined
   a proposal genuinely changes the brief — or a user-initiated
   phase transition (e.g. "let's scope the next phase").

For user-initiated invocation outside these two cases: ask one
question before proceeding — "Is this a scope change or phase
transition, or a wording clarification?" If scope change or phase
transition, continue with the full flow. If wording only, use the
PATCH path (see "PATCH-bump path" below).

This skill is deliberately rare. Do not invoke for routine decisions.

## Step 0 — read existing BRIEF.md before proposing anything
Always read the current memory/BRIEF.md in full before Step 1,
even for a new project (confirm it's truly empty or stub-only).
For revisions:
- Note which sections currently exist (core and optional).
- Note the current version number.
- Note the current Scope "Out" items — these are candidates to
  check against DECISIONS.md in Step 0b below.

## Step 0b — phase transition check (MAJOR bumps only)
If this rebrief is moving any item from Scope "Out" to Scope "In"
(i.e., something previously excluded is now being included), run
this check before elicitation starts:

Scan memory/DECISIONS.md (index if it exists, full file if not) for
any Deferred-and-unresolved entries whose topic matches an item being
moved from Out to In. If any are found, surface them to the user
before proceeding:

"Before we scope this phase, these previously deferred decisions
are now in scope and will need to be actioned:
- DEC-NNN — <title>
[...]
These can be acted on via `decide` during this phase."

Do not log or resolve them here — just surface them. The user
decides when to act on them.

## Step 1 — propose the section list, then stop and wait
Using the existing sections identified in Step 0 as the starting
point:
- For a new project: propose which optional sections apply,
  with a one-line reason each.
- For a revision: list existing optional sections and ask whether
  each should be kept, updated, or removed. Then propose any new
  optional sections not currently present that would apply, with
  a one-line reason each.

Wait for explicit confirmation of the final section list before
drafting anything. If the user declines all optional sections,
confirm: "Core sections only. Continuing." and proceed. Do not
silently decide the section list in either direction.

## Step 2 — elicit each section, applying its quality bar
Work through the confirmed section list one at a time, in order.
For each gated section (Purpose, Scope, Success criteria,
Constraints — see memory/BRIEF-TEMPLATE.md for the exact bar):

1. For sections already in the existing brief: show the current
   content and ask "keep as-is, update, or replace?" If kept,
   move on. If updating or replacing, apply the quality bar.
2. For new sections (not in current brief): elicit from scratch,
   applying the quality bar.
3. If an answer fails the bar: say specifically why, then ask once
   more. "Once more" means exactly one follow-up attempt per
   section — if the user has answered twice and the second answer
   still fails, ask: "Would you like to try once more, or move on
   as-is?" Accept whichever they choose. Never loop past two
   attempts without explicit user direction.
4. If the user stops mid-skill at any point before Step 4's write:
   say "Stopping — nothing has been written to BRIEF.md. Your
   current version is unchanged." Close without writing anything.

Scope requires both explicit "In" and explicit "Out" subsections.
Do not accept one without the other.

For Notes and ungated optional sections: accept the first answer
as given, no scrutiny.

## PATCH-bump path (wording changes only)
Skip Steps 0b and 1 entirely. Ask the user which section(s) they
want to update. Show the current content for each named section,
elicit the new wording, apply no quality bar (PATCH = wording only
by definition). Proceed directly to Step 3 (PATCH) and Step 4.

## Step 3 — versioning
Determine the bump before writing. For a phase transition, also
determine the phase label. State the bump type and reason to the
user and wait for acknowledgment before proceeding.

For a new project (no prior structured BRIEF.md):
- Version is 1.0.0. No bump calculation needed.

For a revision, apply the first rule that matches:
1. MAJOR — any change to the content of Scope's "In" or "Out"
   lines (items added, removed, or renamed — not wording-only).
2. MINOR — a new section added, OR Success criteria changes in a
   way that would have answered the original question differently.
   If both MAJOR and MINOR conditions apply, MAJOR takes precedence.
3. PATCH — all other changes: wording clarified, Notes updated,
   formatting adjusted, no meaning change in any gated section.

Phase annotation: for MAJOR bumps, ask: "Is this a new project
phase? If so, what would you call it?" If named, add a Phase line
to the version block:

```
# BRIEF.md — v2.0.0 (2026-09-01)
# Phase: Notification & Integrations
```

This makes MAJOR version history interpretable on its own without
reading git tags.

Tag format: `brief-vX.Y` (MAJOR.MINOR only — PATCH never tagged).
Annotated, not lightweight.

## Step 4 — assembly
Do not write memory/BRIEF.md until every section in the confirmed
list is complete. All-or-nothing — no partial write per AGENTS.md's
write discipline. Assemble and write in one operation.

## After writing

Every entry written below must satisfy memory/SESSIONS-SCHEMA.md in
full, including the `Brief version` field — the templates below are
illustrative, not an exhaustive substitute for the schema. If the
schema later adds or renames a required field, this entry must carry
that field too, even though the templates below won't have been
updated to show it.

For a new project — read memory/SESSIONS.md to get the next SESS-ID
(or use SESS-001 only if SESSIONS.md is confirmed empty or absent).
Write the first entry immediately before any other work begins:

```
## SESS-NNN — YYYY-MM-DD

Summary: Initial brief drafted and confirmed at v1.0.0.

Brief version: v1.0.0
Decisions: None

Next steps: Project is ready for first working session.
```

For a MAJOR or MINOR revision — write a SESSIONS.md entry
immediately, regardless of whether `wrap-up` will run this session.
Read SESSIONS.md to get the next SESS-ID. For a phase transition,
the Summary may span multiple sentences — one per meaningful thread
of change:

```
## SESS-NNN — YYYY-MM-DD

Summary: Brief revised to vX.Y.Z — phase transition to [name].
Scope expanded to include [new In items]. [Former Out items now In].
Success criteria updated to reflect new phase targets.

Brief version: vX.Y.Z
Decisions: <DEC-NNN if triggered by decide handoff, or "None">

Next steps: <whatever applies, or "None">
```

For PATCH bumps — no SESSIONS.md entry required; the next `wrap-up`
captures it naturally.

Git (only if inside a git work tree — check per AGENTS.md's
git-detection rule; skip entirely if not):
- Stage only memory/BRIEF.md (and memory/SESSIONS.md if an entry
  was written above).
- New project: commit `chore(brief): initial brief v1.0.0` — no tag.
- Revision: commit `chore(brief): bump to vX.Y.Z — <one-line
  reason>`. For MAJOR or MINOR: also run
  `git tag -a brief-vX.Y -m "<reason>"` after committing.
  PATCH: commit only, no tag.
- Never runs git push.

## Open Questions handoff
Before closing, review the elicitation conversation for any items
that were flagged as uncertain, undecided, or "to be determined"
during Step 2 — things the user acknowledged but couldn't answer yet.
These do not belong in BRIEF.md (which records what is known and
decided), but they should not be silently dropped either.

Collect them and surface them to the user:
"The following items came up as unresolved during the brief — consider
raising them as Open Questions in your first session's CONTEXT.md via
`wrap-up`:
- <item 1>
- <item 2>"

Do not write them to CONTEXT.md directly — `brief` never writes to
CONTEXT.md. Just name them so the user and the next `wrap-up` run
can capture them. If nothing was flagged as uncertain during
elicitation, skip this step entirely.
- Never writes to memory/CONTEXT.md or memory/DECISIONS.md.
- Never writes to memory/SESSIONS.md except for the specific cases
  defined above.
- Never invents an answer to a gated question on the user's behalf.
- Never writes a partial BRIEF.md — all-or-nothing only.
- Never actions or resolves a Deferred decision — only surfaces them.
- Never runs git push.
