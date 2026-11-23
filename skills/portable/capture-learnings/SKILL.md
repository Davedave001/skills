---
name: capture-learnings
description: Review the current conversation for reusable learnings (corrections, gotchas, patterns, missed skills, procedures worth turning into a skill), check them against the project's existing docs, and, once the user approves, write them into the project where the next agent will find them, or into a lint rule, test or hook when a machine can catch the mistake. Use whenever the user asks to capture learnings, review what was learned, document gotchas or corrections, extract reusable patterns, write down mistakes so they don't repeat, check whether anything belongs in AGENTS.md or a skill, or do a post-task review. Trigger phrases include "capture learnings", "what did we learn", "document the gotchas", "write those down", "pull out anything for future reference", "extract patterns", "/capture-learnings". Also offer it at the end of a non-trivial task, even if not asked.
---

# Capture learnings

Review the current conversation for reusable corrections, gotchas and patterns, and put them in the project, where every agent and teammate working on it will find them. Never in an agent's personal memory.

A learning goes into a **guide**, a **sensor**, or both. A guide steers the next agent before it acts: the instruction file, a skill, a doc. A sensor checks the work afterwards and fails when the mistake comes back: a linter rule, a structural test, a type, a test, an agent hook. A guide can be missed; a sensor runs every time. So when a machine can catch a learning, propose a sensor first, with a short guide line that explains it.

## 0. Map the project's docs and checks

Before extracting anything, find where this project keeps what agents should know, and what it runs to check their work. Read, don't assume:

- **The instruction file:** `AGENTS.md` or `CLAUDE.md` at the root (if one only imports the other, the imported one is the real target), plus any nested ones in subfolders. Note its sections: rules, conventions, a list of skills, references, checks to run.
- **Project skills:** `.claude/skills/`, `.agents/skills/`, or wherever the instruction file says skills live, with their reference files. A skill installed from a template (its frontmatter has `metadata.template-revision`) belongs to the project and can be edited; a refresh with `adapt-skill` keeps those edits.
- **Review docs**, if the project has them, under any name: a known non-issues list (`KNOWN_NON_ISSUES.md`), a pre-PR review checklist (`PRE_PR_REVIEW.md`), a pitfalls doc (`FOOTGUNS.md`).
- **Sensors:** the linter and its rules, built-in and custom (`eslint.config.js`, `biome.json`, Ruff in `pyproject.toml`, `.golangci.yml`...), structural tests (dependency-cruiser, ArchUnit, eslint-plugin-boundaries...), how strict the type checking is, the test suites, git hooks, and agent hooks (Claude Code's are in `.claude/settings.json`). Note the command that runs each, from the instruction file, the package manifest or CI. A check counts only if something runs it: a rule in a config nobody runs catches nothing.
- **Available skills:** the skills you can invoke in this session, including those from plugins.

## 1. Extract candidates

Scan the conversation for:

- **Corrections:** moments the user said "no", "not like that", "instead do...", or you had to redo something.
- **Gotchas:** unexpected behaviour, subtle bugs, or non-obvious constraints found during the work.
- **Patterns:** approaches that worked well and aren't documented yet.
- **Missed skills:** skills that were available and should have been used but weren't.
- **Docs proved wrong:** a doc the work read or relied on that the conversation showed is now wrong: a command that no longer works, a rule the code no longer follows, a claim the user corrected.
- **New skill candidates:** multi-step procedures you carried out that would make a good skill. A candidate qualifies only if **all** apply:
  - It took three or more distinct steps (not a single command or one-off edit).
  - It has clear inputs the user would pass next time (an issue ID, a file path, a URL).
  - It has a clear output or end state (a file written, a PR opened, a report produced).
  - The same procedure would run the same way on different inputs.
  - No existing skill covers it.

  A single-rule correction ("use X instead of Y") is not a skill candidate: it belongs in the instruction file or a reference, or in a sensor. How often a procedure recurs across sessions can't be seen from one conversation, so judge candidates by their shape and let the user decide.

For each candidate, write:

- **What:** a one-line summary.
- **Why it matters:** what went wrong, or what it prevents.
- **Where it belongs:** the sensor that would catch it next time, if one fits (see Sensors below), and the file to update (see the placement rules below).

## 2. Verify against the existing docs and checks

This step prevents duplicates and puts each learning where it will be found. For each candidate:

1. **Read the target file.** Don't go from memory.
2. **Search for existing coverage** in the target file and the instruction file, by keywords related to the learning, and in the sensors' config for a check that already covers it.
3. **For a pattern or convention, check the code too.** Search the module, or the related ones, for how consistently it's already followed. If it shows up only in this conversation's change, it isn't a convention yet: ask the user whether it's a deliberate new one or a one-off before proposing it. A one-off written down as a convention misleads every later decision.
4. **Classify it:**
   - **skip:** the rule or pattern is already documented. Quote the existing text. But if it exists and was still broken in this conversation, ask why: it may be buried, worded so it isn't found, or missing from where the work happened. If the docs failed to prevent the mistake, mark it **discoverability** instead and propose one of:
     - a sensor, when one fits: a written rule that was broken anyway is the clearest case for a check;
     - stronger trigger words or a more prominent place in the instruction file, so the rule is found earlier;
     - a cross-reference from where you were working to where the rule lives;
     - a better `description` for the skill that should have been used, with the skill-creator skill if it's available.

     If a check already covers it and still didn't catch it, find out why (it doesn't run where the work happened, or the rule is too narrow) and propose that fix.
   - **amend:** the idea is documented but misses the nuance you found. Name the gap.
   - **add:** genuinely new.
   - **correct:** a doc says something this conversation showed is wrong. Quote it and propose the replacement. This covers any doc you read along the way, not only the targets of the other candidates. Only what is wrong: not the style or wording of entries that are still right.

