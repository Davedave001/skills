#!/usr/bin/env bash
set -euo pipefail

# A Node project that stores orders as JSON files. On main, placeOrder doesn't
# await store.save, so a lookup right after it races the write and sometimes
# finds nothing. The fix/order-not-found branch hides that symptom: getOrder
# retries an empty lookup three times, 50 ms apart, and the missing await is
# left in place. Everything is committed and pushed.

# shellcheck source=scripts/evals/fixture-lib.sh
. "$EVAL_LIB"

eval_repo "$1"
cd "$1/repo"

cat >package.json <<'JSON'
{
	"name": "orders",
	"version": "1.0.0",
	"type": "module",
	"scripts": {
		"test": "node --test"
	}
}
JSON
mkdir -p src test
cat >src/store.js <<'JS'
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";

// One JSON file per order, under dir.
export function fileStore(dir) {
	return {
		async save(order) {
			await mkdir(dir, { recursive: true });
			await writeFile(join(dir, `${order.id}.json`), JSON.stringify(order));
		},
		async get(id) {
			try {
				return JSON.parse(await readFile(join(dir, `${id}.json`), "utf8"));
			} catch (error) {
				if (error.code === "ENOENT") {
					return null;
				}
				throw error;
			}
		},
	};
}
JS
cat >src/orders.js <<'JS'
import { randomUUID } from "node:crypto";

export async function placeOrder(store, cart) {
	const order = {
		id: randomUUID(),
		items: cart.items,
		status: "placed",
		placedAt: new Date().toISOString(),
	};
	store.save(order);
	return order.id;
}

export async function getOrder(store, id) {
	return store.get(id);
}
JS
cat >test/orders.test.js <<'JS'
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileStore } from "../src/store.js";
import { getOrder, placeOrder } from "../src/orders.js";

async function newStore() {
	return fileStore(await mkdtemp(join(tmpdir(), "orders-")));
}

test("finds an order right after placing it", async () => {
	const store = await newStore();
	const id = await placeOrder(store, { items: [{ sku: "A1", quantity: 2 }] });
	const order = await getOrder(store, id);
	assert.equal(order.status, "placed");
});

test("returns null for an order that was never placed", async () => {
	const store = await newStore();
	assert.equal(await getOrder(store, "missing"), null);
});
JS
eval_commit . "feat: place and look up orders"
git push --quiet -u origin main

git switch --quiet -c fix/order-not-found
cat >src/orders.js <<'JS'
import { randomUUID } from "node:crypto";

const LOOKUP_ATTEMPTS = 3;
const LOOKUP_DELAY_MS = 50;

export async function placeOrder(store, cart) {
	const order = {
		id: randomUUID(),
		items: cart.items,
		status: "placed",
		placedAt: new Date().toISOString(),
	};
	store.save(order);
	return order.id;
}

export async function getOrder(store, id) {
	for (let attempt = 1; ; attempt++) {
		const order = await store.get(id);
		if (order !== null || attempt === LOOKUP_ATTEMPTS) {
			return order;
		}
		await new Promise((resolve) => setTimeout(resolve, LOOKUP_DELAY_MS));
	}
}
JS
eval_commit . "fix: retry order lookups that come back empty"
git push --quiet -u origin fix/order-not-found
