#!/usr/bin/env bash
#
# Verifies wrappers/main.tf passes through every variable the root module declares.
#
# The wrapper is maintained by hand rather than generated; CONTRIBUTING.md explains
# why. This guards against it drifting from the root module.
#
# Uses grep/sed rather than rg so it runs on a bare CI image.

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

root_vars="$(grep -oE '^variable "[^"]+"' variables.tf \
  | sed 's/^variable "//; s/"$//' | sort)"

# Extracts the argument names passed to the wrapped module. `source` and
# `for_each` also match; harmless, since only root variables missing from this
# set are reported.
#
# The character class includes digits: this module has an `s3` variable, and
# without them it would be reported as missing on every run.
wired="$(grep -oE '^  [a-z0-9_]+ +=' wrappers/main.tf | tr -d ' =' | sort)"

missing="$(comm -23 <(printf '%s\n' "$root_vars") <(printf '%s\n' "$wired"))"

if [[ -n "$missing" ]]; then
  echo "wrappers/main.tf does not pass through every root module variable." >&2
  echo "Missing:" >&2
  printf '%s\n' "$missing" | sed 's/^/  - /' >&2
  echo >&2
  echo "Add each as:" >&2
  echo '  <name> = try(each.value.<name>, var.defaults.<name>, <default>)' >&2
  exit 1
fi

echo "wrappers/main.tf is in sync with $(printf '%s\n' "$root_vars" | wc -l | tr -d ' ') root variables"
