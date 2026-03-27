# NJTransit Gem: Dev Infra Alignment + Terminal Agent — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align njtransit gem's dev infrastructure (linting, CI, hooks) with the tenor project's patterns, and create a Claude Code terminal agent that can answer real-time NJ Transit questions.

**Architecture:** Four independent workstreams: (1) RuboCop + Gemfile cleanup, (2) GitHub Actions CI upgrade, (3) lefthook alignment, (4) Claude Code slash command agent. The first three are infrastructure — no Ruby code changes. The fourth is a new `.claude/commands/njtransit.md` file that teaches Claude how to use the gem's API.

**Tech Stack:** RuboCop, RSpec, Lefthook, GitHub Actions, Claude Code custom commands

---

## File Structure

| File | Action | Purpose |
|------|--------|---------|
| `.rubocop.yml` | Modify | Tighten config, add rubocop-rspec |
| `Gemfile` | Modify | Add rubocop-rspec dev dependency |
| `.github/workflows/ci.yml` | Modify | Add RuboCop caching, update action versions, add dependabot |
| `.github/dependabot.yml` | Create | Weekly dependency updates (matches tenor) |
| `lefthook.yml` | Modify | Add `parallel: true` to pre-push (minor alignment) |
| `.claude/commands/njtransit.md` | Create | Claude Code slash command for NJ Transit queries |

---

### Task 1: RuboCop + Gemfile Alignment

**Files:**
- Modify: `Gemfile`
- Modify: `.rubocop.yml`

- [ ] **Step 1: Add rubocop-rspec to Gemfile**

In `Gemfile`, change:
```ruby
gem "rubocop", "~> 1.21"
```
to:
```ruby
gem "rubocop", "~> 1.21"
gem "rubocop-rspec", "~> 3.0", require: false
```

- [ ] **Step 2: Update .rubocop.yml**

Replace the full `.rubocop.yml` with:
```yaml
require:
  - rubocop-rspec

AllCops:
  TargetRubyVersion: 3.2
  NewCops: enable
  SuggestExtensions: false

Style/StringLiterals:
  EnforcedStyle: double_quotes

Style/StringLiteralsInInterpolation:
  EnforcedStyle: double_quotes

Style/Documentation:
  Enabled: false

Style/CommentedKeyword:
  Enabled: false

Layout/LineLength:
  Max: 120

Metrics/BlockLength:
  Exclude:
    - "spec/**/*"
    - "*.gemspec"
    - "lib/njtransit/tasks.rb"

# HTTP client code tends to have longer classes/methods
Metrics/ClassLength:
  Exclude:
    - "lib/njtransit/client.rb"
    - "lib/njtransit/gtfs/database.rb"

Metrics/MethodLength:
  Exclude:
    - "lib/njtransit/client.rb"

Metrics/AbcSize:
  Exclude:
    - "lib/njtransit/client.rb"

Metrics/CyclomaticComplexity:
  Exclude:
    - "lib/njtransit/client.rb"

# GTFS database schema is inherently verbose
Metrics/ModuleLength:
  Exclude:
    - "lib/njtransit/gtfs/database.rb"
```

Key changes: added `rubocop-rspec` require, reduced line length from 180 to 120.

- [ ] **Step 3: Run bundle install**

Run: `cd /Users/jravaliya/Code/njtransit && bundle install`
Expected: Gemfile.lock updated with rubocop-rspec

- [ ] **Step 4: Run rubocop to check for new violations**

Run: `cd /Users/jravaliya/Code/njtransit && bundle exec rubocop`
Expected: May have new violations from rubocop-rspec and shorter line length. Fix any that appear.

- [ ] **Step 5: Auto-fix what's possible, manually fix the rest**

Run: `cd /Users/jravaliya/Code/njtransit && bundle exec rubocop -a`
Then fix any remaining violations manually. If specific cops are too noisy for existing code, add targeted exclusions to `.rubocop.yml` rather than rewriting working code.

- [ ] **Step 6: Verify clean rubocop run**

Run: `cd /Users/jravaliya/Code/njtransit && bundle exec rubocop`
Expected: 0 offenses

- [ ] **Step 7: Run rspec to ensure nothing broke**

Run: `cd /Users/jravaliya/Code/njtransit && bundle exec rspec`
Expected: All tests pass

- [ ] **Step 8: Commit**

```bash
cd /Users/jravaliya/Code/njtransit
git add Gemfile Gemfile.lock .rubocop.yml lib/ spec/
git commit -m "chore: tighten rubocop config, add rubocop-rspec

Reduce max line length to 120, add rubocop-rspec for spec linting.
Fix all resulting violations.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 2: GitHub Actions CI Upgrade

**Files:**
- Modify: `.github/workflows/ci.yml`
- Create: `.github/dependabot.yml`

- [ ] **Step 1: Create .ruby-version file**

Create `.ruby-version` with content `3.2` (needed for CI cache key and ruby/setup-ruby auto-detection).

- [ ] **Step 2: Upgrade ci.yml to match tenor patterns**

Replace `.github/workflows/ci.yml` with:
```yaml
name: CI

