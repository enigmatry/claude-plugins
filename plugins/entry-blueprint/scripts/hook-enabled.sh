#!/bin/sh
# Sourced by every hook script right after it reads its input: exits 0 unless the
# host project enables this hook through ENIGMATRY_ENABLED_HOOKS, e.g. in the `env`
# block of its .claude/settings.json. Unset or `all` enables every hook, `none`
# enables none, and a list enables only the hooks it names, by script name without
# the .sh extension, separated by spaces or commas. Renaming a script renames its
# switch, so update the README's hook table and tell consuming projects.
case " $(printf '%s' "${ENIGMATRY_ENABLED_HOOKS:-all}" | tr ',' ' ') " in
  *" all "*) ;;
  *" $(basename "$0" .sh) "*) ;;
  *) exit 0 ;;
esac
