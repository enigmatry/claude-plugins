#!/bin/sh
# Sourced by every hook script right after it reads its input: exits 0 when the
# host project lists this hook in ENIGMATRY_DISABLED_HOOKS, e.g. in the `env`
# block of its .claude/settings.json. A hook is named after its script without
# the .sh extension; names are separated by spaces or commas. Renaming a script
# renames its switch, so update the README's hook table and tell consuming projects.
case " $(printf '%s' "${ENIGMATRY_DISABLED_HOOKS:-}" | tr ',' ' ') " in
  *" $(basename "$0" .sh) "*) exit 0 ;;
esac