on:
  pull_request:
  push:
    branches: [main]

jobs:
  lint:
    runs-on: ubuntu-latest
    env:
      RUBOCOP_CACHE_ROOT: tmp/rubocop
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true

      - name: Prepare RuboCop cache
        uses: actions/cache@v4
        env:
          DEPENDENCIES_HASH: ${{ hashFiles('.ruby-version', '**/.rubocop.yml', 'Gemfile.lock') }}
        with:
          path: ${{ env.RUBOCOP_CACHE_ROOT }}
          key: rubocop-${{ runner.os }}-${{ env.DEPENDENCIES_HASH }}-${{ github.ref_name == github.event.repository.default_branch && github.run_id || 'default' }}
          restore-keys: |
            rubocop-${{ runner.os }}-${{ env.DEPENDENCIES_HASH }}-

      - name: Lint code for consistent style
        run: bundle exec rubocop --parallel -f github

  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        ruby-version: ["3.2", "3.3"]
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Ruby ${{ matrix.ruby-version }}
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: ${{ matrix.ruby-version }}
          bundler-cache: true

      - name: Run RSpec
        run: bundle exec rspec
```

Key changes from current: RuboCop caching with `actions/cache@v4`, GitHub-format output (`--parallel -f github`), `.ruby-version` auto-detection, triggers on all PRs (not just to main).

- [ ] **Step 2: Create dependabot.yml**

Create `.github/dependabot.yml`:
```yaml
version: 2
updates:
  - package-ecosystem: bundler
    directory: "/"
    schedule:
      interval: weekly
    open-pull-requests-limit: 10
  - package-ecosystem: github-actions
    directory: "/"
    schedule:
      interval: weekly
    open-pull-requests-limit: 10
```

- [ ] **Step 4: Commit**

```bash
cd /Users/jravaliya/Code/njtransit
git add .ruby-version .github/workflows/ci.yml .github/dependabot.yml
git commit -m "chore: upgrade CI to match tenor patterns

Add RuboCop caching, update to actions/checkout@v6, add dependabot
for weekly bundler and GH Actions dependency updates.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 3: Lefthook Alignment

**Files:**
- Modify: `lefthook.yml`

- [ ] **Step 1: Add parallel flag to pre-push**

Update `lefthook.yml` to:
```yaml
# Lefthook configuration for git hooks
# Install hooks: bundle exec lefthook install
# Docs: https://github.com/evilmartians/lefthook

pre-commit:
  parallel: true
  commands:
    rubocop:
      glob: "*.rb"
      run: bundle exec rubocop --force-exclusion {staged_files}
      stage_fixed: true

pre-push:
  parallel: true
  commands:
    rspec:
      run: bundle exec rspec
```

Only change: added `parallel: true` to pre-push block (matches tenor).

- [ ] **Step 2: Verify hooks work**

Run: `cd /Users/jravaliya/Code/njtransit && bundle exec lefthook run pre-commit`
Expected: rubocop runs on staged files

Run: `cd /Users/jravaliya/Code/njtransit && bundle exec lefthook run pre-push`
Expected: rspec runs

- [ ] **Step 3: Commit**

```bash
cd /Users/jravaliya/Code/njtransit
git add lefthook.yml
git commit -m "chore: align lefthook config with tenor patterns

Add parallel: true to pre-push block.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 4: Claude Code NJTransit Terminal Agent

**Files:**
- Create: `.claude/commands/njtransit.md`

This is the creative centerpiece. The slash command teaches Claude how to use the njtransit gem to answer real-time transit questions from the terminal.

- [ ] **Step 1: Create the commands directory**

Run: `mkdir -p /Users/jravaliya/Code/njtransit/.claude/commands`

- [ ] **Step 2: Create the agent command file**

Create `.claude/commands/njtransit.md`:

````markdown
---
description: Ask NJ Transit questions - bus arrivals, routes, stops, schedules, light rail. Uses the njtransit gem to query real-time data.
---

You are an NJ Transit assistant. The user is asking a transit question from their terminal. Your job is to answer it by writing and executing Ruby code using the `njtransit` gem in this repository.

## Setup

The gem is in the current directory. Credentials come from environment variables. Before making any API call, run this setup:

```ruby
require "dotenv"
Dotenv.load

$LOAD_PATH.unshift(File.join(Dir.pwd, "lib"))
require "njtransit"

NJTransit.configure do |config|
  config.username = ENV["NJTRANSIT_USERNAME"]
  config.password = ENV["NJTRANSIT_PASSWORD"]
end

