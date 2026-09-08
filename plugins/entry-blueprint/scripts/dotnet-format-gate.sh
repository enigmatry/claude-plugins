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

# Workspace: prefer .slnx, then .sln, then a single .csproj at the root.
ws=$(ls -1 ./*.slnx 2>/dev/null | head -n 1)
[ -z "$ws" ] && ws=$(ls -1 ./*.sln 2>/dev/null | head -n 1)
[ -z "$ws" ] && [ "$(ls -1 ./*.csproj 2>/dev/null | wc -l)" -eq 1 ] && ws=$(ls -1 ./*.csproj)
[ -z "$ws" ] && exit 0

changed=$(git status --porcelain --untracked-files=all 2>/dev/null | grep -E '\.cs$' | grep -vE '^ ?D' | sed 's/^...//; s/^"\(.*\)"$/\1/')
[ -z "$changed" ] && exit 0

block() {
  # $1 = headline, stdin = tool output. Make it JSON-safe without escaping:
  # drop CR, join lines, quotes -> apostrophes, backslashes -> slashes, cap size.
  detail=$(head -c 6000 | tr -d '\r' | tr '\n' ' ' | tr '"' "'" | tr '\\' '/' | sed 's/  */ /g')
  printf '{"decision":"block","reason":"%s %s"}' "$1" "$detail"
  exit 0
}

# shellcheck disable=SC2086
fmt_out=$(dotnet format "$ws" --severity info --no-restore --include $changed 2>&1) \
  || printf '%s' "$fmt_out" | block "dotnet format failed on the changed .cs files. Fix the problem, then stop again. Output:"

build_out=$(dotnet build "$ws" --no-restore -nologo -clp:NoSummary -v q 2>&1) \
  || printf '%s' "$build_out" | grep -E 'error|warning' | sort -u | block "dotnet build failed after formatting (TreatWarningsAsErrors is on). Fix every error below, then stop again. Errors:"

exit 0
