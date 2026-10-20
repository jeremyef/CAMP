#!/usr/bin/env bash
# Usage: scripts/check-memory-ids.sh [memory-dir]     (default: memory)
#
# Catches duplicate or reused memory IDs. Runs the same way locally and in
# CI (.github/workflows/memory-id-check.yml). Exit 0 = clean, 1 = problem.
#
# Checks:
#   DEC-NNN   one defining heading per ID across DECISIONS.md + DECISIONS-ARCHIVE/
#   SESS-NNN  one defining heading per ID across SESSIONS.md + SESSIONS-ARCHIVE/
#   ITEM-NNN  one defining bullet per ID in CONTEXT.md
#   ITEM-NNN  no ID open in CONTEXT.md may be recorded as closed in SESSIONS.md
#             or SESSIONS-ARCHIVE/ (retired numbers are never reused)
#
# The script reads each ID only from where the schemas say it is defined (see
# the comments on each check). Anything else that mentions an ID is a
# reference and is ignored, so an Index line, an archive-pointer line, or a
# title that names another entry is never mistaken for a second definition.
# Closed entries in SESSIONS.md are validated against a strict whitelist
# (memory/DECISIONS.md, DEC-004), and items in CONTEXT.md must be written
# exactly "- ITEM-NNN: text". Warnings (::warning::) never change the exit code.
#
# Known limits (deliberate, not oversights):
#   - IDs are compared as text. DEC-001 and DEC-0001 count as different IDs.
#     The schemas fix 3-digit zero-padding and the skills always mint it that
#     way, so only a hand-edit can produce a variant.
#   - Archive folders are read flat, *.md only, matching the schema's
#     <year>-<quarter>.md layout. If the layout changes, update the globs here.
#   - Only the subject of a Closed entry is treated as retired. An ID named
#     only as a merge/split/re-mint target is not, so a child item that vanishes
#     without its own closure note is not caught here. wrap-up's minting rule
#     and its no-silent-drops rule are the guard for that (see DEC-001).
#   - A heading quoted inside an entry body, or a malformed heading, produces a
#     warning and is never counted as a definition, so it cannot fail the check.
set -euo pipefail
shopt -s nullglob

dir="${1:-memory}"
fail=0

# A wrong path must not look like a pass: every file below is skipped when
# missing, so with no directory (or none of the three files) nothing is checked.
if [ ! -d "$dir" ]; then
  echo "::error::memory directory not found: $dir"
  exit 1
fi
if [ ! -f "$dir/DECISIONS.md" ] && [ ! -f "$dir/SESSIONS.md" ] && [ ! -f "$dir/CONTEXT.md" ]; then
  echo "::error::no DECISIONS.md, SESSIONS.md or CONTEXT.md found in $dir, wrong path?"
  exit 1
fi

# Where each ID is defined (from the schema files). Only these positions count;
# an ID mentioned anywhere else (Index line, archive pointer, title, prose,
# Next steps) is a reference, never a definition.
#   DEC   heading line of a DECISIONS entry, followed by its first field
#   SESS  heading line of a SESSIONS entry, followed by its first field
# The separator after the ID is any single token (this does not hard-code a
# dash style) and the date is required. A heading-shaped line that fails the
# heading-plus-first-field test is reported as a warning, not an error: it may
# be a quoted example or a malformed entry, and the script cannot tell which.
# Patterns avoid {n,} intervals so they work in mawk as well as gawk.
ITEM_ID='ITEM-[0-9][0-9][0-9]+'
DEC_HEADING='^### DEC-[0-9][0-9][0-9]+ [^ ]+ [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
SESS_HEADING='^## SESS-[0-9][0-9][0-9]+ [^ ]+ [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'

# entry_ids FILE KIND HEADING_RE FIRST_FIELD_RE : one defining ID per real entry.
entry_ids() {
  awk -v file="$1" -v kind="$2" -v head="$3" -v first="$4" '
    { sub(/\r$/, ""); line[NR] = $0 }
    END {
      loose = "^[[:space:]]*#+[[:space:]]*" kind "-[0-9]+"
      for (i = 1; i <= NR; i++) {
        if (line[i] !~ loose) continue
        ok = 0
        if (line[i] ~ head) {
          j = i + 1
          while (j <= NR && line[j] ~ /^[[:space:]]*$/) j++
          if (j <= NR && line[j] ~ first) ok = 1
        }
        if (ok) {
          match(line[i], kind "-[0-9]+")
          print substr(line[i], RSTART, RLENGTH)
        } else {
          printf "::warning file=%s,line=%d::looks like a %s entry heading but is not in the schema shape (strict heading, then %s): %s\n", file, i, kind, first, line[i] > "/dev/stderr"
        }
      }
    }' "$1"
}

