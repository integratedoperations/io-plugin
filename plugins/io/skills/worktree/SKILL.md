---
name: io:worktree
description: Create or destroy an isolated Augur dev worktree — its own git worktree, branch, Phoenix port block, and dev/test databases. Use when the user says "/io:worktree", "new worktree", "spin up a worktree for X", "tear down / merge back the worktree". Modes — create <name>: provision everything and print session-restart instructions; destroy <name>: merge the branch back to main (port/DB overrides are gitignored so they never merge), drop the DBs, remove the worktree.
argument-hint: "create <name> | destroy <name>"
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion, Bash(git worktree:*), Bash(git branch:*), Bash(git merge:*), Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(mix:*), Bash(cp:*), Bash(mkdir:*), Bash(cat:*), Bash(ls:*), Bash(find:*), Bash(grep:*), Bash(lsof:*), Bash(dropdb:*)
---

# Augur Worktree Lifecycle

Provision or tear down a fully isolated parallel dev environment. Isolation works
because `config/*.local.exs` is **gitignored** and imported *after* `dev.exs` /
`test.exs` (see `config/config.exs` bottom), so per-worktree port + database
overrides live there and can never leak into a merge.

Arguments: `$ARGUMENTS` = `create <name>` or `destroy <name>`.
Derive: `SLUG` = name kebab-cased; `DBSLUG` = SLUG with `-` → `_`;
worktree path `../augur-<SLUG>`; branch `<SLUG>`.

## Mode: create

### 1. Pick a free port block

Main checkout uses HTTP 4010, HTTPS 4011. Each worktree gets a block
`BASE = 4110, 4210, 4310, ...` (HTTP=BASE, HTTPS=BASE+1).
Find the first free block:

```bash
used=$(find .. -maxdepth 3 -path '*/config/dev.local.exs' -exec grep -h "port:" {} + 2>/dev/null)
for base in 4110 4210 4310 4410; do
  if ! echo "$used" | grep -q "port: ${base}" && ! lsof -i ":${base}" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "BASE=${base}"; break
  fi
done
```

(Uses `find`, not a `../augur-*/` glob — zsh aborts on unmatched globs when no
sibling worktree has a `dev.local.exs` yet.)

### 2. Create the worktree + branch

```bash
git worktree add ../augur-<SLUG> -b <SLUG>
```

(Branch creation here is authorized — it is the point of this skill.)

### 3. Seed local config (gitignored — carries secrets AND the overrides)

`config/dev.local.exs` is gitignored, so the new worktree won't have it. Copy
the main checkout's copy (it holds required R2/API secrets), then append the
worktree overrides:

```bash
cp config/dev.local.exs ../augur-<SLUG>/config/dev.local.exs
cat >> ../augur-<SLUG>/config/dev.local.exs <<EOF

# --- worktree '<SLUG>' overrides (gitignored; never merged back) ---
config :augur, AugurWeb.Endpoint, http: [port: BASE], https: [port: BASE+1]
config :augur, :event_api_url, "http://localhost:BASE/api/events"
config :augur, Augur.Repo, database: "augur_dev_<DBSLUG>"
config :augur, :cert_auth_port, CERTPORT
config :augur, :cot_listener_port, COTPORT
EOF
```

Every listener the app binds must shift, or boot fails with `:eaddrinuse`
against the main dev server. Shift by the same block offset N (BASE = 4010 +
100·N): `CERTPORT` = 4444 + 100·N (dev mTLS/CAC listener), `COTPORT` = 22605 +
100·N (CoT TLS listener — enabled by the copied `dev.local.exs`).

(Substitute literal numbers for BASE/BASE+1. Keyword configs deep-merge, so
`http: [port: ...]` keeps the `ip:` from dev.exs.)

Do NOT add a `config :crawly, port: ...` override. Crawly was removed as a
dependency, so configuring it makes every `mix` run in the worktree print
"Please ensure :crawly exists or remove the configuration".

Copy the other gitignored-but-required runtime assets — the dev HTTPS listener
needs `priv/cert/*` (seeds fail at app start without it) and the CoT listener
enabled in `dev.local.exs` needs `priv/cot/*`:

