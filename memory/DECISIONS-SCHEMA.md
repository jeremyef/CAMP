# DECISIONS.md — Entry Schema

## ID format
DEC-NNN, zero-padded to 3 digits, sequential, never reused, never
renumbered. Numbering continues across archive boundaries — an archived
entry keeps its original ID forever.

---

## Entry template

Three field shapes are shown below. Use whichever matches each field's
actual content, per the formatting rules in each field's definition.

### Active decision — no prior entries affected

### DEC-001 — 2026-06-21 — Use Postgres over MongoDB

Context:
Need to choose a primary datastore before backend work starts.

Decision:
Postgres.

Alternatives considered:
- MongoDB — rejected. Team has no operational experience managing
  backups and restores at our required SLA.
- SQLite — rejected. Does not support concurrent writes for our
  multi-user case.

Disposition: Active
Brief version: v1.0.0

---

### Deferred decision — out of scope for now

### DEC-009 — 2026-07-04 — PagerDuty integration

Context:
Raised mid-sprint as a possible addition to the notification system.

Decision:
Not actioned — explicitly out of current scope per BRIEF.md v1.0.

Alternatives considered:
- Full PagerDuty integration — deferred. Team has no ops experience
  with it and the current sprint has no capacity.

Disposition: Deferred

---

### Active decision that supersedes a prior one

### DEC-020 — 2026-08-10 — Replace Postgres with PlanetScale

Context:
Team moving to serverless deployment; Postgres requires a persistent
connection pool that conflicts with the serverless model.

Decision:
PlanetScale (MySQL-compatible serverless DB).

Alternatives considered:
- Neon (serverless Postgres) — rejected. Still in public beta at time
  of decision; unstable for production use.
- Keep Postgres with PgBouncer — rejected. Adds operational overhead
  that defeats the purpose of going serverless.

Disposition: Active
Supersedes: DEC-001
Brief version: v1.2.0

---

### Active decision that resolves a prior deferred entry

### DEC-031 — 2026-09-15 — Adopt Twilio for on-call paging

Context:
PagerDuty integration was deferred at DEC-009 (BRIEF.md v1.0).
Now in scope under BRIEF.md v2.0 — phase 2 includes notification
integrations. Team now has capacity and a concrete customer requirement.

Decision:
Twilio — not PagerDuty. Lower cost at our scale, and the team already
has Twilio experience from the SMS notification work.

Alternatives considered:
- PagerDuty — rejected. ~3x the monthly cost of Twilio at our current
  user volume.
- Build in-house — rejected. Estimated 3 sprints; not justified when
  Twilio covers the requirement.

Disposition: Active
Resolves: DEC-009
Brief version: v2.0.0

---

## Field definitions and formatting rules

**Entry header** — uses `###` level, not `##`, to distinguish entries
from schema section headers when both files appear in the same context.
Format: `### DEC-NNN — YYYY-MM-DD — <title>`

**Title** — 5 words maximum. Enough to identify the decision at a
glance in the index; not a full description. If it can't fit in 5
words, shorten it — the full description is in Context and Decision.

**Context** — always present. One to three sentences explaining why
this decision was needed at this moment. If the reason is obvious, one
sentence is sufficient — do not pad.

**Decision** — always present. State what was decided plainly. Not
"we discussed" or "we considered" — what was actually chosen.

