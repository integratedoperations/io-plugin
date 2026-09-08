# io-plugin

Claude Code skills shared across the io workspace (`augur`, `interrogator`, and
anything else under `~/Developer/io`). One marketplace (`io-local`) holding one
plugin (`io`).

## Skills

| Command | Purpose |
|---|---|
| `/io:new` | Write the one self-contained context file a fresh session starts from, and print the `/phx:work <path>` line to copy. |
| `/io:fix-tests` | Triage failing ExUnit tests as regression / stale / flaky and drive each to the right resolution. |
| `/io:find-customer` | Find and qualify evidence-backed first customers from public signals. |

Remote: `git@github.com:integratedoperations/io-plugin.git` (private).

## Install

Registered as a directory-source marketplace, so a checkout is the install —
clone it, then point Claude Code at the clone:

```
git clone git@github.com:integratedoperations/io-plugin.git
claude plugin marketplace add "$PWD/io-plugin"
claude plugin install io@io-local
```

Keep the source a local path rather than the GitHub repo: edits to a `SKILL.md`
are then live in the next session with no `claude plugin update` step.

`claude plugin marketplace list` shows where the marketplace currently points.
Editing a `SKILL.md` here takes effect in the **next** session — skills are read
at session start, and `claude --continue` re-reads them without losing history.

## Layout

```
.claude-plugin/marketplace.json    marketplace manifest (name: io-local)
plugins/io/.claude-plugin/plugin.json
plugins/io/skills/<name>/SKILL.md  one directory per skill
                        references/  loaded on demand by the skill
                        scripts/     executables the skill runs
                        outputs/     run artifacts — gitignored
```

Validate a change before relying on it: `claude plugin validate .`
