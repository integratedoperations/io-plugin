---
name: io:new
description: Produce ONE self-contained context file that a fresh session can start from, and print the exact `/phx:work <path>` line to copy. Usually an existing /phx:plan (which points at its scratchpad); otherwise write the missing plan or a handoff file first, from verified repo state. Use when the user types /io:new or asks for a handoff, a context file for a new session, a "what do I paste into the next session", or how to continue this work elsewhere.
argument-hint: "[slug | plan path | topic] [--handoff] [--new] [--repo <path>]"
allowed-tools: Read, Write, Edit, Grep, Glob, AskUserQuestion, Bash(git status:*), Bash(git log:*), Bash(git diff:*), Bash(git branch:*), Bash(git show:*), Bash(git stash list:*), Bash(git worktree list:*), Bash(ls:*), Bash(cat:*), Bash(head:*), Bash(tail:*), Bash(sed:*), Bash(grep:*), Bash(find:*), Bash(date:*)
---

# /io:new — write the file a new session starts from

Output is **one file path**. The user copies it, opens a fresh session, runs
`/phx:work <path>`, and that session has everything it needs. Nothing else
carries over: this conversation's transcript, its assigns, its "we decided" —
all gone. Whatever matters must be **in the file**.

Three cases, one of which applies:

| Situation | Output |
|---|---|
| The work maps onto an existing `/phx:plan` and that plan's state is current | that `plan.md` path — after refreshing its checkboxes and appending a handoff entry to its `scratchpad.md` |
| A plan exists but this session's work sits **outside** it (review fixes, follow-ups, a cross-repo ask, a phase the plan doesn't carry) | a new `handoff-<topic>.md` in the plan directory, task-shaped, cross-linked both ways |
| No plan covers the work | a new `.claude/plans/<slug>/` with `plan.md` + `scratchpad.md` |

## Iron Laws (non-negotiable)

1. **Self-contained.** No "as discussed", no "the change we made", no pronoun
   whose referent is this conversation. The reader has seen nothing.
2. **Verify every state claim in this invocation** — `git status`, `git log`,
   the actual files. Never write state from memory or from what you believe you
   did; other sessions edit these repos concurrently and your snapshot is stale.
3. **`/phx:work` executes checkboxes.** Remaining work is
   `- [ ] [Pn-Tm][agent] …`, landed work is `- [x] …`. A prose-only file is not
   a work input; if the file has no unchecked tasks, it is not finished.
4. **Do not rewrite a plan another session is executing.** Tick boxes for work
   that actually landed and update its status line — nothing more. New
   instructions belong in a handoff file.
5. **Dead ends are the highest-value content.** What was tried and failed, and
   why, is what stops the next session burning a context window repeating it.
6. **Never commit, stage, push, or deploy.** Report what is staged/unstaged/
   committed/undeployed; leave the tree as found.
7. **End with one copyable line** and nothing after it.

## Step 0 — Resolve target and repo

1. `--repo <path>` if given, else the working directory. **interrogator is an
   umbrella** — mix runs from `apps/interrogator/`; **augur is not** — mix runs
   from the repo root. If the work spans both, say so explicitly in the file
   with absolute paths for each.
2. Parse the rest of the argument:
   - empty → infer the subject from this session's work, then confirm in Step 2
   - a slug or a path to `plan.md` → that plan is the target
   - a topic phrase → the subject of a new plan or handoff
   - `--handoff` forces the handoff-file shape; `--new` forces a new plan dir.
3. `ls .claude/plans/` and read the repo's `CLAUDE.md` — the file must carry the
   project's real verification commands, not invented ones.

## Step 1 — Gather verified state

Run, don't recall:

- `git status --porcelain=v1 -b`, `git log --oneline -10`, `git diff --stat` and
  `git diff --cached --stat`, `git worktree list`, `git stash list`.
- For each commit that belongs to this work: `git show --stat <sha>` — record
  sha, subject, and **whether it is pushed and whether it is deployed**. Those
  are three different states and the next session cannot infer them.
- The candidate plan directory: `plan.md` status line, checkbox counts, the tail
  of `scratchpad.md`, anything in `reviews/`, `research/`, `summaries/`.
- Whatever the work actually touched: read the files back rather than trusting
  your account of them.

Then reconcile: a `[x]` whose code is not in the tree, or a `[ ]` whose code is,
is a defect in the plan — fix the checkbox and note it. Do this before writing.

## Step 2 — Choose the shape

Pick from the table above. Use `AskUserQuestion` only when the choice is
genuinely open (e.g. "extend plan `foo` vs. start a plan for this") or when a
task's intent is ambiguous enough that a wrong guess costs the next session real
work. Otherwise choose and say which you chose.

## Step 3 — Write the file

Every section below is required. Omit a section only by writing "none".

- **Title + `Created <YYYY-MM-DD>`.** Absolute dates always — "yesterday" is
  meaningless to a session that opens the file next month.
- **Goal.** One paragraph: what the next session is to accomplish, and what
  "done" looks like.
- **Repos and cwd.** Absolute path per repo, umbrella-vs-root mix rule, branch,
  and the concurrency rule the repo uses (re-check `git status` before staging,
  verify staged content with `git diff --cached <file>`, never amend, follow-up
  commits only).
- **State of the tree.** HEAD sha + subject; commits belonging to this work with
  pushed/deployed status; staged vs unstaged files; anything deliberately left
  dirty and why.
- **Read first.** An ordered list of paths, each with one line on *why* — plan,
  scratchpad, review, the canonical docs named in `CLAUDE.md` that govern this
  area. Order matters: it is the reading sequence.
- **Decisions already taken**, each with its reason. This is what stops the next
  session relitigating a settled call.
- **Dead ends.** What was tried, what happened, why it is not the path.
- **Tasks.** `- [ ] [Pn-Tm][agent] Description` with an acceptance criterion per
  task. `[x]` for what landed, with the inline implementation note kept.
- **Verification.** The exact commands, copied from `CLAUDE.md` — including the
  repo's test-partition rule and any known trap (e.g. a precommit step that
  edits a shared lockfile). The next session must not have to derive these.
- **Open questions for the user.** Anything you could not settle. Say what you
  assumed if the tasks proceed under an assumption.
- **Out of scope.** What is deliberately not in this file, and where it lives.

## Step 4 — Cross-link

- New handoff file → add one line in `plan.md` pointing to it, and one
  `scratchpad.md` entry dated today saying why it exists.
- Existing plan → append a scratchpad entry: what this session landed, what it
  learned, where it stopped.
- New plan dir → `scratchpad.md` gets the inputs, the decisions, and the dead
  ends from this session; `plan.md` stays the task list.

## Step 5 — Read it back cold

Re-read the written file as if you had never seen this conversation. Check:

- Every path resolves; every sha exists; every command is runnable as written.
- No sentence depends on context that is not in the file.
- There is at least one `- [ ]` task.
- Nothing was committed, staged, or pushed by this skill.

Fix what fails, then report in two or three lines what the file covers.

## Step 6 — Print the line

Last output, on its own, nothing after it:

```
/phx:work <path-to-file>
```

Use the path form the next session will be launched with (repo-relative when
that session will start in the repo root; absolute when the work spans repos).
