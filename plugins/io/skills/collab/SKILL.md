---
name: io:collab
description: Check in with the private LLM session register (integratedoperations/sessions) — find or create this session's entry, read and send messages between sessions, record parent/child links between pieces of work. Use when the user types /io:collab, says "check messages" or "register this session", or when a repo's CLAUDE.md asks for a check-in at session start, decision points or gates. Argument `messages` runs the message check only.
argument-hint: "[messages]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(gh auth status:*), Bash(gh repo clone integratedoperations/sessions:*), Bash(git -C ~/Developer/io/sessions:*), Bash(git clone:*), Bash(ln -s ../../scripts/pre-push:*)
---

# /io:collab — check in with the session register

The register is a private GitHub repo, `integratedoperations/sessions`,
cloned to `~/Developer/io/sessions`. Each LLM session working on something
has one entry there; sessions leave each other messages as files. GitHub is
the only access control: whoever can read the repo can read the register.

This skill only reaches the repo. The protocol lives in the repo's
`INSTRUCTIONS.md`, so it has one source; follow that file, and where it and
this skill disagree, the file wins.

## Arguments

| Argument | Runs |
|---|---|
| none | Steps 1–4, then all of `INSTRUCTIONS.md`. |
| `messages` | Steps 1–2, then `INSTRUCTIONS.md` step 1 (find yourself) and step 3 (messages). If you have no entry yet, run the full check-in instead. |

## Step 1: auth

```sh
gh auth status
```

If it reports no logged-in account, stop and ask the user to run
`! gh auth login` and then `! gh auth setup-git`. Never ask for, read, store
or pass a token yourself.

## Step 2: clone or pull

The shell's working directory resets between calls: address the clone with
`git -C ~/Developer/io/sessions …`, or `cd ~/Developer/io/sessions && …`
inside a single call.

- `~/Developer/io/sessions/.git` absent:
  `gh repo clone integratedoperations/sessions ~/Developer/io/sessions`.
  A "not found" error means this GitHub account has no access; stop and
  tell the user to ask an org owner for read/write access.
- Present: check `git -C ~/Developer/io/sessions remote get-url origin`
  names `integratedoperations/sessions`, then
  `git -C ~/Developer/io/sessions pull --rebase --autostash`.

## Step 3: pre-push hook

If `~/Developer/io/sessions/.git/hooks/pre-push` does not exist:

```sh
ln -s ../../scripts/pre-push ~/Developer/io/sessions/.git/hooks/pre-push
```

If a different hook is already there, leave it and tell the user. The hook
validates each pushed commit with `elixir scripts/register.exs validate`; it
needs Elixir on the PATH and, on first run, network access to fetch one hex
package.

## Step 4: follow the protocol

Read `~/Developer/io/sessions/INSTRUCTIONS.md` in full and carry it out. It
covers finding or creating your entry, reading and sending messages, when to
update the entry, how to commit and push, renames, overlap, and what never
to write there.

## Rules

- Commit only your own entry and new message files, by pathspec. Other
  sessions share the clone and may have uncommitted drafts in it.
- Push only the sessions repo. This skill never pushes, commits in, or edits
  any other repo.
- Never write secrets, tokens, passwords or keys into the register.
- Do not copy register content (entries, messages, plans) into public repos,
  including this plugin.

## Report

End with a short summary: your entry id, what you changed in it, messages
read (sender and one line each) and sent, and anything that needs the
user (an open `register validation failing` issue, a reciprocity warning, a
message asking for a decision).
