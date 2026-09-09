#!/bin/sh
# Stop-hook gate: when uncommitted .cs files exist, apply `dotnet format`
# (whitespace + style + analyzers, severity info so suggestion-level
# .editorconfig rules are applied too) to them, then build. Blocks the stop
# when formatting or the build fails.
# Loop-safe like code-review-gate.sh: lets the continuation stop through
# (stop_hook_active = true), so it blocks at most once per batch of changes.
raw=$(cat)

printf '%s' "$raw" | grep -Eq '"stop_hook_active"[[:space:]]*:[[:space:]]*true' && exit 0
command -v dotnet >/dev/null 2>&1 || exit 0

root="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$root" ]; then
  root=$(printf '%s' "$raw" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1 | tr '\\' '/' | sed 's#//*#/#g')
fi
[ -z "$root" ] && root=$(pwd)
cd "$root" || exit 0
[ -f .editorconfig ] || exit 0

# Workspace: prefer .slnx, then .sln, then a single .csproj at the root.
ws=$(ls -1 ./*.slnx 2>/dev/null | head -n 1)
[ -z "$ws" ] && ws=$(ls -1 ./*.sln 2>/dev/null | head -n 1)
[ -z "$ws" ] && [ "$(ls -1 ./*.csproj 2>/dev/null | wc -l)" -eq 1 ] && ws=$(ls -1 ./*.csproj)
[ -z "$ws" ] && exit 0

# Changed .cs files as one argument each in "$@", as paths relative to $root:
# `dotnet format --include` only matches paths relative to the workspace
# folder (absolute paths are silently ignored). --relative and ls-files both
# report relative to the cwd and skip files above it, which is right: those are
# not in the solution. -z gives unquoted paths; renames show only the new name;
# deletions are dropped by the -f test. Paths containing a newline are not
# supported.
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
set --
while IFS= read -r p; do
  case "$p" in *.cs) ;; *) continue ;; esac
  [ -f "$p" ] && set -- "$@" "$p"
done <<LIST
$({ git diff --name-only -z --relative HEAD; git ls-files -o --exclude-standard -z; } 2>/dev/null | tr '\0' '\n')
LIST
[ $# -eq 0 ] && exit 0

block() {
  # $1 = headline, $2 = tool output. Runs in the parent shell so `exit` ends
  # the script: exactly one JSON object is ever printed. Make the text
  # JSON-safe without escaping: join lines, drop CR and other control
  # characters, quotes -> apostrophes, backslashes -> slashes, cap size.
  detail=$(printf '%s' "$2" | head -c 6000 | tr '\n' ' ' | tr -d '\001-\037\177' | tr '"' "'" | tr '\\' '/' | sed 's/  */ /g')
  printf '{"decision":"block","reason":"%s %s"}' "$1" "$detail"
  exit 0
}

# Restore explicitly first: the blueprint uses RestorePackagesWithLockFile, so a
# changed PackageReference makes --no-restore fail, and dotnet format reports a
# failed restore as an unhandled-exception stack trace. This keeps the reason
# readable and lets format/build skip their own (slower) restore.
restore_out=$(dotnet restore "$ws" -nologo -v q 2>&1) \
  || block "dotnet restore failed. Fix the package reference or lock file (packages.lock.json), then stop again. Output:" "$restore_out"

fmt_out=$(dotnet format "$ws" --severity info --no-restore --include "$@" 2>&1) \
  || block "dotnet format failed on the changed .cs files. Fix the problem, then stop again. Output:" "$fmt_out"

build_out=$(dotnet build "$ws" --no-restore -nologo -clp:NoSummary -v q 2>&1) \
  || block "dotnet build failed after formatting (TreatWarningsAsErrors is on). Fix every error below, then stop again. Errors:" "$(printf '%s\n' "$build_out" | grep -E 'error|warning' | sort -u)"

exit 0