```bash
mkdir -p ../augur-<SLUG>/priv/cert ../augur-<SLUG>/priv/cot
cp priv/cert/* ../augur-<SLUG>/priv/cert/
cp priv/cot/*  ../augur-<SLUG>/priv/cot/ 2>/dev/null || true
```

(Copy file contents into the existing dirs — `cp -R priv/cert ...` nests a
`cert/cert/` subdir because the tracked dir already exists in the worktree.)

Give tests their own DB too (avoids shared-`augur_test` sandbox collisions):

```bash
cat > ../augur-<SLUG>/config/test.local.exs <<EOF
import Config
config :augur, Augur.Repo, database: "augur_test_<DBSLUG>"
EOF
```

### 4. Build and create the databases

Run inside the worktree:

```bash
cd ../augur-<SLUG>
mix setup                      # deps, ecto.create+migrate+seeds, assets
MIX_ENV=test mix ecto.create   # test DB (name comes from test.local.exs)
MIX_ENV=test mix ecto.migrate
```

Known flake: on a fresh dep build, Elixir 1.19.5 can fail with
`:elixir_quote.validate_quote` stale-beam errors — just retry the command once;
do NOT `deps.compile --force` or `mix clean`.

### 5. Print handoff instructions (final output to user)

```
Worktree ready: ../augur-<SLUG>  (branch <SLUG>)
  HTTP  : http://localhost:BASE      (HTTPS BASE+1)
  Dev DB: augur_dev_<DBSLUG>   Test DB: augur_test_<DBSLUG>

Claude Code sessions are bound to their start folder, so:
  1. Quit this session (Ctrl+C twice or /exit)
  2. cd ../augur-<SLUG>
  3. claude
  4. mix phx.server  → http://localhost:BASE

When done: from a session in the MAIN checkout, run /io:worktree destroy <SLUG>
```

## Mode: destroy

Must run from the **main checkout** (`augur/`), never from inside the worktree
being destroyed. If the current directory is the target worktree, stop and tell
the user to quit and restart in the main checkout first.

### 1. Safety checks — stop and ask the user if any fail

```bash
git -C ../augur-<SLUG> status --porcelain        # must be empty (uncommitted work)
git diff main...<SLUG> --name-only | grep 'config/.*\.local\.exs'  # must be empty
```

If the second check hits, a secrets/port file was committed on the branch —
surface it and resolve with the user before merging.

Generated build artifacts (e.g. `docs/generated_images/*.svg`) can leave the
tree dirty without being real work. Check what the diff actually is before
discarding it, and say what you discarded.

### 2. Drop the databases (while config still exists)

```bash
(cd ../augur-<SLUG> && mix ecto.drop && MIX_ENV=test mix ecto.drop)
```

Faster, and avoids a cold compile in a worktree you are about to delete:

```bash
PGPASSWORD=postgres dropdb -h localhost -U postgres --if-exists augur_dev_<DBSLUG>
PGPASSWORD=postgres dropdb -h localhost -U postgres --if-exists augur_test_<DBSLUG>
```

(`dropdb` lives at `/Applications/Postgres.app/Contents/Versions/17/bin/dropdb`
when it is not on `PATH`.)

**Expect a permission prompt.** Dropping databases and removing a worktree can
be auto-denied as "Irreversible Local Destruction". If that happens, do NOT
try to route around it — finish whatever else the user asked for, then tell
them the teardown is still pending and let them approve it or run it
themselves. Nothing else depends on the teardown.

### 3. Merge back to main

```bash
git merge <SLUG>
```

The port/DB changes live only in gitignored `*.local.exs` files, so they are
excluded automatically — nothing to revert. Do NOT push or deploy; Augur ships
via `mix deploy --do` only when the user asks.

If the branch was already merged (e.g. it shipped as a PR), this is a no-op —
confirm with `git branch --merged main` first so you do not report a merge that
did not happen.

### 4. Remove worktree and branch

```bash
git worktree remove ../augur-<SLUG>   # refuses if dirty — do not --force without asking
git branch -d <SLUG>
```

Confirm to the user: merged, DBs dropped, worktree and branch removed.