**Alternatives considered** — always present, never omitted. At least
one entry required even if there was only one realistic option (state
why the alternatives weren't realistic). Format: bulleted list, one
alternative per bullet, rejection reason on the same bullet or
indented beneath it. Never a comma-run on one line.

**Disposition** — always present, always one of: `Active` or
`Deferred`. Set once at creation, never edited afterward. See
"Current status" section for what these mean in combination with
forward references.

**Brief version** — always present on Active entries; omit on Deferred
entries (which reference the brief version in their Decision field text
by convention — e.g. "out of current scope per BRIEF.md v1.0"). Records
which brief version was in effect when this decision was made. Enables
later sessions to understand whether a decision was made under a
different phase's scope without needing to open git log.

**Supersedes** — omit the field line entirely if not applicable. Write
the field line only when this entry replaces a prior Active entry.
One target ID only — see "Fan-in guard."

**Resolves** — omit the field line entirely if not applicable. Write
the field line only when this entry acts on a prior Deferred entry.
One target ID only — see "Fan-in guard." See "Resolves test" below.
When resolving a Deferred entry from a previous phase (i.e., the
Deferred entry's brief version differs from the current one), note the
cross-phase context explicitly in the Context field — e.g. "Deferred
under v1.0 scope; now in scope under v2.0."

Resolves test — concrete, not a judgment call: use Resolves only when
this entry is choosing how to handle something a prior Deferred entry
explicitly described, even if the chosen approach is to reject it
entirely ("we will never do X"). If this entry is only tangentially
related in topic, do not set Resolves — log it as a fresh entry.

---

## Fan-in guard — checked before writing, not after
Before setting Supersedes or Resolves to target DEC-NNN, confirm no
existing entry already targets that same ID via either field. If one
does, stop and surface this to the user directly — do not create a
second pointer to an already-claimed target under any circumstance.
This is what keeps "current status" a well-defined single answer rather
than a fork.

---

## Current status (computed, not stored) — chain-following required
An entry's current status is derived by following references forward,
not by checking one hop and stopping:

- Active-and-current — Disposition: Active, nothing references it via
  Supersedes.
- Superseded — Disposition: Active, a later entry references it via
  Supersedes.
- Deferred-and-unresolved — Disposition: Deferred, nothing references
  it via Resolves.
- Resolved — Disposition: Deferred, a later entry references it via
  Resolves.

If the entry found via Supersedes or Resolves has itself since been
superseded, follow the chain to whichever entry is currently active
before treating anything as settled. Citing an intermediate link as
if it were current is treated the same as citing a stale decision —
not acceptable grounds to skip re-checking.

Because the fan-in guard is enforced at write time, this chain is
guaranteed to be linear — following it forward always terminates at
exactly one current entry, never a fork.

---

## Index — scope is deliberately limited
The index lists only entries whose current status is Active-and-current
or Deferred-and-unresolved — the genuinely open set. Superseded and
Resolved entries drop out of the index once resolved. This keeps the
index bounded by how much is currently open, not by total project
history.

Index line format — one real example:
  - DEC-031 — 2026-Q3 — Twilio for paging — Active-and-current — v2.0.0

One line per open entry, newest first. The quarter is included so an
archived entry's file can be located by ID without searching across
multiple archive files. The brief version is included so phase context
is visible without opening the full entry.

Regenerated by `decide` on every run once the index exists. An entry
is removed from the index on the run that supersedes or resolves it.
First generated when total entries in the live file pass 40.

## Multi-phase Deferred handling
A Deferred-and-unresolved entry that survives more than one MAJOR brief
version bump (i.e., it has been deferred through at least one full phase
transition without being resolved or re-examined) should be flagged
during the next `brief` run's Step 0b check. It is not automatically
closed, superseded, or removed — but its continued Deferred status
across phase boundaries is a signal that it may be permanently out of
scope rather than temporarily deferred. `brief` surfaces these entries;
the user decides whether to formally close them (by logging a new entry
that Resolves the old one with Decision "Will not pursue") or carry them
forward deliberately into the new phase.

---

## Archive
Trigger: once the count of entries currently in DECISIONS.md (not
total entries ever written) passes 40, archive all but the most recent
15, moving full entries to
memory/DECISIONS-ARCHIVE/<year>-<quarter>.md based on each entry's
original date. Re-triggers any time the live file count passes 40
again. Full entry content is preserved exactly — archiving is a move,
not a summarization. An archived entry remains fully citable via
chain-following regardless of index membership. Citing an archived
DEC-ID as grounds for a new decision requires opening and reading that
entry in full first — the index line alone is not sufficient.