client = NJTransit.client
```

If credentials are missing, tell the user to set `NJTRANSIT_USERNAME` and `NJTRANSIT_PASSWORD` in their `.env` file. They can register at https://developer.njtransit.com/registration

## Available API Methods

### Bus & Light Rail Routes
```ruby
# Get all routes (mode: "BUS", "NLR", "HBLR", "RL", or "ALL")
# Currently the gem hardcodes BUS mode, so pass mode directly:
client.bus.routes  # BUS routes only
```

### Directions for a Route
```ruby
client.bus.directions(route: "197")
# => [{"Direction_1"=>"New York", "Direction_2"=>"Willowbrook Mall"}]
```

### Stops on a Route
```ruby
client.bus.stops(route: "197", direction: "New York", enrich: false)
# => [{"busstopdescription"=>"...", "busstopnumber"=>"..."}]
# Use name_contains: "keyword" to filter
```

### Stop Name Lookup
```ruby
client.bus.stop_name(stop_number: "19159", enrich: false)
# => {"stopName"=>"15TH AVE AT BEDFORD ST"}
```

### Real-Time Departures (most useful for "when is my bus?")
```ruby
client.bus.departures(stop: "PABT", enrich: false)
# Returns trips active in next hour
# Can filter: route: "197", direction: "New York"
# Response includes: public_route, header (destination), departuretime ("in 18 mins"),
#   lanegate, vehicle_id, passload, sched_dep_time
```

### Route Trips at a Location
```ruby
client.bus.route_trips(location: "PABT", route: "113")
# Returns scheduled trips with departure times, lane/gate info
```

### Trip Stops (track a specific bus)
```ruby
client.bus.trip_stops(
  internal_trip_number: "19624134",
  sched_dep_time: "6/22/2023 12:50:00 AM"
)
# Returns every stop the trip makes with status (Departed/Approaching/etc)
```

### Nearby Stops
```ruby
client.bus.stops_nearby(lat: 40.8523, lon: -74.2567, radius: 2000, enrich: false)
# radius is in feet. Returns stops with distance
```

### Nearby Vehicles
```ruby
client.bus.vehicles_nearby(lat: 40.8523, lon: -74.2567, radius: 5000, enrich: false)
# Returns live vehicle positions with route, destination, passenger load
```

### Locations (terminals/hubs)
```ruby
client.bus.locations
# => [{"bus_terminal_code"=>"PABT", "bus_terminal_name"=>"Port Authority Bus Terminal"}, ...]
```

### GTFS Static Data (schedules, offline queries)
```ruby
# Only if GTFS data has been imported
gtfs = NJTransit::GTFS.new
gtfs.stops.find_by_code("WBRK")         # Find a stop
gtfs.routes.find("197")                   # Find a route
gtfs.routes_between(from: "WBRK", to: "PABT")  # Routes connecting two stops
gtfs.schedule(route: "197", stop: "WBRK", date: Date.today)  # Full day schedule
```

## Common Terminal Codes

- **PABT** — Port Authority Bus Terminal (Manhattan)
- **NWKP** — Newark Penn Station
- **JCSQ** — Journal Square
- **HOBO** — Hoboken Terminal
- **SECC** — Secaucus Junction

## How to Answer Questions

1. **"When is my next bus?"** → Use `departures` with the stop and optionally route. Show departure times, destinations, and vehicle info in a clean table.

2. **"What buses go from X to Y?"** → Use GTFS `routes_between` if available, otherwise use `routes` + `stops` to find matching routes.

3. **"What stops are near me?"** → Ask for their location or use a known landmark's coordinates with `stops_nearby`.

4. **"Where is the 197 bus right now?"** → Use `vehicles_nearby` with a wide radius, filtered by route in the results.

5. **"What's the schedule for route X?"** → Use `departures` for real-time, or GTFS `schedule` for the full day.

## Response Style

- Be concise — the user is in a terminal, probably in a hurry
- Format departure times as a clean table
- Highlight the NEXT departure prominently
- Include passenger load info when available (EMPTY, LIGHT, MODERATE, HEAVY)
- If enrichment fails (GTFS not imported), use `enrich: false` and still return results
- Always use `enrich: false` to avoid GTFS dependency unless the user specifically asks for enriched data

## User's Question

$ARGUMENTS
````

- [ ] **Step 3: Test the command works**

From the njtransit directory, run: `/njtransit what routes are available?`
Verify Claude picks up the command and attempts to use the gem.

- [ ] **Step 4: Commit**

```bash
cd /Users/jravaliya/Code/njtransit
git add .claude/commands/njtransit.md
git commit -m "feat: add Claude Code terminal agent for NJ Transit queries

New /njtransit slash command lets you ask transit questions from terminal.
Supports real-time departures, route lookup, nearby stops, vehicle tracking,
and GTFS schedule queries via the njtransit gem.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Execution Order

Tasks 1-3 are independent infrastructure and can be parallelized.
Task 4 (agent) is also independent but is the most creative piece.

Recommended: run all 4 in parallel if using subagent-driven development.
