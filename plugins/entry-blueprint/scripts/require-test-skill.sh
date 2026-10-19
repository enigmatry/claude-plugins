#!/bin/sh
# PreToolUse hook (Edit|Write|MultiEdit|Skill): before the first write to a C# test
# file in a session, require entry-blueprint:csharp-unit-tests to be loaded.
# Exit 2 + stderr blocks the call and tells Claude why. Loading the skill through
# the Skill tool sets the per-session marker, so the edit is only blocked when the
# skill was not loaded yet; otherwise it fires once per session, then stays quiet.
raw=$(cat)

field() {
  printf '%s' "$raw" | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n 1
}

# Fall back to an hourly bucket so the hook stays active if the payload ever lacks a session id.
key=$(field session_id)
[ -z "$key" ] && key=$(date +%Y%m%d-%H)
marker="${TMPDIR:-/tmp}/claude-csharp-unit-tests-$key.marker"

if [ "$(field tool_name)" = "Skill" ]; then
  case "$(field skill)" in
    *csharp-unit-tests) touch "$marker" ;;
  esac
  exit 0
fi

file=$(field file_path | sed 's#\\#/#g; s#//*#/#g')
case "$file" in
  */bin/*|*/obj/*) exit 0 ;;
  *Fixture.cs|*Tests.cs) ;;
  *) exit 0 ;;
esac
[ -f "$marker" ] && exit 0
touch "$marker"

echo "You are about to write a C# test (${file##*/}). Load the entry-blueprint:csharp-unit-tests skill first (Skill tool) and follow it, including the project notes it points to: the rules on test naming, fixture accessibility, assertion count, parameterization and existing builders are not in CLAUDE.md. Then retry the edit; this check fires once per session." >&2
exit 2
