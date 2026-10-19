#!/bin/sh
# Gate C# test edits on the entry-blueprint:csharp-unit-tests skill being loaded.
# - PostToolUse (Skill) and UserPromptExpansion (/csharp-unit-tests): record that
#   the skill loaded, in a marker per session and per subagent (a subagent does
#   not inherit the skill its parent loaded).
# - PreToolUse (Edit|Write|MultiEdit) of a *Fixture.cs / *Tests.cs file: block
#   (exit 2 + stderr) until that marker exists.
raw=$(cat)

field() {
  printf '%s' "$raw" | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n 1
}

# Fall back to an hourly bucket so the gate stays active if the payload ever lacks a session id.
key=$(field session_id)
[ -z "$key" ] && key=$(date +%Y%m%d-%H)
agent=$(field agent_id)
[ -n "$agent" ] && key="$key-$agent"
marker="${TMPDIR:-/tmp}/claude-csharp-unit-tests-$key.marker"

case "$(field hook_event_name)" in
  PostToolUse)
    [ "$(field skill)" = "entry-blueprint:csharp-unit-tests" ] && touch "$marker"
    exit 0 ;;
  UserPromptExpansion)
    # The bare name only counts for a plugin skill; a project or personal skill can share it.
    case "$(field command_source):$(field command_name)" in
      plugin:csharp-unit-tests|*:entry-blueprint:csharp-unit-tests) touch "$marker" ;;
    esac
    exit 0 ;;
esac

file=$(field file_path | sed 's#\\#/#g; s#//*#/#g')
case "$file" in
  */bin/*|*/obj/*) exit 0 ;;
  *Fixture.cs|*Tests.cs) ;;
  *) exit 0 ;;
esac
[ -f "$marker" ] && exit 0

echo "You are about to write a C# test (${file##*/}). Load the entry-blueprint:csharp-unit-tests skill first (Skill tool, skill: entry-blueprint:csharp-unit-tests) and follow it, including the project notes it points to: the rules on test naming, fixture accessibility, assertion count, parameterization and existing builders are not in CLAUDE.md. Test-file edits stay blocked until the skill is loaded; then retry the edit." >&2
exit 2
