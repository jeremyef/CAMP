# BRIEF.md — Template & Section Menu

---

## BRIEF.md format

The version line is always the first line of BRIEF.md, in exactly
this format:

  # BRIEF.md — v1.0.0 (YYYY-MM-DD)

Followed by the agreed sections in order. Section headers use `##`.
Core sections always appear. Optional sections appear only when
confirmed — see "Optional sections" below.

---

## Core sections (always present)

### Purpose
One to three sentences. What this project is trying to achieve,
expressed as a measurable result — not an activity.

### Scope
Two required subsections, both must be present:

In:
- <item>

Out:
- <item>

Neither subsection is acceptable without the other. See
"Per-section quality bar" for the pushback rule.

### Success criteria
How you'll know this is working — a number, a binary outcome, or a
date. If success genuinely cannot be defined yet (early-stage
exploratory project), write "To be defined — current stage is
exploratory." This is the only acceptable escape; do not accept
vague sentiment ("it should feel better") as a substitute.

### Constraints / non-negotiables
Hard limits that cannot be revisited without a rebrief. If nothing
is genuinely non-negotiable yet, write "None identified yet" — do not
invent constraints to fill the section.

### Notes
Free-form. No quality bar. Anything that matters but doesn't fit
elsewhere. May be left empty.

---

## Optional sections (propose, don't assume)
Before drafting, `rebrief` proposes which optional sections apply and
states a one-line reason for each, then waits for explicit confirmation
before writing anything. Do not silently include or omit optional
sections — the list must be visible and agreed before drafting starts.

Available optional sections:
- Stakeholder map — relevant when more than one person's preferences
  materially affect the outcome. Format: name/role per line, one line
  each, brief note on their stake. Free-form beyond that.
- Tech stack / platform — relevant for software projects with real
  technology choices to make explicit. List chosen tools/platforms and
  a brief reason for each choice.
- Timeline / milestones — relevant only when real external deadlines
  exist. Skip for open-ended or personal projects. Format: date and
  milestone description, one per line.

This menu is not exhaustive — `rebrief` may propose a section not
listed here if a project genuinely calls for it, using the same
propose-then-confirm rule.

---

## Per-section quality bar

**Purpose — gated.**
Reject answers that describe activity rather than a result. Push
back once if the answer only describes what will be built ("a tool
that helps with X") rather than what will be achieved ("reduce X to
near-zero, currently N/month"). If the second answer still fails,
do not loop — ask the user explicitly: "Would you like to move on
with the current answer, or try once more?" Accept whichever they
choose. Never loop more than twice total without explicit user
direction.

**Scope — gated.**
Both "In" and "Out" subsections are required. Do not accept one
without the other. If the user provides only "In," ask specifically
for "Out" before moving on — this is the section most likely to
prevent scope creep, and it's the one most commonly skipped. Apply
the same two-attempt-then-ask rule as Purpose if needed.

**Success criteria — gated, lighter touch.**
Must be specific enough to check against later: a number, a binary
outcome, or a date. The escape clause ("To be defined — current
stage is exploratory") is valid — accept it without pushback if
offered. Push back only on pure sentiment ("it should feel better").
Apply the two-attempt-then-ask rule if needed.

**Constraints / non-negotiables — gated, lighter touch.**
Must name an actual hard limit, not a preference. "None identified
yet" is a valid answer — accept it without pushback. Push back only
if an answer describes a preference rather than a genuine constraint.

**Notes — ungated.**
No quality bar. Accept any answer, including silence.

**Optional sections — ungated by default.**
Accept the first answer as given. Apply light scrutiny only if the
project stakes clearly warrant it.

---

## Versioning

The version line format is: `# BRIEF.md — vMAJOR.MINOR.PATCH (YYYY-MM-DD)`

Bump rules — evaluated in order, stopping at the first that applies:
1. MAJOR — any change to the content of Scope's "In" or "Out" lines,
   regardless of downstream impact on past decisions. Wording-only
   changes that don't alter meaning are PATCH, not MAJOR.
2. MINOR — a new section is added, OR an existing section changes in
   a way that passes the quality bar for that section but would have
   answered the original question differently (Success criteria
   revised from "reduce to 0-1/month" to "reduce by 80%"). If both
   a MINOR-level and a MAJOR-level change occur in the same rebrief,
   MAJOR takes precedence.
3. PATCH — all other changes: wording clarified, formatting adjusted,
   Notes updated, no meaning change in any gated section.

MAJOR and MINOR bumps: commit + annotated tag `brief-vX.Y`.
PATCH bumps: commit only, no tag.

---

## Assembly
`rebrief` does not write any section to BRIEF.md until every gated
section in the agreed list has passed its quality bar (or the
explicit user override has been accepted). This is all-or-nothing —
no partial BRIEF.md is ever saved, per AGENTS.md's write discipline.

---

## Example — non-coding project brief (minimal)

# BRIEF.md — v1.0.0 (2026-06-21)

## Purpose
Reduce missed on-call handoffs to near-zero. Currently averaging
2-3 missed handoffs per month, all caused by people checking an
outdated schedule spreadsheet.

## Scope

In:
- On-call schedule visibility for the whole team.
- Automated handoff reminders 24 hours before a shift change.

Out:
- PagerDuty or any third-party escalation integration.
- Automated paging or alerting.

## Success criteria
Missed handoffs drop to 0-1 per month within two full rotation
cycles of the new system being live.

## Constraints / non-negotiables
Must work without a new login — pull from the existing team calendar.

## Notes
Current spreadsheet is owned by ops. Will need their sign-off before
deprecating it.

---

## Example — software project brief (with optional sections)

# BRIEF.md — v1.1.0 (2026-07-15)

## Purpose
Replace the manual CSV export process for monthly billing reports.
Currently takes ~4 hours per finance team member each month and
produces errors in roughly 1 in 5 reports.

## Scope

In:
- Automated generation of monthly billing reports from the existing
  database.
- PDF export and email delivery to the finance team.

Out:
- Real-time billing dashboards.
- Integration with external accounting software (Xero, QuickBooks).

## Success criteria
Monthly billing report generation time under 10 minutes with zero
manual steps. Error rate drops to 0 for two consecutive billing
cycles.

## Constraints / non-negotiables
Must use the existing Postgres database — no data migration.
Reports must match the current PDF format exactly (finance has
regulatory obligations tied to the current layout).

## Tech stack / platform
- Postgres (existing, non-negotiable per constraints above)
- Python for report generation (team's primary language)
- SendGrid for email delivery (already contracted)

## Timeline / milestones
- 2026-08-01: working report generation, no delivery yet.
- 2026-08-15: email delivery live, tested with finance team.
- 2026-09-01: fully deployed, old CSV process deprecated.

## Notes
Finance team lead is Jamie — cc on all test reports during QA.
