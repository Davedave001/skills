---
name: teach-me-why
description: Explain a decision the agent made earlier in this session as one short HTML lesson (the concept behind it, the alternatives, a quick check and links to the docs), saved to a temp folder and opened in the browser. With no argument, it offers the session's latest decisions to pick from.
disable-model-invocation: true
argument-hint: "[the decision to explain]"
---

# Teach me why

The user saw you do something in this session and doesn't know why. Turn that one **decision** into one short **lesson**: an HTML page that explains the reasoning and the concept beneath it, so next time they could make the call themselves.

One decision, one lesson, readable in about five minutes. For a whole topic, or anything this session didn't do, Matt Pocock's [`teach`](https://github.com/mattpocock/skills/tree/main/skills/productivity/teach) skill runs a full course: see [Out of scope](#out-of-scope).

## 1. Pick the decision

A decision is a choice where something else was possible: a library, a pattern, a command or flag, a file layout, a rule followed without comment, something done that the user didn't ask for. Mechanical steps with only one sensible way (reading a file, running the tests) aren't decisions.

- **With an argument**, find what it names in this session. If it matches one decision, take it. If it matches several ("the git thing"), ask which, as below. If the session never did it, see [Out of scope](#out-of-scope).
- **Without an argument**, look back from the latest turn and list the decisions you made since the user's last request. Take one without asking only when it is the only decision there, or the user's message already pointed at it. With two or more, ask, even when one seems the most interesting to you: what puzzled the user is often not what you would guess. Offer at most four: the choices between real alternatives that are most likely to surprise someone reading the work, ahead of housekeeping like deleting caches or how you ran the tests. Write each as a few words plus where it happened ("Used `git worktree` instead of a branch, in the release step"). Say they can name any other decision instead. Use your question tool if you have one, else a numbered list, and stop until the user answers.

Done when you can say the decision in one sentence and the user has confirmed it, or it was the only candidate.

## 2. Work out the why

Reconstruct the reasoning you actually used at the time, from the conversation, the code and the git history: what you were trying to achieve, what you knew, which alternatives existed and why you passed them over. Be honest about it. If the choice was a habit, a default or a guess, the lesson says so; if, looking at it again, another option would have been better, say that in the lesson and in your reply, and offer to change it. A lesson that rationalises a bad call after the fact teaches the wrong thing.

Then name the **concept** beneath the decision: the general idea that makes it right here (idempotency, optimistic locking, a shell's word splitting, semantic versioning...). The lesson teaches that concept through this session's case.

Find one to three sources for it, primary source first: the official docs, the spec, the tool's own manual, or a well-known article by its authors. If you can reach the web, open each link and keep only those that load and say what you cite them for. If you can't, cite only top-level official pages and tell the user the links weren't checked.

Done when you can state, for this concept, when the choice is right and when an alternative would be.

## 3. Write the lesson

Copy [`lesson-template.html`](lesson-template.html) from this skill's folder (`<skill-dir>` is the folder this `SKILL.md` is in) into a new temp folder, named after the decision:

```sh
tmp="${TMPDIR:-/tmp}"
dir="$(mktemp -d "${tmp%/}/teach-me-why.XXXXXX")"
cp "<skill-dir>/lesson-template.html" "$dir/<short-slug>.html"
```

Fill in every `{{...}}` placeholder and delete the template's comments. Write in the language the user writes to you in. The sections, in order:

1. **The short answer**: two or three sentences that answer the question on their own.
2. **What happened here**: the decision in this session, with the real snippet, command or file path.
3. **The idea behind it**: the concept, explained only as far as this decision needs.
4. **The alternatives**: each option you passed over and when it would have been the right one. This is what turns an explanation into judgement.
5. **An example**, only when code says it better than prose: a minimal snippet, outside this project, that shows the concept on its own. Delete the section otherwise.
6. **Quick check**: one or two questions that apply the concept to a new situation, not recall of this session. Give each three options of about the same length, put the right answer in a different position each time, and write feedback for every option that says why it's right or wrong.
7. **Learn more**: the sources from step 2, primary first, each with a line on what the user will find there.

The template already ends with a reminder that the user can ask you follow-up questions in the session.

Done when no `{{` is left in the file and every link in it is one you kept in step 2.

## 4. Open it and hand over

Open the file in the user's browser: `open` on macOS, `xdg-open` on Linux, `wslview` under WSL. If none is available or the command fails, give the path instead.

Then tell the user, briefly:

- the lesson's full path;
- that it lives in a temp folder the system will clear, so if they want to keep it they can copy it themselves or ask you to save it somewhere else;
- your own verdict if step 2 found the decision was a poor one, with the offer to change it;
- that if they want to go deeper into the topic, the `teach` skill can take it from here (see below).

## Out of scope

This skill explains what this session did. Two requests belong to Matt Pocock's `teach` skill instead, which builds a course over several sessions in a workspace folder, with a mission, lessons, reference sheets and a learning record:

- **A topic this session never touched** ("teach me why Rust has lifetimes"). Say the session didn't do it, and don't write a lesson.
- **Going deeper** than one lesson, before or after writing it ("teach me everything about git rebase").

If a `teach` skill is available to you, offer to start it on the topic. Otherwise offer to install it: [its repository's README](https://github.com/mattpocock/skills#installation-30-second-setup) has the command for each agent.
