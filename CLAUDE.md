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

## Development Workflow

### Complete Issue-to-Deploy Workflow

**Every change follows this workflow, even small/transient fixes:**

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  1. CREATE ISSUE (if not exists)                                            │
│     - Add `claude` label                                                    │
│     - Include Success Criteria checkboxes                                   │
│     - Note: "*Co-authored by Claude*"                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│  2. CREATE BRANCH                                                           │
│     - Format: fix/<issue-number>-<brief-description>                        │
│     - Checkout the new branch                                               │
├─────────────────────────────────────────────────────────────────────────────┤
│  3. IMPLEMENT                                                               │
│     - Write code, tests                                                     │
│     - Update issue checkboxes as criteria are met                           │
├─────────────────────────────────────────────────────────────────────────────┤
│  4. COMMIT                                                                  │
│     - Include "Closes #<issue-number>" in commit body                       │
│     - Include "Co-Authored-By: Claude <noreply@anthropic.com>"              │
├─────────────────────────────────────────────────────────────────────────────┤
│  5. PUSH BRANCH                                                             │
│     - Push to origin                                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│  6. CREATE PR                                                               │
│     - Use GitHub MCP (mcp__github__create_pull_request)                     │
│     - Include "*Co-authored by Claude*" in body                             │
│     - Always use merge commits (not squash)                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│  7. WAIT FOR MERGE                                                          │
│     - User reviews and merges, OR                                           │
│     - User gives green light for Claude to merge via GitHub MCP             │
├─────────────────────────────────────────────────────────────────────────────┤
│  8. CLEANUP (after user confirms deployment is healthy or N/A)              │
│     - git checkout main                                                     │
│     - git pull origin main                                                  │
│     - git branch -d <branch-name>                                           │
│     - Delete remote branch via GitHub MCP or git push origin --delete       │
│     - git fetch --prune                                                     │
│                                                                             │
│     ⚠️  DO NOT delete branch if deployment failed - may need to push fixes  │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Note:** This repo does not have DigitalOcean deployment monitoring. After PR is merged, ask user for green light before branch cleanup.

### GitHub Issue Requirements

**Creating Issues (Claude):**
- Always add the `claude` label
- Note co-authorship in the issue body: `*Co-authored by Claude*`
- Include a **Success Criteria** section with checkbox items

**Reviewing Issues (Human-created):**
- Issues without `claude` or `claude:reviewed` labels are human-created
- After reading, add the `claude:reviewed` label
- Never add both `claude` and `claude:reviewed` to the same issue

### Success Criteria

**Every issue should have a Success Criteria section** with testable checkbox items:

```markdown
## Success Criteria

- [ ] Feature X works as described
- [ ] All existing tests pass
- [ ] New tests added for feature X
```

### Branch Naming Convention

Format: `fix/<issue-number>-<brief-description>`

Examples:
- `fix/15-add-schedule-parsing`
- `fix/23-fix-departure-times`

### Commit Requirements

**Auto-close issues:** Include `Closes #<issue-number>` in the commit message body.

**Co-authorship:** All commits must include:
```
Co-Authored-By: Claude <noreply@anthropic.com>
```

### Pull Request Requirements

- Use GitHub MCP (`mcp__github__create_pull_request`) to create PRs
- Use GitHub MCP (`mcp__github__merge_pull_request`) to merge when given green light
- Include co-authorship note in PR body: `*Co-authored by Claude*`
- **Always use merge commits** (squash merge is disabled)

### Branch Cleanup

**Only perform after user confirms deployment is healthy (or N/A):**

```bash
git checkout main
git pull origin main
git branch -d <branch-name>
git push origin --delete <branch-name>
git fetch --prune
```
