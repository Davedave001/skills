#!/usr/bin/env bash
set -euo pipefail

# A Node client for a shop's backend. AGENTS.md says to call the backend
# through apiClient, but the history shows `fetch` called directly twice,
# each fixed afterwards: a mistake a lint rule can catch. The ESLint config
# has only general rules, so nothing in it hints at one. Its integration
# tests hit a payments sandbox, whose quirks no check in the code can see.
# ESLint is installed for real (with a throwaway npm cache), so the agent can
# run the linter.

# shellcheck source=scripts/evals/fixture-lib.sh
. "$EVAL_LIB"

eval_repo "$1"
cd "$1/repo"

cat >package.json <<'JSON'
{
	"name": "shop-client",
	"version": "1.0.0",
	"private": true,
	"type": "module",
	"scripts": {
		"lint": "eslint .",
		"test": "node --test 'test/unit/*.test.js'",
		"test:integration": "node --test 'test/integration/*.test.js'"
	}
}
JSON
cat >.gitignore <<'TXT'
node_modules/
TXT
cat >AGENTS.md <<'MD'
# Shop client

The client the storefront uses to talk to the shop's backend: orders, invoices and checkout.

## Checks

Run `npm run lint` and `npm test` before finishing a change. `npm run test:integration` runs checkout against the staging backend and the payments sandbox, so it needs network.

## Conventions

- Call the backend through `apiClient` in `src/lib/api-client.js`: it adds the auth header and retries requests that fail with a 5xx.
- Amounts are integer cents everywhere. Format them for display only with `formatCents` in `src/lib/format.js`.
MD
cat >eslint.config.js <<'JS'
export default [
	{
		files: ["**/*.js"],
		languageOptions: {
			ecmaVersion: 2024,
			sourceType: "module",
			globals: {
				fetch: "readonly",
				process: "readonly",
			},
		},
		rules: {
			"eqeqeq": "error",
			"no-undef": "error",
			"no-unused-vars": "error",
			"prefer-const": "error",
		},
	},
];
JS
mkdir -p src/lib src/features test/unit test/integration
cat >src/lib/auth.js <<'JS'
export function getToken() {
	return process.env.SHOP_API_TOKEN ?? "";
}
JS
cat >src/lib/api-client.js <<'JS'
import { getToken } from "./auth.js";

const BASE_URL = process.env.SHOP_API_URL ?? "https://api.shop.example";
const ATTEMPTS = 3;

async function request(method, path, body) {
	for (let attempt = 1; ; attempt++) {
		const response = await fetch(`${BASE_URL}${path}`, {
			method,
			headers: {
				Authorization: `Bearer ${getToken()}`,
				"Content-Type": "application/json",
			},
			body: body === undefined ? undefined : JSON.stringify(body),
		});
		if (response.status >= 500 && attempt < ATTEMPTS) {
			continue;
		}
		if (!response.ok) {
			throw new Error(`${method} ${path} failed with ${response.status}`);
		}
		return response.json();
	}
}

export const apiClient = {
	get: (path) => request("GET", path),
	post: (path, body) => request("POST", path, body),
};
JS
cat >src/lib/format.js <<'JS'
export function formatCents(cents, currency = "EUR") {
	return `${(cents / 100).toFixed(2)} ${currency}`;
}
JS
cat >test/unit/format.test.js <<'JS'
import { test } from "node:test";
import assert from "node:assert/strict";
import { formatCents } from "../../src/lib/format.js";

test("formats cents with two decimals", () => {
	assert.equal(formatCents(1999), "19.99 EUR");
});
JS
npm install --no-audit --no-fund --loglevel=error --no-update-notifier --cache "$1/npm-cache" --save-dev eslint@9 >/dev/null
eval_commit . "chore: set up the shop client"

cat >src/features/orders.js <<'JS'
import { apiClient } from "../lib/api-client.js";

export function listOrders(customerId) {
	return apiClient.get(`/customers/${customerId}/orders`);
}

export async function cancelOrder(orderId) {
	const response = await fetch(`https://api.shop.example/orders/${orderId}/cancel`, { method: "POST" });
	return response.json();
}
JS
eval_commit . "feat: cancel orders"

cat >src/features/orders.js <<'JS'
import { apiClient } from "../lib/api-client.js";

export function listOrders(customerId) {
	return apiClient.get(`/customers/${customerId}/orders`);
}

export function cancelOrder(orderId) {
	return apiClient.post(`/orders/${orderId}/cancel`);
}
JS
git add src/features/orders.js
git commit --quiet -m "fix: cancel orders through apiClient" -m "The direct fetch sent no auth header, so every cancellation failed with 401."

cat >src/features/checkout.js <<'JS'
import { apiClient } from "../lib/api-client.js";

export function checkout(cartId, paymentToken) {
	return apiClient.post("/checkout", { cartId, paymentToken });
}
JS
cat >test/integration/checkout.test.js <<'JS'
import { test } from "node:test";
import assert from "node:assert/strict";
import { checkout } from "../../src/features/checkout.js";

// Runs against the staging backend, which charges the payments sandbox.
test("checks out a cart with the sandbox's test card", async () => {
	const order = await checkout("cart-test-1", "tok_sandbox_visa");
	assert.equal(order.status, "paid");
});
JS
eval_commit . "feat: checkout"

cat >src/features/invoices.js <<'JS'
export async function listInvoices(customerId) {
	const response = await fetch(`https://api.shop.example/customers/${customerId}/invoices`);
	return response.json();
}
JS
eval_commit . "feat: list a customer's invoices"

cat >src/features/invoices.js <<'JS'
import { apiClient } from "../lib/api-client.js";

export function listInvoices(customerId) {
	return apiClient.get(`/customers/${customerId}/invoices`);
}
JS
git add src/features/invoices.js
git commit --quiet -m "fix: list invoices through apiClient" -m "The direct fetch sent no auth header, so every request failed with 401."
git push --quiet origin main
