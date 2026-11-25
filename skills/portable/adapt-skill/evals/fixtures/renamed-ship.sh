#!/usr/bin/env bash
set -euo pipefail

# A small Node project that installed the deliver template back when it was
# called ship: .claude/skills/ship/ holds an adapted copy at revision 6, with
# a branch rule of its own (feat/<slug>), and CLAUDE.md points to /ship. The
# README says "ship" in its everyday sense, which a rename must leave alone.
# Everything is committed and pushed.

# shellcheck source=scripts/evals/fixture-lib.sh
. "$EVAL_LIB"

eval_repo "$1"
cd "$1/repo"

cat >package.json <<'EOF'
{
	"name": "billing",
	"version": "1.0.0",
	"type": "module",
	"scripts": {
		"test": "node --test"
	}
}
EOF
cat >README.md <<'EOF'
# billing

Invoices for the shop. We ship a release every Friday.
EOF
cat >CLAUDE.md <<'EOF'
# billing

- Run the tests with `npm test`.
- When a change is finished, run `/ship`: it commits, pushes and opens the pull request.
EOF
mkdir -p src .claude/skills/ship
cat >src/invoice.js <<'EOF'
export function total(lines) {
	return lines.reduce((sum, line) => sum + line.price * line.quantity, 0);
}
EOF
cat >.claude/skills/ship/SKILL.md <<'EOF'
---
name: ship
description: >-
  Take finished work from the working tree to shipped in one move: commit it, bring the branch up to date, push, and
  open the PR. Use whenever the user wants to "ship", "ship it", "open a PR", or invokes `/ship`.
metadata:
  template-revision: "6"
---

# Ship

This project ships **through pull requests** against `main`. `ship` accepts `--base <branch>` to target another base.

## Step 1: Read the current state

Run `git status --short --branch` and `git log --oneline -5`.

## Step 2: Branch

Never commit onto `main`. Name the branch `feat/<slug>`, with a short kebab-case slug of the change.

## Step 3: Commit

Commit with Conventional Commits.

## Step 4: Check

Run `npm test` before pushing.

## Step 5: Push and open the PR

Push the branch and open a pull request with `gh pr create`.
EOF
eval_commit . "chore: add the ship skill"

git push --quiet -u origin main
