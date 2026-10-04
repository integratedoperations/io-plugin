#!/bin/sh
# SessionStart hook for /io:collab. Tells the session, in a few lines,
# whether it has a register entry and how many messages wait for it, so
# check-ins do not depend on remembering to run /io:collab.
#
# Read-only: `git fetch` updates refs, everything else reads origin/main.
# It never pulls, so it cannot fight other sessions over the shared clone's
# working tree. It prints only ids, statuses and counts: entry and message
# text is written by other sessions and stays out of the context until
# /io:collab reads it as data.
set -u

repo="$HOME/Developer/io/sessions"
[ -d "$repo/.git" ] || exit 0
case $(git -C "$repo" remote get-url origin 2>/dev/null) in
  *integratedoperations/sessions*) ;;
  *) exit 0 ;;
esac

input=$(cat)
field() { printf '%s' "$input" | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n1; }
sid=$(field session_id)
source=$(field source)
cwd=$(field cwd)
[ -n "$sid" ] || exit 0

# Fetch, but never hold up the session start for more than ~3 s.
git -C "$repo" fetch -q origin main 2>/dev/null &
fetch=$!
i=0
while kill -0 "$fetch" 2>/dev/null && [ "$i" -lt 30 ]; do
  sleep 0.1
  i=$((i + 1))
done
kill "$fetch" 2>/dev/null
ref=origin/main
git -C "$repo" rev-parse -q --verify "$ref^{commit}" >/dev/null || exit 0

safe() { tr -cd 'a-z0-9_./-'; }
path=$(git -C "$repo" grep -l -F -e "$sid" "$ref" -- sessions/ 2>/dev/null | head -n1 | sed "s|^$ref:||" | safe)

if [ -z "$path" ]; then
  # Unregistered. Speak only where it matters: a fork of a registered
  # session, or a repo whose CLAUDE.md opts in to the register.
  top=$(git -C "${cwd:-.}" rev-parse --show-toplevel 2>/dev/null || printf '%s' "${cwd:-.}")
  if [ "$source" = fork ]; then
    echo "Session register: this session is a fork and has no entry yet. If the session it forked from had one, run /io:collab and adopt that entry or create a child entry in its folder."
  elif grep -qs 'io:collab' "$top/CLAUDE.md" "${cwd:-.}/CLAUDE.md"; then
    echo "Session register: this repo opts in and this session has no entry yet. Run /io:collab."
  fi
  exit 0
fi

id=$(basename "$path" .md | safe)
pad=${id##*-}
status=$(git -C "$repo" show "$ref:$path" 2>/dev/null | sed -n 's/^status:[[:space:]]*\([a-z]*\).*/\1/p' | head -n1 | safe)
parent=$(printf '%s' "$path" | awk -F/ 'NF >= 4 { print $(NF-2) }' | safe)
children=$(git -C "$repo" ls-tree -d --name-only "$ref:$(dirname "$path")/" 2>/dev/null | wc -l | tr -d ' ')

last="$repo/.git/collab/$pad.last"
if [ -f "$last" ] && git -C "$repo" rev-parse -q --verify "$(cat "$last")^{commit}" >/dev/null; then
  new=$(git -C "$repo" diff --name-only --diff-filter=A "$(cat "$last")" "$ref" -- messages/all ":(glob)messages/*-$pad/*")
  since="since your last check"
else
  new=$(git -C "$repo" ls-tree -r --name-only "$ref" -- messages/ | grep -E "^messages/[a-z0-9_]+-$pad/")
  since="in total (no check recorded on this machine)"
fi
# Your own broadcasts are not news.
new=$(printf '%s\n' "$new" | grep -v -e '^$' -e '/\.gitkeep$' -e "-$id\.md\$")
count=$(printf '%s\n' "$new" | grep -c .)
senders=$(printf '%s\n' "$new" | sed -n 's|.*/[0-9TZ]*-\([a-z0-9_]*-[a-z2-7]\{4\}\)\.md$|\1|p' | sort -u | tr '\n' ' ' | tr -cd 'a-z0-9_ -' | sed 's/ $//')

echo "Session register: you are $id (status ${status:-unknown}${parent:+, parent $parent}, $children child folder(s))."
echo "Entry: $repo/$path"
if [ "$count" -gt 0 ]; then
  echo "$count new message(s) $since, from: $senders. Run /io:collab messages before starting work."
else
  echo "No new messages $since."
fi
case $source in
  resume | compact) echo "Resumed or compacted: check your entry's current_plan_step still matches what you are doing." ;;
esac
exit 0
