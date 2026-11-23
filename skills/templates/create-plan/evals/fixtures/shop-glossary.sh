#!/usr/bin/env bash
set -euo pipefail

# The shop with a glossary that defines Customer and Order, lacks LineItem,
# and leaves basket against cart as an open naming decision. Saving a basket
# for later touches all three, and adds a new concept.

# shellcheck source=skills/templates/create-plan/evals/fixtures/shop.sh
. "$(dirname "$0")/shop.sh"

shop_base "$1"
shop_glossary
git push --quiet -u origin main