# check LABEL KIND HEADING_RE FIRST_FIELD_RE HOW_TO_FIX FILE...
check() {
  local label="$1" kind="$2" heading="$3" firstfield="$4" fix="$5"; shift 5
  local f dupes
  dupes=$(
    for f in "$@"; do
      [ -f "$f" ] || continue
      entry_ids "$f" "$kind" "$heading" "$firstfield" | sed "s|\$|\t$f|"
    done | awk -F'\t' '
      { n[$1]++; where[$1] = where[$1] " " $2 }
      END { for (id in n) if (n[id] > 1) print id "\t" where[id] }' | sort
  )
  if [ -n "$dupes" ]; then
    while IFS=$'\t' read -r id where; do
      echo "::error::Duplicate $label $id is defined more than once, in:$where. $fix"
    done <<<"$dupes"
    fail=1
  fi
}

# closed_item_ids FILE... : reads each SESSIONS entry's Closed field against a
# strict whitelist (DEC-004; vocabulary from CONTEXT-SCHEMA.md). Output lines:
#   CLOSED<TAB>ITEM-NNN          the subject of a real closure (it is now retired)
#   BAD<TAB>file<TAB>line<TAB>text   an entry that matches none of the forms
# The field runs from "Closed:" to the next field label or heading; blank lines
# inside it are ignored; an indented line continues the entry above it. Entries
# must be "- " bullets, one item each (or inline after "Closed:"); "None" is ok.
# "moved to" and "re-minted as" are valid but not closures, so they retire
# nothing: the item is still open.
closed_item_ids() {
  [ "$#" -gt 0 ] || return 0
  awk -v id="$ITEM_ID" -v dec="DEC-[0-9][0-9][0-9]+" '
    function flush(   t) {
      if (cur == "") return
      t = cur; cur = ""
      if (t ~ ("^" id " (resolved|dropped)$") || \
          t ~ ("^" id " (decided|deferred) per " dec "$") || \
          t ~ ("^" id " merged into " id "$") || \
          t ~ ("^" id " split into " id "(, " id ")*$")) {
        match(t, id); print "CLOSED\t" substr(t, RSTART, RLENGTH)
      } else if (t ~ ("^" id " moved to .+$") || t ~ ("^" id " re-minted as " id "$")) {
        # valid, but not a closure
      } else {
        printf "BAD\t%s\t%d\t%s\n", curfile, curline, t
      }
    }
    function begin(s, n) { flush(); cur = s; curline = n; curfile = FILENAME }
    FNR == 1 { flush(); inblock = 0 }
    { sub(/\r$/, "") }
    /^Closed:/ {
      flush(); inblock = 1
      rest = $0; sub(/^Closed:[ \t]*/, "", rest)
      if (rest != "" && rest != "None") begin(rest, FNR)
      next
    }
    inblock && /^[A-Z][A-Za-z ]*:/ { flush(); inblock = 0; next }
    inblock && /^#/                { flush(); inblock = 0; next }
    inblock && /^[ \t]*$/          { next }
    inblock && /^[ \t]+/ && cur != "" { s = $0; sub(/^[ \t]+/, "", s); cur = cur " " s; next }
    inblock {
      s = $0
      if (s ~ /^- /) { sub(/^- /, "", s) } else { s = "(not a - bullet) " s }
      begin(s, FNR); next
    }
    END { flush() }
  ' "$@"
}

