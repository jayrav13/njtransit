# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

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
