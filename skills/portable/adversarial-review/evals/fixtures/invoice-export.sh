#!/usr/bin/env bash
set -euo pipefail

# A Node project that lists a customer's invoices. The feature/invoice-export
# branch adds exportInvoices, which writes them to a CSV file as asked, and
# also a `format` option with a JSON renderer and a `delimiter` option that
# nobody asked for. The CSV it writes by default is correct, so what's left
# to find is the extra. Everything is committed and pushed.

# shellcheck source=scripts/evals/fixture-lib.sh
. "$EVAL_LIB"

eval_repo "$1"
cd "$1/repo"

cat >package.json <<'JSON'
{
	"name": "billing",
	"version": "1.0.0",
	"type": "module",
	"scripts": {
		"test": "node --test"
	}
}
JSON
mkdir -p src test
cat >src/invoices.js <<'JS'
const INVOICES = [
	{ customerId: "c1", number: "INV-002", date: "2026-02-03", amountCents: 4500 },
	{ customerId: "c1", number: "INV-001", date: "2026-01-15", amountCents: 1999 },
	{ customerId: "c2", number: "INV-003", date: "2026-02-10", amountCents: 120000 },
];

// A customer's invoices, in no particular order.
export function invoicesFor(customerId) {
	return INVOICES.filter((invoice) => invoice.customerId === customerId);
}
JS
eval_commit . "feat: list a customer's invoices"
git push --quiet -u origin main

git switch --quiet -c feature/invoice-export
cat >src/export.js <<'JS'
import { writeFile } from "node:fs/promises";
import { invoicesFor } from "./invoices.js";

function euros(cents) {
	return (cents / 100).toFixed(2);
}

const RENDERERS = {
	csv(invoices, { delimiter }) {
		const rows = [
			["date", "number", "amount"],
			...invoices.map((invoice) => [invoice.date, invoice.number, euros(invoice.amountCents)]),
		];
		return rows.map((row) => row.join(delimiter)).join("\n") + "\n";
	},
	json(invoices) {
		const records = invoices.map((invoice) => ({
			date: invoice.date,
			number: invoice.number,
			amount: euros(invoice.amountCents),
		}));
		return JSON.stringify(records, null, 2) + "\n";
	},
};

export async function exportInvoices(customerId, path, { format = "csv", delimiter = "," } = {}) {
	const render = RENDERERS[format];
	if (!render) {
		throw new Error(`unknown export format: ${format}`);
	}
	const invoices = [...invoicesFor(customerId)].sort((a, b) => a.date.localeCompare(b.date));
	await writeFile(path, render(invoices, { delimiter }));
}
JS
cat >test/export.test.js <<'JS'
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { exportInvoices } from "../src/export.js";

test("writes a customer's invoices as CSV, oldest first", async () => {
	const path = join(await mkdtemp(join(tmpdir(), "export-")), "invoices.csv");
	await exportInvoices("c1", path);
	assert.equal(
		await readFile(path, "utf8"),
		"date,number,amount\n2026-01-15,INV-001,19.99\n2026-02-03,INV-002,45.00\n",
	);
});
JS
eval_commit . "feat: export a customer's invoices"
git push --quiet -u origin feature/invoice-export
