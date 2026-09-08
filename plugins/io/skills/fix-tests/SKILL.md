---
name: io:fix-tests
description: Find failing Elixir/ExUnit tests and resolve each by classifying it as a regression (collaborate with the user on the fix), a stale test (code changed intentionally — update the test to the new contract), or flaky (make it deterministic; else tag :flaky; else :skip the individual test when :flaky is overridden). Use when the user types /io:fix-tests or asks to triage/fix failing tests, a red suite, or flaky tests.
argument-hint: "[--repo <path>] [test_path[:line] | --failed | (empty = full suite)]"
allowed-tools: Read, Edit, Write, Grep, Glob, AskUserQuestion, TaskCreate, TaskUpdate, Bash(mix test:*), Bash(mix compile:*), Bash(mix format:*), Bash(git status:*), Bash(git log:*), Bash(git diff:*), Bash(git blame:*), Bash(git show:*)
---

# /io:fix-tests — triage and resolve failing Elixir tests

Find failing ExUnit tests and drive each to a **correct** resolution. Every
failure is exactly one of three kinds; the whole skill is a classifier plus the
right action per kind:

| Kind | Meaning | Action |
|------|---------|--------|
| **Regression** | Code behavior changed/broke; the test's expectation is still correct | **Collaborate with the user** on fixing the CODE — never silently touch the test |
| **Stale** | Code was changed **on purpose**; the test still asserts the old contract | Update the TEST to the new intended behavior |
| **Flaky** | Non-deterministic; not a real product failure | Make deterministic → else `@tag :flaky` → else `@tag :skip` |

## Iron Laws (non-negotiable)

1. **Never make a red test green by weakening its assertion unless you have
   confirmed the new behavior is intended.** That masks regressions and is the
   single worst thing this skill can do. When intent is unclear → **ASK**.
2. **Regressions are the user's call.** Present evidence and options; do not
   pick the fix unilaterally.
3. **Prefer determinism over suppression.** `@tag :flaky`/`:skip` are last
   resorts, only after a real attempt to remove the non-determinism.
4. **Every suppression leaves a trail** — a `# why:` comment on the tag and a
   note to the user (and a `.claude/solutions/` doc if the repo uses them).
5. **Verify before claiming done** — re-run the affected tests (and, for a
   suppressed flaky, run it in isolation a few times to confirm the diagnosis).

## Step 0 — Resolve target and scope

1. Extract an optional `--repo <path>` (default: current working directory).
   Both io repos are Elixir; **interrogator is an umbrella** (run mix from
   `apps/interrogator/`), **augur is not** (run from repo root).
