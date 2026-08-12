#!/bin/sh
# Stop-hook gate: require entry-blueprint:code-review-blueprint before finishing
# when source files changed.
# Loop-safe: allows immediately when the stop is itself a continuation of this hook
# (stop_hook_active = true), so it blocks at most once per batch of changes.
raw=$(cat)

# Already continuing because of this hook -> let it through (prevents infinite loop).
printf '%s' "$raw" | grep -Eq '"stop_hook_active"[[:space:]]*:[[:space:]]*true' && exit 0

# Look for uncommitted source files (.cs / .ts / .html).
if git status --porcelain --untracked-files=all 2>/dev/null | grep -Eq '\.(cs|ts|html)$'; then
  printf '%s' '{"decision":"block","reason":"Uncommitted source files (.cs/.ts/.html) detected. Run the entry-blueprint:code-review-blueprint skill over the diff before finishing, address any findings, then stop again."}'
fi

exit 0
