#!/usr/bin/env bash
set -euo pipefail

# A Node project that renders report exports through a small job queue. On
# main, the queue never frees a worker slot when a job rejects, so after two
# failed renders it stalls and every later export times out. The
# fix/export-timeout branch hides that symptom in another module: exportReport
# waits 60 seconds instead of 5, and the leak in src/queue.js is left in
# place. Everything is committed and pushed.

# shellcheck source=scripts/evals/fixture-lib.sh
. "$EVAL_LIB"

eval_repo "$1"
cd "$1/repo"

cat >package.json <<'JSON'
{
	"name": "reports",
	"version": "1.0.0",
	"type": "module",
	"scripts": {
		"test": "node --test"
	}
}
JSON
mkdir -p src test
cat >src/queue.js <<'JS'
// Runs jobs with at most `concurrency` of them in flight; the rest wait in
// order.
export function createQueue({ concurrency = 2 } = {}) {
	const waiting = [];
	let active = 0;

	function runNext() {
		if (active >= concurrency || waiting.length === 0) {
			return;
		}
		const { job, resolve, reject } = waiting.shift();
		active++;
		job().then(
			(result) => {
				active--;
				resolve(result);
				runNext();
			},
			(error) => {
				reject(error);
			},
		);
	}

	return {
		push(job) {
			return new Promise((resolve, reject) => {
				waiting.push({ job, resolve, reject });
				runNext();
			});
		},
		get pending() {
			return waiting.length;
		},
	};
}
JS
cat >src/render.js <<'JS'
import { writeFile } from "node:fs/promises";
import { join } from "node:path";

const REPORTS = {
	sales: [
		["region", "total"],
		["north", "1200"],
		["south", "950"],
	],
	stock: [
		["sku", "quantity"],
		["A1", "40"],
	],
};

// Writes the report as CSV under dir and resolves with the file's path.
export async function renderReport(dir, name) {
	const rows = REPORTS[name];
	if (!rows) {
		throw new Error(`unknown report: ${name}`);
	}
	const path = join(dir, `${name}.csv`);
	await writeFile(path, rows.map((row) => row.join(",")).join("\n") + "\n");
	return path;
}
JS
cat >src/export.js <<'JS'
import { renderReport } from "./render.js";

const EXPORT_TIMEOUT_MS = 5_000;

function withTimeout(promise, ms) {
	let timer;
	const timeout = new Promise((_, reject) => {
		timer = setTimeout(() => reject(new Error("export timed out")), ms);
	});
	return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

export function exportReport(queue, dir, name) {
	return withTimeout(
		queue.push(() => renderReport(dir, name)),
		EXPORT_TIMEOUT_MS,
	);
}
JS
cat >test/export.test.js <<'JS'
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createQueue } from "../src/queue.js";
import { exportReport } from "../src/export.js";

async function newDir() {
	return mkdtemp(join(tmpdir(), "reports-"));
}

test("exports a report as CSV", async () => {
	const dir = await newDir();
	const path = await exportReport(createQueue(), dir, "sales");
	assert.match(await readFile(path, "utf8"), /^region,total\n/);
});

test("rejects with the render error for an unknown report", async () => {
	const dir = await newDir();
	await assert.rejects(exportReport(createQueue(), dir, "nope"), /unknown report/);
});
JS
eval_commit . "feat: export reports through a job queue"
git push --quiet -u origin main

git switch --quiet -c fix/export-timeout
cat >src/export.js <<'JS'
import { renderReport } from "./render.js";

// Large reports can take a while to render under load.
const EXPORT_TIMEOUT_MS = 60_000;

function withTimeout(promise, ms) {
	let timer;
	const timeout = new Promise((_, reject) => {
		timer = setTimeout(() => reject(new Error("export timed out")), ms);
	});
	return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

export function exportReport(queue, dir, name) {
	return withTimeout(
		queue.push(() => renderReport(dir, name)),
		EXPORT_TIMEOUT_MS,
	);
}
JS
eval_commit . "fix: give report exports more time before timing out"
git push --quiet -u origin fix/export-timeout
