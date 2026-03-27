# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture

### Two Clients

The gem wraps two separate NJ Transit API hosts with a single `Client` class:

- **`NJTransit.client`** → `pcsdata.njtransit.com` — Bus, light rail, bus GTFS-RT
- **`NJTransit.rail_client`** → `raildata.njtransit.com` — Rail/train, rail GTFS-RT

Both use the same `Client` class with different `base_url` and `auth_path`. Authentication is token-based and handled automatically (with transparent re-auth on token expiry).

### Resource Classes (`lib/njtransit/resources/`)

- `Bus` — real-time bus/light rail API (departures, routes, stops, vehicles)
- `Rail` — real-time rail API (schedules, station messages, vehicle tracking)
- `BusGTFS` — bus GTFS-RT feeds (protobuf). Also used for G2 feeds via `api_prefix` param
- `RailGTFS` — rail GTFS-RT feeds (protobuf)

### GTFS Static Layer (`lib/njtransit/gtfs/`)

SQLite-backed offline schedule data. Import from GTFS zip, then query via `NJTransit::GTFS.new`:
- `Database` — Sequel SQLite connection and schema
- `Importer` — parses GTFS txt files into SQLite
- `Models` — `Stop`, `Route`
- `Queries` — `RoutesBetween`, `Schedule`

### Key Patterns

- **`enrich` flag**: Bus API methods default to `enrich: true`, which joins GTFS static data (lat/lon, route names). Use `enrich: false` if GTFS isn't imported or you don't need it.
- **`mode` parameter**: Bus methods default to `mode: "BUS"`. Pass `"HBLR"`, `"NLR"`, `"RL"`, or `"ALL"` for light rail.
- **`stops_nearby` radius**: The radius parameter is in **feet**, not miles.
- **Raw responses**: GTFS-RT methods (`bus_gtfs`, `rail_gtfs`) return binary protobuf data via `post_form_raw`.

## Testing

```bash
bundle exec rspec              # Run all 153 specs
bundle exec rspec spec/file.rb # Run a specific spec file
```

All API calls are stubbed — no credentials needed for tests.

## Git Workflow

Every change follows this process: Issue -> Branch -> Implement -> Commit -> PR -> CI -> Merge -> Release -> Cleanup.

### 1. Create Issue

- Create a GitHub issue describing the work
- Add the `claude` label to issues created by Claude
- For human-created issues: add `claude:reviewed` label after reviewing (not both labels on same issue)
- Include a **Success Criteria** section with testable checkbox items:
  ```markdown
  ## Success Criteria
  - [ ] Feature X works as described
  - [ ] All existing tests pass
  - [ ] New tests added for feature X
  ```
- Note `*Co-authored by Claude*` if applicable

### 2. Create Branch

Branch naming convention:
```
fix/<issue-number>-<brief-description>
```

Examples:
- `fix/15-add-schedule-parsing`
- `fix/23-fix-departure-times`

### 3. Implement

- Write code and tests
- Update issue checkboxes as criteria are met
- Bump version in `lib/njtransit/version.rb`
- Add entry to `CHANGELOG.md` under `[Unreleased]`

**Every PR must include** a version bump and changelog entry. Dependabot PRs are exempt.

Follow [Semantic Versioning](https://semver.org/):
- **PATCH** (0.0.x): Bug fixes, minor doc updates
- **MINOR** (0.x.0): New features, new API methods
- **MAJOR** (x.0.0): Breaking changes to public API

### 4. Commit

Every commit must include:
- `Closes #<issue-number>` in the commit message body
- Co-authorship footer:
  ```
  Co-Authored-By: Claude <noreply@anthropic.com>
  ```

Example:
```
Add user authentication with Devise

Closes #12

Co-Authored-By: Claude <noreply@anthropic.com>
```

### 5. Push & Create PR

- Push branch to origin
- Create PR using `gh pr create`
- Include `*Co-authored by Claude*` in PR body
- Always use **merge commits** (not squash)

### 6. Monitor CI

```bash
bin/ci-watch <pr-number>              # Check once
bin/ci-watch <pr-number> --poll       # Poll every 10s until done
bin/ci-watch <pr-number> --poll 30    # Poll every 30s
```

Exit codes: `0` = all passed, `1` = failed, `2` = still in progress.

- **Exit 0**: notify user and await instruction to merge
- **Exit 1**: investigate the failure, propose a fix — do NOT merge
- **Exit 2**: check again later

Do NOT merge the PR automatically. Wait for explicit user instruction.

### 7. Merge PR

After CI passes and user gives explicit instruction:

```bash
gh pr merge <pr-number> --merge
```

### 8. Monitor Release

If version was bumped, a release workflow runs automatically on merge to main:
1. Runs the test suite
2. Builds the gem
3. Publishes to RubyGems (via Trusted Publishing / OIDC)
4. Creates a GitHub release with the gem attached

```bash
bin/release-watch                # Check once
bin/release-watch --poll         # Poll every 15s until done
bin/release-watch --poll 30      # Poll every 30s
```

Exit codes: `0` = gem published, `1` = workflow failed, `2` = still in progress.

- **Exit 0**: gem is live on RubyGems — proceed to cleanup
- **Exit 1**: investigate failure, propose fix — do NOT delete branch
- **Exit 2**: check again later

### 9. Cleanup (only after release is healthy)

```bash
git checkout main
git pull origin main
git branch -d <branch-name>
git push origin --delete <branch-name>
git fetch --prune
```

Do NOT delete the branch if the release failed — it may be needed for fixes.
