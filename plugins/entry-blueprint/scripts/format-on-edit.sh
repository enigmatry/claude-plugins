#!/bin/sh
# PostToolUse hook (Edit|Write|MultiEdit): run `dotnet format whitespace` on the
# edited .cs file in folder mode. Folder mode needs no project or solution, so it
# is fast enough to run after every edit. Style and analyzer fixes need the
# workspace and run once in the Stop hook (dotnet-format-gate.sh).
#
# If the formatter changed the file, tell Claude to re-read it before the next
# edit, otherwise the next Edit will be refused as "modified since read".
raw=$(cat)

command -v dotnet >/dev/null 2>&1 || exit 0

file=$(printf '%s' "$raw" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1 | sed 's#\\#/#g; s#//*#/#g')
case "$file" in
  *.cs) ;;
  *) exit 0 ;;
esac
[ -f "$file" ] || exit 0

root="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$root" ]; then
  root=$(printf '%s' "$raw" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1 | sed 's#\\#/#g; s#//*#/#g')
fi
[ -z "$root" ] && root=$(pwd)
[ -f "$root/.editorconfig" ] || exit 0

before=$(cksum < "$file")
dotnet format whitespace "$root" --folder --include "$file" >/dev/null 2>&1
after=$(cksum < "$file")

if [ "$before" != "$after" ]; then
  printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"dotnet format whitespace reformatted %s to match .editorconfig. Re-read it before editing it again."}}' "$file"
fi
exit 0