2. Parse the remaining argument:
   - empty → run the **full suite** to discover failures
   - `--failed` → `mix test --failed` (uses ExUnit's stored failures manifest)
   - `path` or `path:line` → scope to that file/line
3. Before triaging, load context that prevents wrong calls:
   - `Grep .claude/solutions/` for prior write-ups on the failing area (the repo
     accrues these; a known flaky/pattern may already be documented).
   - Skim recent history (`git log --oneline -15`) so "was this an intentional
     change?" has evidence behind it in Step 2.

## Step 1 — Collect the failing set

Run the scoped tests and capture the failure list (file:line + the
expected/actual for each). Use `TaskCreate` to make one task per failing test
so progress is visible; mark `in_progress`/`completed` as you work each.

If the suite won't **compile**, that's not a test failure — fix the compile
error first (or report it) before classifying anything.

## Step 2 — Classify each failure

Work one failure at a time. The decision tree:

### 2a. Reproduce in isolation

Run just that test a few times: `mix test <file>:<line>` (×3–5).

- **Fails every isolated run, same way** → deterministic → go to **2b**.
- **Passes alone but fails in the full suite**, or **passes on some isolated
  re-runs** → non-deterministic → go to **2c**.

### 2b. Deterministic failure → Regression vs Stale

Read expected-vs-actual, then look at what changed in the **code under test**
(not the test file): `git log -p`, `git blame`, `git diff` on the source module.
Ask the one question that separates the two kinds:

> **Is the current code's behavior the intended behavior?**

- **Intended** (a recent feature/refactor deliberately changed it, matches a
  plan/commit message/your session context) and the test still checks the old
  contract → **STALE** → Step 3B.
- **Not intended** (the code is wrong, or nothing explains the behavior change,
  or it violates a documented contract) → **REGRESSION** → Step 3A.
- **Unclear** → do **not** guess. Present both readings to the user with
  evidence via `AskUserQuestion` and let them classify. Guessing here either
  hides a bug (if you call a regression "stale" and edit the test) or reverts a
  feature (if you call a stale test a "regression" and change the code).

Watch for the trap: a test that fails only in the suite but passes alone is
usually **test pollution / ordering**, not flaky randomness — another test
leaks global state (ETS, a named process, DB sandbox misuse, `Application.put_env`).
Treat that as a **regression in test isolation** (fix setup/teardown or ownership),
not something to tag away.

### 2c. Non-deterministic failure → Flaky

Identify the source of non-determinism (this drives the fix in Step 3C):

- `Process.sleep` + count/poll inside a fixed wall-clock window
- wall-clock / `DateTime.utc_now` / unseeded randomness / ordering assumptions
- async race between the test and the process under test
- reliance on message/scheduler timing, external I/O, or port/UDP timing
- shared-state ordering dependence (see the pollution note above)

## Step 3 — Act per classification

### 3A. Regression → collaborate

STOP and bring the user in. Present, for each regression:
- the failing test and its expected-vs-actual,
- the code change that most likely caused it (file:line, commit),
- 2–3 concrete fix options for the **code** (not the test), with trade-offs.

Use `AskUserQuestion` to let them choose the direction, then implement the
chosen fix, and re-run to green. Do not edit the test's assertions to pass
unless the user explicitly redefines the expected behavior (which reclassifies
it as Stale).

### 3B. Stale → update the test to the new contract

Only once intent is confirmed (Step 2b or the user). Rewrite the assertions to
the **new intended** behavior — not to whatever the code currently emits. If the
code's current output looks partly wrong even though the change was intended,
surface that; a stale-test update should not rubber-stamp an incidental bug.
Keep the test meaningful (still asserts the contract, just the new one). Re-run.

### 3C. Flaky → deterministic first, then quarantine

In priority order:

1. **Make it deterministic (preferred).** Replace the non-determinism:
   - `Process.sleep` + poll → have the process emit a message/`:telemetry` event
     and `assert_receive` it; or `assert_eventually`-style poll on a condition
     with a generous timeout instead of a fixed window.
   - unseeded randomness → seed it; ordering deps → isolate shared state
     (`start_supervised!`, unique names/ids, proper sandbox ownership).
   - Prove the fix: run the test in isolation several times.

2. **Tag `@tag :flaky` (if determinism is genuinely impractical now).** ONLY
   valid if the repo excludes it by default — **verify** `test/test_helper.exs`
   (umbrella: the relevant app's) calls
   `ExUnit.start(exclude: [:flaky, ...])`. Add the tag with a `# why:` comment
   naming the timing assumption. CI here runs plain `mix test`, so the exclude
   applies automatically — do **not** edit CI to achieve this.

3. **`@tag :skip` the individual test (when `:flaky` won't quarantine it).**
   If the `:flaky` exclude is **overridden** for this test — e.g. it lives in a
   module run with `--include flaky`, or a `@moduletag`/synchronous-run config
   force-includes it, or the run otherwise honors flaky tags — then tagging
   `:flaky` does nothing. Use `@tag :skip` (optionally `@tag skip: "why + tracking ref"`),
   which ExUnit honors **unconditionally** regardless of include/exclude
   filters. This is the narrowest hammer: it removes exactly the one test,
   leaving the rest of its (synchronous) module running. Always pair with a
   note/issue so it isn't lost.

   Decision within 3C, restated:
   > deterministic fix possible? → do it.
   > else exclude-honored? → `@tag :flaky`.
   > else → `@tag :skip` the single test.

## Step 4 — Verify and report

- Re-run the affected tests (and the full suite if failures were suite-only).
- Report per test: **kind** (regression/stale/flaky), **what you did**, and for
  any suppression, **why determinism was deferred** + the tracking note.
- Offer follow-ups: a `.claude/solutions/` write-up for a non-obvious root cause
  (`/phx:compound` if that plugin is present), or filing the deferred
  determinism work.

Never leave a suppressed test undocumented, and never report "fixed" for a test
whose assertion you changed without confirming the new behavior was intended.
