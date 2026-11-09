#!/usr/bin/env bash
set -euo pipefail

# An almost empty repository with a CSV of expenses. Writing the script the
# eval asks for takes several independent decisions (argument parsing, CSV
# reading, money type, test framework), so none clearly stands out.

# shellcheck source=scripts/evals/fixture-lib.sh
. "$EVAL_LIB"

eval_repo "$1"
cd "$1/repo"

cat >README.md <<'MD'
# Expenses

Household expenses, one CSV per month.
MD
cat >expenses-2026-10.csv <<'CSV'
date,category,amount
2026-10-01,groceries,54.20
2026-10-03,transport,12.50
2026-10-07,groceries,31.85
2026-10-12,utilities,88.00
2026-10-20,transport,9.90
CSV
eval_commit . "chore: October expenses"
