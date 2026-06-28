---
name: decide
description: Logs a project decision to memory/DECISIONS.md. Use when a choice has been reached and is ready to be logged — after deliberation, not at the start of it. Covers technical approaches, scope questions, tool/stack choices, or any other meaningful decision that should outlive this session. Also use when a previously Deferred item is being acted on. Do not trigger during open-ended discussion or exploration before a choice has been made.
---

# decide

## When this fires
A decision has been reached that should outlive this conversation —
something a future session, or a different person, would otherwise
have to re-derive or re-litigate.

Concrete test for "worth logging": if this choice were silently
reversed next session without explanation, would it cause real
rework or confusion? If yes — log it. If no — skip it.

Examples that pass: technology stack choices, architecture patterns,
scope boundaries, naming conventions applied project-wide, process
decisions that affect multiple sessions.
Examples that fail: a local variable name, a one-off formatting
choice, anything that affects only the current file and would be
obviously re-derivable from context.

## Step 1 — BRIEF.md structural check
Read memory/BRIEF.md. Check whether a `## Scope` section with
both "In:" and "Out:" subsections exists — not whether the file is
non-empty. If the Scope section is absent or incomplete (i.e.,
`brief` has not produced a properly structured brief yet), skip
Step 2 entirely and note this to the user: "BRIEF.md has no Scope
section yet — scope check skipped. Consider running brief before
logging decisions." Continue to Step 3.

## Step 2 — Scope check (runs before existing-entry scan)
Concrete test: read BRIEF.md's Scope "In" lines as a list of named
items. This decision is in scope if and only if:
(a) it affects only items already named in the "In" list, without
    adding new named components, OR
(b) it is a direct implementation detail of an already-named "In"
    item (e.g. "In" lists "on-call schedule visibility" and this
    decision is which calendar format to use for it).
If neither condition is met, treat as out of scope by default.

Present the three-way choice before proceeding:
(a) In scope — continue to Step 3.
(b) Out of scope — log as Deferred. See "Deferred scope entries."
(c) Genuinely changes the brief — pause `decide`, hand off to
    `brief`. When `brief` completes, ask the user explicitly:
    "Should we now log a decision against the updated brief?"
    If yes, restart from Step 1 with the updated BRIEF.md. If no,
    close without logging.

If the user's response to this choice is undecided or unclear ("not
sure," "let's discuss more"), do not proceed — respond: "Take your
time. Invoke `decide` again when ready to log." Close the skill
without writing anything.

Scope check takes priority over the existing-entry scan. A prior
entry that was itself logged out of scope does not override this
check.

## Step 3 — Existing entry scan
Read memory/DECISIONS.md's index if it exists. The index covers
all entries whose current status is Active-and-current or
Deferred-and-unresolved — regardless of whether they're in the live
file or archive. It does not cover Superseded or Resolved entries.
If no index exists yet, scan the live file only and note to the user:
"No index exists yet — archive files (if any) are not covered by
this scan. If prior decisions on this topic may have been archived,
check memory/DECISIONS-ARCHIVE/ manually."

Matching test: an existing entry matches if BOTH are true:
(a) It covers the same specific named component of the project
    (same technology, same architectural area, same named process).
(b) The new decision would be rendered unnecessary or directly
    contradicted if the prior one stands as-is.

Note: this test becomes harder to evaluate reliably as the number
of decisions and supersede chains grows. On projects with 50+
entries, treat a confident match as a signal to verify, not as a
final answer — show the matched entry to the user rather than
acting on the match alone.

If a match is found:
- Follow the Supersedes/Resolves chain to its end per
  memory/DECISIONS-SCHEMA.md. Cite the terminal entry's DEC-ID —
  not an intermediate link.
- Show the user the matched entry's title, current status, Brief
  version, and its Decision field. The Brief version matters: if
  the matched entry was made under a different MAJOR version than
  the current BRIEF.md (i.e., a different phase), say so explicitly
  — "DEC-NNN was logged under vX.0.0; current phase is vY.0.0.
  The prior decision's scope context may have changed." This is not
  grounds to skip showing the match, but it is grounds for the user
  to treat it as less binding than a same-phase entry.
- Ask explicitly: "DEC-NNN already covers this. Options:
  (a) This is a new or distinct decision — continue logging.
  (b) Revisit DEC-NNN — close decide for now and discuss first.
  (c) This is the same decision, nothing to log — close."
- If the user picks (b), close the skill without writing anything.
  The user re-invokes `decide` after discussion concludes.
- Proceed only on explicit (a).

