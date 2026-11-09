#!/usr/bin/env bash
set -euo pipefail

# A Node project whose invoice total adds prices as floats, so 0.1 + 0.2
# prints 0.30000000000000004. Fixing it means choosing how to handle money
# (integer cents, rounding, a decimal library...), a decision to explain.

# shellcheck source=scripts/evals/fixture-lib.sh
. "$EVAL_LIB"

eval_repo "$1"
cd "$1/repo"

cat >package.json <<'JSON'
{
	"name": "invoices",
	"version": "1.0.0",
	"type": "module",
	"scripts": {
		"test": "node --test"
	}
}
JSON
mkdir -p src test
cat >src/invoice.js <<'JS'
export function invoiceTotal(lines) {
	let total = 0;
	for (const line of lines) {
		total += line.price * line.quantity;
	}
	return total;
}

export function formatTotal(lines) {
	return `${invoiceTotal(lines)} EUR`;
}
JS
cat >test/invoice.test.js <<'JS'
import { test } from "node:test";
import assert from "node:assert/strict";
import { invoiceTotal } from "../src/invoice.js";

test("adds every line", () => {
	assert.equal(invoiceTotal([{ price: 2, quantity: 3 }, { price: 1, quantity: 1 }]), 7);
});
JS
eval_commit . "feat: invoice totals"
git push --quiet origin main
