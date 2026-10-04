# io-plugin

Claude Code skills shared across the io workspace (`augur`, `interrogator`, and
anything else under `~/Developer/io`). One marketplace (`io-local`) holding one
plugin (`io`).

## Skills

| Command | Purpose |
|---|---|
| `/io:new` | Write the one self-contained context file a fresh session starts from, and print the `/phx:work <path>` line to copy. |
| `/io:collab` | Check in with the private session register (`integratedoperations/sessions`): find or create this session's entry, read and send messages between sessions, nest sub-sessions under their parent, track children's status and judge done, and move entries (`/io:collab move <id> under <parent-id>` or `move <id> top`). |
| `/io:fix-tests` | Triage failing ExUnit tests as regression / stale / flaky and drive each to the right resolution. |
| `/io:find-customer` | Find and qualify evidence-backed first customers from public signals. |

Remote: <https://github.com/integratedoperations/io-plugin> (public).

## Install

Install from GitHub; the repo is public:

```
claude plugin marketplace add integratedoperations/io-plugin
claude plugin install io@io-local
```

Or declare it in `~/.claude/settings.json` so a machine picks it up on its own:

```json
"extraKnownMarketplaces": {
  "io-local": {
    "source": { "source": "github", "repo": "integratedoperations/io-plugin" },
    "autoUpdate": true
  }
},
"enabledPlugins": { "io@io-local": true }
```

`plugin.json` carries no `version`, so the installed version is the commit
SHA and every pushed commit is an update. A change reaches a machine only
after it is pushed and pulled: `claude plugin marketplace update io-local`
(or auto-update), then `/reload-plugins` in a running session.

`claude plugin marketplace list` shows where the marketplace points. To try
an unpushed `SKILL.md` edit, point the marketplace at a local clone
(`claude plugin marketplace add "$PWD/io-plugin"`) and switch back after.

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
