# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Fixed

- Threads sharing one client no longer mint a token each when NJ Transit rejects the token they all sent. Renewal is single-flight per API (one lock per token key, shared by every client in the process): the first thread mints, the others retry with its token. A rejection deletes the stored token only if it is still the one that was sent, and a token another thread or client already stored is reused without minting. Applies on both the JSON form and raw (GTFS-RT) paths
- `Client#api_client`, `NJTransit.client` and `NJTransit.rail_client` are memoized under a lock, so threads racing on first use share one instance

The token store contract (`read`/`write`/`delete`) is unchanged. Races between separate processes sharing a store are not covered: each process can still mint once per rejection

## [1.3.0] - 2026-11-14

### Fixed

- GTFS-RT feeds (`bus_gtfs`, `bus_gtfs_g2`, `rail_gtfs`) now authenticate at their own APIs (`/api/GTFS/authenticateUser`, `/api/GTFSG2/authenticateUser`, `/api/GTFSRT/getToken`). They used to reuse the bus or rail API token, which NJ Transit rejects, so every feed call failed
- A token rejected with HTTP 500 and a JSON "invalid token" error (NJ Transit's actual response, worded "Invalid token." or "Invalid Token. Please authenticate user.") now triggers one re-authentication and retry on both the JSON and raw paths, instead of raising `InternalServerError`

### Added

- `Client#api_client(auth_path)`: a client for another API on the same host, sharing credentials, timeout, logging and token store

### Changed

- Token store keys include the auth endpoint: `njtransit:token:<base_url><auth_path>:<username>`. Tokens stored by 1.2.0 aren't found under the new keys, so each API mints one fresh token after upgrading

## [1.2.0] - 2026-11-14

### Added

- Pluggable auth token store (`config.token_store` / `Client.new(token_store:)`): any object with `read`, `write` and `delete`, including `Rails.cache`. Lets long-running processes reuse a token across restarts instead of hitting NJ Transit's daily token cap
- `NJTransit::TokenStores::Memory` (the default, shared per process) and `NJTransit::TokenStores::File` (JSON file, mode 0600, atomic writes under an exclusive `flock`, safe across processes)
- Assigning a `token_store` without `read`/`write`/`delete` raises `ArgumentError`
- `Client#token_key` and `Client.default_token_store`

### Changed

- Tokens are keyed by API host and username (`njtransit:token:<base_url>:<username>`), not host alone
- Raw GTFS-RT requests now detect an expired token (a JSON `Invalid token.` body, or a 401/403), re-authenticate and retry once, as JSON requests already did. A JSON error body on a feed now raises `APIError` instead of being returned as feed bytes
- Clearing an expired token deletes the stored copy only if it is still the stale one, so clients sharing a store don't discard each other's fresh tokens
- A failing token store always warns on stderr (regardless of `log_level`) and is bypassed instead of raising

### Deprecated

- `Client.token_cache`: use `Client.default_token_store` or configure `token_store`

## [1.1.5] - 2026-11-14

### Added

- GitHub Pages landing page (`docs/index.md`); https://jayravaliya.com/njtransit/ no longer 404s
- `CLAUDE.md` Documentation Sync row for the landing page

## [1.1.4] - 2026-04-26

### Changed

- Release workflow now runs RuboCop in addition to RSpec before publishing the gem

## [1.1.3] - 2026-04-26

### Added

- `CLAUDE.md` "Documentation Sync" section with a table mapping change types to required doc surfaces

## [1.1.2] - 2026-04-26

### Changed

- CI test matrix now includes Ruby 3.4 alongside 3.2 and 3.3

### Fixed

- Declare `csv` as a runtime dependency (no longer a default gem in Ruby 3.4)

## [1.1.1] - 2026-04-26

### Fixed

- `Configuration` initialize specs now stub `NJTRANSIT_USERNAME` / `NJTRANSIT_PASSWORD` so they pass regardless of the host environment

## [1.1.0] - 2026-03-27

### Added

- `njtransit install-skill` CLI command to install `/njtransit` slash command for Claude Code
- `njtransit uninstall-skill` to remove it
- Skill works across Claude Code CLI, desktop app, and IDE extensions

## [1.0.2] - 2026-03-27

### Added

- `bin/release-watch` — monitors release workflow and confirms gem is live on RubyGems

### Changed

- Updated CLAUDE.md step 8 to use `bin/release-watch`
- Updated README.md with CI and release tooling documentation

## [1.0.1] - 2026-03-27

### Fixed

- Switch release workflow to Trusted Publishing (OIDC) for RubyGems authentication

## [1.0.0] - 2026-03-27

### Added

- **Rail API** — train schedules, station messages, train stop lists, and live vehicle positions via `NJTransit.rail_client`
- **Bus GTFS-RT** — real-time alerts, trip updates, and vehicle positions (`client.bus_gtfs`)
- **Bus GTFS-RT G2** — newer version of bus feeds (`client.bus_gtfs_g2`)
- **Rail GTFS-RT** — real-time rail feeds (`rail_client.rail_gtfs`)
- **Light rail support** — `mode` parameter on bus API methods (`HBLR`, `NLR`, `RL`, `ALL`)
- **GTFS static data** — full offline schedules via SQLite, with import/query/rake tasks
- **Automatic enrichment** — bus API responses enriched with GTFS lat/lon and route names
- **Token caching** — auth tokens cached across client instances to avoid hitting daily API limits
- **Descriptive auth errors** — actual API error messages surfaced instead of generic "Authentication failed"
- **CI pipeline** — RuboCop linting and RSpec on Ruby 3.2/3.3
- **Automated releases** — publish to RubyGems on merge to main when version changes

### Bus API

- `routes`, `directions`, `stops`, `stop_name`, `departures`
- `route_trips`, `trip_stops`, `stops_nearby`, `vehicles_nearby`
- `locations` with mode filtering

### Rail API

- `stations`, `station_messages`, `station_schedule`
- `train_schedule`, `train_schedule_19`, `train_stop_list`
- `vehicle_data`

## [0.1.0] - 2026-01-24

- Initial release
