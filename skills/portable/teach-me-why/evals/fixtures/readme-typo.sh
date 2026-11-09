#!/usr/bin/env bash
set -euo pipefail

# A repository whose README has a typo, for a session that does almost
# nothing, so a question about an unrelated topic is clearly out of scope.

# shellcheck source=scripts/evals/fixture-lib.sh
. "$EVAL_LIB"

eval_repo "$1"
cd "$1/repo"

cat >README.md <<'MD'
# Notes

A place to keep my notes. Run `./build.sh` to genrate the site.
MD
eval_commit . "docs: readme"