## 3. Propose

Present every candidate in a table, with its status, so the user can see your work:

```
| # | What | Where | Status |
|---|------|-------|--------|
| 1 | Missing edge case in a shared hook | AGENTS.md → Conventions | add: not documented |
| 2 | Use skill X before Y work | skill X description | skip: already in AGENTS.md |
| 3 | Check reference X before doing Y | AGENTS.md → Checks | discoverability: rule exists, but its wording misses common task terms |
| 4 | Bundle a multi-step procedure | new skill | new-skill: 4 steps, input an issue ID, output a resolved issue |
| 5 | Tests run with `make check` now | AGENTS.md → Checks | correct: it still says `make test` |
| 6 | Feature code calls `fetch` directly, skipping the API client's auth header | `eslint.config.js`: `no-restricted-globals`, plus a line in AGENTS.md → Conventions | discoverability: AGENTS.md says to use the client, and it was broken anyway |
```

For **add**, **amend** and **correct**, show the exact text you'll insert and where (the section, and after which line or paragraph), so the user approves precise edits, not intentions. A sensor changes code or config, so show it the same way: the rule or test with its failure message, the file it goes in, any exemption (such as the one module that has to do what the rule forbids), and the guide line that goes with it.

For **new-skill**, show the proposed name, a one-line description of what it does and when it triggers, the steps it would automate, and its inputs and outputs. Don't create the skill yourself: the user decides, then uses the skill-creator skill (or asks you to).

**Wait for the user's confirmation.** They may remove, edit or redirect entries before anything is written.

## 4. Document

Apply the confirmed learnings:

- Keep additions minimal and in the style of each file.
- Add a sensor where the project keeps its kind: a lint rule next to the linter's other rules, a test next to the tests of the code it covers.
- In the instruction file, add to the most relevant existing section; create a new one only if nothing fits.
- In a skill's references, add next to the related topic, not in a separate "learnings" section.
- In a skill's `SKILL.md`, broaden the `description` if its trigger wording was the problem.