## Step 4 — Writing the entry
Determine the next DEC-ID by finding the highest existing ID across
the live file AND all files in memory/DECISIONS-ARCHIVE/. The next
ID is that number plus one, zero-padded to 3 digits. Never derive
the next ID from the live file alone.

Show the user the complete proposed entry and ask for confirmation
before writing anything. Do not write silently even if the decision
seemed unambiguous during conversation. One confirmation per entry;
do not ask field by field.

Follow the template in memory/DECISIONS-SCHEMA.md exactly: ID,
date (today), title (5 words maximum), Context, Decision,
Alternatives considered (mandatory — never omitted, even if there
was only one realistic option; state why alternatives weren't
realistic), Disposition, Supersedes/Resolves if applicable, and
Brief version (required on Active entries; omit on Deferred entries,
where the brief version is recorded in the Decision field text
instead — e.g. "out of current scope per BRIEF.md v1.0.0").

Alternatives considered — fallback when not derivable from
conversation: if the conversation leading to this decision did not
explicitly name or discuss alternatives, do not invent them and do
not leave the field empty. Instead, ask before composing the
proposed entry: "What alternatives did you consider, and why were
they ruled out?" Wait for the answer before proceeding. Only after
receiving an explicit answer (even if the answer is "I didn't
consider any others — X was the only realistic option") should the
entry be composed and shown for confirmation.

Cross-phase Resolves: if this entry sets Resolves to a Deferred
entry whose Brief version differs from the current BRIEF.md version
(i.e., resolving a cross-phase deferral), the Context field must
note this explicitly — e.g. "Deferred under v1.0.0 scope; now
in scope under v2.0.0 following phase transition." This is the
only place this cross-phase relationship is recorded in a
human-readable way — do not omit it.

Fan-in guard: before setting Supersedes or Resolves, confirm no
existing entry already targets that same ID via either field. If one
does, stop and surface this to the user — do not write a second
pointer to an already-claimed target.

## Deferred scope entries (option b from Step 2)
When logging a Deferred entry for a scope-boundary reason, use this
structure exactly — populated with the actual current BRIEF.md
version, not angle-bracket placeholders:

### DEC-NNN — YYYY-MM-DD — <topic in 5 words>

Context:
<Describe what was proposed and why it came up.>

Decision:
Not actioned — out of current scope per BRIEF.md vX.Y.Z.
Candidate for future consideration.

Alternatives considered:
- <Any options that were discussed, with why each was set aside.>

Disposition: Deferred

The `vX.Y.Z` in the Decision field is the actual current BRIEF.md
version read from the file — not left as a placeholder. This is
how Deferred entries record their phase context without a separate
Brief version field. It is what `brief`'s Step 0b uses to identify
which phase a deferral belongs to.

## After writing — operations run in this order
1. Archive check: if the live entry count now passes 40 (i.e.,
   reaches 41 or more), archive all but the most recent 15 per
   memory/DECISIONS-SCHEMA.md. Archiving moves entries out of the
   live file before index regeneration runs.
2. Index regeneration: if the index already exists, regenerate it
   now against the current state of the live file (post-archive if
   archiving ran). This happens on every `decide` run once the index
   exists. If the index does not yet exist and the live file just
   reached 41 or more entries, generate it for the first time per
   the schema.

Git (only if inside a git work tree — check per AGENTS.md's
git-detection rule; skip entirely if not):
- Pre-commit check: before staging, check whether any non-memory
  files are dirty or staged. If any are found, surface the list of
  dirty file paths and ask: "These non-memory files are uncommitted —
  commit them first, or proceed with the memory-only commit?" Wait
  for an explicit answer before staging anything. Do not commit the
  dirty files and do not auto-continue.
- Stage only memory/DECISIONS.md (+ memory/DECISIONS-ARCHIVE/<file>
  if archiving ran this turn).
- Commit: `chore(memory): log decision [DEC-NNN]` where DEC-NNN is
  the ID of the entry just written — read from the entry itself,
  do not invent.
- If this decision coincides with a code change in the same session,
  do not bundle it into this commit — see AGENTS.md, "Attaching
  decisions to code commits."

## What this skill never does
- Never edits a past entry. Never deletes a past entry.
- Never writes to memory/CONTEXT.md or memory/SESSIONS.md.
- Never writes to memory/BRIEF.md.
- Never logs a decision without explicit user confirmation of the
  proposed entry content.
- Never runs git push.
- Never proceeds past an undecided scope check or an undecided
  existing-entry prompt — always closes cleanly and waits for
  re-invocation.
