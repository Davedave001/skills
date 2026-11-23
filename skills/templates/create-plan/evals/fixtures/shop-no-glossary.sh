#!/usr/bin/env bash
set -euo pipefail

# The shop with no glossary at all, so the first plan that agrees on a term
# should offer to start one.

# shellcheck source=skills/templates/create-plan/evals/fixtures/shop.sh
. "$(dirname "$0")/shop.sh"

shop_base "$1"
git push --quiet -u origin main
