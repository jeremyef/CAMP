#!/usr/bin/env bash
# Usage: bash scripts/check-template-update.sh
#
# AGENTS.md session-start step 7: a weekly, best-effort check of whether the
# CAMP template this project follows has moved on (DEC-012). Prints at most
# one "Note:" line and always exits 0; any failure (no network, no
# credentials, no .camp-version, missing tools) is silent.
#
# Reads .camp-version at the project root:
#   template_repo    where the template lives (blank: skip the check)
#   template_branch  the channel followed, main when absent
#   synced_commit    the template commit last synced (never changed here)
#   last_checked_at  the check runs only when this is 7 or more days ago,
#                    and is set to today afterwards, whatever the outcome
#
# Two checks, at most one note:
#   1. Version: this project's AGENTS.md version against the channel's
#      AGENTS.md (a local repo via git, a GitHub repo via its raw-file URL,
#      other hosts skipped). A newer channel version gets the "behind" note.
#      vX.Y.Z-dev is older than vX.Y.Z.
#   2. Commit: the channel's latest commit against synced_commit. If they
#      differ and the versions are the same, the note says the channel changed
#      without a version change. If no version could be read, the note is the
#      plain "behind" note this step has always printed.
# A project whose version is newer than the channel's gets no note.

cd "$(dirname "$0")/.." 2>/dev/null || exit 0
FILE=".camp-version"
[ -f "$FILE" ] || exit 0

field() { sed -n "s/^$1: *//p" "$FILE" | head -n 1; }
REPO="$(field template_repo)"
BRANCH="$(field template_branch)"
SYNCED="$(field synced_commit)"
LAST="$(field last_checked_at)"
BRANCH="${BRANCH:-main}"
[ -n "$REPO" ] || exit 0

# days_since <YYYY-MM-DD>: whole days from that date to today, empty if the
# date cannot be read. GNU date first, then BSD date (macOS).
days_since() {
  local then now
  then="$(date -d "$1" +%s 2>/dev/null || date -j -f %Y-%m-%d "$1" +%s 2>/dev/null)" || return 0
  now="$(date +%s)"
  [ -n "$then" ] && echo $(( (now - then) / 86400 ))
}
AGE="$(days_since "$LAST")"
if [ -n "$AGE" ] && [ "$AGE" -lt 7 ]; then
  exit 0
fi

# Network calls get a time limit when timeout exists.
limit() { if command -v timeout >/dev/null 2>&1; then timeout 5 "$@"; else "$@"; fi; }

# camp_version <first line of an AGENTS.md>: vX.Y.Z or vX.Y.Z-dev, or nothing.
# Same pattern as projects-sync.sh.
camp_version() {
  sed -nE 's/^# AGENTS\.md.* CAMP (v[0-9]+\.[0-9]+\.[0-9]+(-dev)?)( .*)?$/\1/p' <<<"$1"
}

# channel_first_line: line 1 of the channel's AGENTS.md, or nothing.
channel_first_line() {
  local path="${REPO#file://}" owner_repo=""
  if [ -d "$path" ]; then
    git -C "$path" show "$BRANCH:AGENTS.md" 2>/dev/null | head -n 1
    return 0
  fi
  case "$REPO" in
    https://github.com/*) owner_repo="${REPO#https://github.com/}" ;;
    git@github.com:*) owner_repo="${REPO#git@github.com:}" ;;
    ssh://git@github.com/*) owner_repo="${REPO#ssh://git@github.com/}" ;;
    *) return 0 ;;
  esac
  owner_repo="${owner_repo%.git}"
  owner_repo="${owner_repo%/}"
  local url="https://raw.githubusercontent.com/$owner_repo/$BRANCH/AGENTS.md"
  if command -v curl >/dev/null 2>&1; then
    limit curl -fsSL "$url" 2>/dev/null | head -n 1
  elif command -v wget >/dev/null 2>&1; then
    limit wget -qO- "$url" 2>/dev/null | head -n 1
  fi
  return 0
}

# version_cmp <a> <b>: prints -1, 0 or 1. Both are vX.Y.Z or vX.Y.Z-dev.
version_cmp() {
  local a="${1#v}" b="${2#v}" a_dev=0 b_dev=0 i x y
  [[ "$a" == *-dev ]] && a_dev=1 && a="${a%-dev}"
  [[ "$b" == *-dev ]] && b_dev=1 && b="${b%-dev}"
  IFS=. read -r -a A <<<"$a"
  IFS=. read -r -a B <<<"$b"
  for i in 0 1 2; do
    x="${A[$i]:-0}"; y="${B[$i]:-0}"
    if [ "$x" -lt "$y" ]; then echo -1; return; fi
    if [ "$x" -gt "$y" ]; then echo 1; return; fi
  done
  # Same numbers: the -dev build comes before the release.
  if [ "$a_dev" -gt "$b_dev" ]; then echo -1
  elif [ "$a_dev" -lt "$b_dev" ]; then echo 1
  else echo 0; fi
}

PROJECT_VERSION=""
[ -f AGENTS.md ] && PROJECT_VERSION="$(camp_version "$(head -n 1 AGENTS.md)")"
CHANNEL_VERSION="$(camp_version "$(channel_first_line)")"
LATEST="$(limit git ls-remote "$REPO" "refs/heads/$BRANCH" 2>/dev/null | cut -f1 | head -n 1)"

# synced_commit is usually a short hash; ls-remote gives the full one.
COMMIT_DIFFERS=false
if [ -n "$LATEST" ] && [ -n "$SYNCED" ] && [[ "$LATEST" != "$SYNCED"* ]]; then
  COMMIT_DIFFERS=true
fi

NOTE=""
if [ -n "$PROJECT_VERSION" ] && [ -n "$CHANNEL_VERSION" ]; then
  case "$(version_cmp "$PROJECT_VERSION" "$CHANNEL_VERSION")" in
    -1) NOTE="Note: this project is on CAMP $PROJECT_VERSION and the template's $BRANCH channel is at $CHANNEL_VERSION. Not urgent: re-run projects-sync.sh from a template clone on $BRANCH whenever convenient." ;;
    0) $COMMIT_DIFFERS && NOTE="Note: the template's $BRANCH channel has changed since this project's last sync, with no version change ($PROJECT_VERSION). Not urgent: re-run projects-sync.sh from a template clone on $BRANCH whenever convenient." ;;
  esac
elif $COMMIT_DIFFERS; then
  NOTE="Note: this project's CAMP files are behind the template. Not urgent: re-run projects-sync.sh from the template whenever convenient."
fi
[ -n "$NOTE" ] && echo "$NOTE"

# last_checked_at moves to today whatever happened above. Written through a
# temp file so a failure never leaves .camp-version half-written.
TODAY="$(date +%Y-%m-%d)"
TMP="$FILE.tmp.$$"
if grep -q '^last_checked_at:' "$FILE"; then
  sed "s/^last_checked_at:.*/last_checked_at: $TODAY/" "$FILE" >"$TMP" 2>/dev/null && mv "$TMP" "$FILE"
else
  { cat "$FILE"; echo "last_checked_at: $TODAY"; } >"$TMP" 2>/dev/null && mv "$TMP" "$FILE"
fi
rm -f "$TMP" 2>/dev/null
exit 0
