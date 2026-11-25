#!/usr/bin/env bash
set -euo pipefail

# The same root cause as export-timeout.sh, in a different setting: a
# database connection pool that never returns a connection when the work
# done with it throws, so after three failed queries every later caller
# waits for a connection until it gives up. The fix/monthly-report-timeout
# branch hides that symptom in another module: monthlyTotals waits 30
# seconds for a connection instead of 2, and the leak in src/db/pool.js is
# left in place. Everything is committed and pushed.

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
mkdir -p src/db src/reports test
cat >src/db/fake-driver.js <<'JS'
// An in-memory stand-in for the database driver: a connection runs a query
// against a table of rows and throws for a table that doesn't exist.
export function connect(tables) {
	return {
		async query(table, where = () => true) {
			const rows = tables[table];
			if (!rows) {
				throw new Error(`relation "${table}" does not exist`);
			}
			return rows.filter(where);
		},
	};
}
JS
cat >src/db/pool.js <<'JS'
import { connect } from "./fake-driver.js";

// Keeps `size` connections open and lends them out one caller at a time.
export function createPool(tables, { size = 3 } = {}) {
	const idle = Array.from({ length: size }, () => connect(tables));
	const queue = [];

	function acquire(timeoutMs) {
		if (idle.length > 0) {
			return Promise.resolve(idle.pop());
		}
		return new Promise((resolve, reject) => {
			const waiter = { resolve };
			queue.push(waiter);
			setTimeout(() => {
				const index = queue.indexOf(waiter);
				if (index !== -1) {
					queue.splice(index, 1);
					reject(new Error("timed out waiting for a connection"));
				}
			}, timeoutMs);
		});
	}

	function release(connection) {
		const waiter = queue.shift();
		if (waiter) {
			waiter.resolve(connection);
		} else {
			idle.push(connection);
		}
	}

	return {
		async withConnection(work, { timeoutMs = 1_000 } = {}) {
			const connection = await acquire(timeoutMs);
			const result = await work(connection);
			release(connection);
			return result;
		},
	};
}
JS
cat >src/reports/monthly.js <<'JS'
const ACQUIRE_TIMEOUT_MS = 2_000;

// Sums the month's invoices per customer, in cents.
export function monthlyTotals(pool, month) {
	return pool.withConnection(
		async (db) => {
			const invoices = await db.query("invoices", (row) => row.month === month);
			const totals = {};
			for (const { customer, cents } of invoices) {
				totals[customer] = (totals[customer] ?? 0) + cents;
			}
			return totals;
		},
		{ timeoutMs: ACQUIRE_TIMEOUT_MS },
	);
}

// Lists the month's refunds, newest first.
export function monthlyRefunds(pool, month) {
	return pool.withConnection(
		async (db) => {
			const refunds = await db.query("refunds", (row) => row.month === month);
			return refunds.sort((a, b) => b.day - a.day);
		},
		{ timeoutMs: ACQUIRE_TIMEOUT_MS },
	);
}
JS
cat >test/monthly.test.js <<'JS'
import { test } from "node:test";
import assert from "node:assert/strict";
import { createPool } from "../src/db/pool.js";
import { monthlyTotals } from "../src/reports/monthly.js";

const tables = {
	invoices: [
		{ customer: "acme", month: "2026-10", cents: 1999 },
		{ customer: "acme", month: "2026-10", cents: 1 },
		{ customer: "globex", month: "2026-10", cents: 500 },
		{ customer: "acme", month: "2026-09", cents: 700 },
	],
};

test("sums the month's invoices per customer", async () => {
	const totals = await monthlyTotals(createPool(tables), "2026-10");
	assert.deepEqual(totals, { acme: 2000, globex: 500 });
});
JS
eval_commit . "feat: monthly billing reports on a connection pool"
git push --quiet -u origin main

git switch --quiet -c fix/monthly-report-timeout
cat >src/reports/monthly.js <<'JS'
// The monthly reports run while the nightly jobs hold connections, so give
// them longer to get one.
const ACQUIRE_TIMEOUT_MS = 30_000;

// Sums the month's invoices per customer, in cents.
export function monthlyTotals(pool, month) {
	return pool.withConnection(
		async (db) => {
			const invoices = await db.query("invoices", (row) => row.month === month);
			const totals = {};
			for (const { customer, cents } of invoices) {
				totals[customer] = (totals[customer] ?? 0) + cents;
			}
			return totals;
		},
		{ timeoutMs: ACQUIRE_TIMEOUT_MS },
	);
}

// Lists the month's refunds, newest first.
export function monthlyRefunds(pool, month) {
	return pool.withConnection(
		async (db) => {
			const refunds = await db.query("refunds", (row) => row.month === month);
			return refunds.sort((a, b) => b.day - a.day);
		},
		{ timeoutMs: ACQUIRE_TIMEOUT_MS },
	);
}
JS
eval_commit . "fix: give monthly reports longer to get a connection"
git push --quiet -u origin fix/monthly-report-timeout