# context_items FILE : open ITEM IDs, one per line. ITEMs are defined only by a
# canonical "- ITEM-NNN:" bullet under "## Active blockers" or "## Open
# questions" (CONTEXT-SCHEMA.md). Other sections (e.g. Recently completed) may
# mention an ID without it counting as open. A bullet in those two sections that
# starts like an item but is not canonical ("* ITEM-5:", indented, bold, a space
# before the colon) is an error line "BAD<TAB>line<TAB>text". Wrapped
# continuation lines (no bullet marker) are ignored. Warns if neither section
# exists at all.
context_items() {
  awk -v file="$1" -v id="$ITEM_ID" '
    { sub(/\r$/, "") }
    /^## / { insec = ($0 ~ /^## Active blockers/ || $0 ~ /^## Open questions/); if (insec) seen = 1; next }
    insec && $0 ~ ("^- " id ":") { match($0, id); print substr($0, RSTART, RLENGTH); next }
    insec && $0 ~ ("^[[:space:]]*[-*+][[:space:]]+[*_]*" id) { printf "BAD\t%d\t%s\n", FNR, $0 }
    END { if (!seen) printf "::warning file=%s::no \"## Active blockers\" or \"## Open questions\" section found, ITEM checks have nothing to read\n", file > "/dev/stderr" }
  ' "$1"
}

# --- DEC / SESS -------------------------------------------------------------
check DEC DEC "$DEC_HEADING" '^Context:' \
  "Resolve by hand at merge time: keep the earlier entry, renumber the later one (in file order) to the next unused DEC number, and fix any references to it." \
  "$dir"/DECISIONS.md "$dir"/DECISIONS-ARCHIVE/*.md

check SESS SESS "$SESS_HEADING" '^Summary:' \
  "Resolve by hand at merge time: keep the earlier entry, renumber the later one (in file order) to the next unused SESS number." \
  "$dir"/SESSIONS.md "$dir"/SESSIONS-ARCHIVE/*.md

# --- Closed entries (SESSIONS) ---------------------------------------------
# Validated whenever a SESSIONS file exists, whether or not CONTEXT.md does.
sessions=("$dir"/SESSIONS.md "$dir"/SESSIONS-ARCHIVE/*.md)
existing=()
for f in "${sessions[@]}"; do [ -f "$f" ] && existing+=("$f"); done

closed_out=$(closed_item_ids "${existing[@]}")
while IFS=$'\t' read -r tag file lineno text; do
  [ "$tag" = BAD ] || continue
  echo "::error file=$file,line=$lineno::Closed entry does not match an allowed form: \"$text\". One item per line, exactly one of: ITEM-NNN resolved | ITEM-NNN decided per DEC-NNN | ITEM-NNN deferred per DEC-NNN | ITEM-NNN merged into ITEM-MMM | ITEM-NNN split into ITEM-MMM, ITEM-NNN | ITEM-NNN dropped | ITEM-NNN moved to <section> | ITEM-NNN re-minted as ITEM-MMM. No extra words on the line."
  fail=1
done <<<"$closed_out"
closed_ids=$(printf '%s\n' "$closed_out" | awk -F'\t' '$1 == "CLOSED" { print $2 }' | sort -u)

# --- ITEM (CONTEXT) ---------------------------------------------------------
context="$dir/CONTEXT.md"
if [ -f "$context" ]; then
  items_out=$(context_items "$context")
  while IFS=$'\t' read -r tag lineno text; do
    [ "$tag" = BAD ] || continue
    echo "::error file=$context,line=$lineno::Not a canonical item bullet: \"$text\". Items under Active blockers / Open questions must be written exactly as \"- ITEM-NNN: text\" (a dash, one space, the ID, a colon)."
    fail=1
  done <<<"$items_out"
  open_list=$(printf '%s\n' "$items_out" | grep -E "^$ITEM_ID\$" || true)

  dupes=$(printf '%s\n' "$open_list" | sort | uniq -d)
  for id in $dupes; do
    echo "::error::Duplicate ITEM $id appears more than once in $context. Re-mint the later one (in file order) under a fresh ITEM number (one above the highest ever used, open or closed) and note 'ITEM-NNN re-minted as ITEM-MMM' in that session's SESSIONS.md entry."
    fail=1
  done

  open_ids=$(printf '%s\n' "$open_list" | sort -u)
  reused=$(comm -12 <(printf '%s\n' "$open_ids") <(printf '%s\n' "$closed_ids") | grep -v '^$' || true)
  for id in $reused; do
    echo "::error::$id is open in $context but a SESSIONS entry already records it as closed. Retired ITEM numbers are never reused. Re-mint the open item under a fresh ITEM number (one above the highest ever used, open or closed) and note '$id re-minted as ITEM-MMM' in that session's SESSIONS.md entry."
    fail=1
  done
fi

exit "$fail"