## 5. Verify

When code or config changed, which every sensor does, run the project's checks: those its instruction file lists, or the ones its CI runs. A new sensor is done when you've seen both:

- **It passes on the current code.** If it flags existing code, show the user what it found and let them choose: fix that code, exempt it, or narrow the rule.
- **It fails on the mistake, with its message.** Run it on a snippet that repeats the mistake: the linter's stdin, or a throwaway file you delete afterwards.

For docs-only changes, re-read the edited sections to confirm they say what was approved.

Don't commit; tell the user what changed so they can.

## Sensors

A sensor fits when the mistake leaves a mark a machine can see: an import, a call or a pattern in the code; one module reaching into another; a value the types allow but never should; behaviour a test can pin down; an agent action, such as a command or a path it touches. Judgement, intent, process and facts about the world outside the code (a service's quirks, who to ask, when a sandbox is down) leave no such mark, so they stay in a guide. A sensor catches the mistake itself, in what the agent wrote or did, not the situation that led to it. When nothing the agent wrote or did would trip a check, propose the guide alone and say in one line why no sensor fits.

Build it from what the project already runs: a built-in rule of its linter first (many take a message, like ESLint's `no-restricted-imports` or Ruff's `banned-api`), a custom rule where the project already writes them, a test in an existing suite. A new tool or dependency is the user's call: propose the guide line, and name the tool as an option.

Its failure message says what to do instead, not only what's wrong, because the agent that trips it reads the message as its next instruction. Compare the git-guardrails hook's "Don't force-push with --force, -f or a +refspec: use --force-with-lease, so commits you haven't seen are not overwritten" with a bare "force-push not allowed".

Pair it with one line in a guide, where the placement rules put the learning: the rule, why it exists, and the check that enforces it. The next agent learns the rule before the check fires, and nobody deletes the check as noise. The check holds the detail, so one line is enough.

## Placement rules

Put each learning where the next agent will find it, using the structure you mapped in step 0. When one of the sensor rows fits, it comes first, and the learning also gets its one-line guide entry from the rows below them.

| Learning | Target |
|----------|--------|
| A forbidden import, call or code pattern | A rule in the project's linter, built-in or custom |
| A module or layer reaching into one it shouldn't | The project's structural tests (dependency-cruiser, ArchUnit, eslint-plugin-boundaries...), or a linter rule if it has none |
| A value or state the code should make impossible | A stricter type |
| Behaviour that broke and can be pinned down | A test, next to the code's existing tests |
| An agent action the project forbids: a command, a path to leave alone | An agent hook that blocks it, if the project configures hooks |
| A rule that must always or never be followed | The instruction file's rules section |
| A project convention or architecture fact | The instruction file's most relevant section |
| A gotcha specific to one skill's area | That skill's reference files, next to the related topic |
| A skill that exists but wasn't used | That skill's `description` (a project skill), or the instruction file's list of skills |
| A runtime pitfall that passes review and type checks | `FOOTGUNS.md`, if the project has one |
| A review finding that is a settled convention, not a defect | `KNOWN_NON_ISSUES.md`, if the project has one |
| A defect class that review keeps catching | `PRE_PR_REVIEW.md`, if the project has one |
| A reference worth linking | The instruction file's references section |
| A multi-step procedure no skill covers | A new skill proposal (never created automatically) |

A skill that comes from a plugin isn't the project's to edit: don't touch the plugin's installed files. Propose the change to the user so they can make it where the plugin is maintained, and put any project-specific workaround in the instruction file.

## Rules

- **Never** write learnings to an agent's personal memory. They go into the project, so they reach everyone working on it.
- Prefer existing files, sections and checks. If a learning fits nowhere, suggest a new document or skill and let the user decide.
- **Never** document what can be read from the code. Only document what an agent would get wrong without the learning.
