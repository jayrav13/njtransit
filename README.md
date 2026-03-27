# NJTransit

A Ruby gem for NJ Transit's real-time and schedule data — buses, trains, and light rail. Built to be easy to drop into AI agents, chatbots, and creative projects that need live transit data.

## What You Can Do

- **Real-time departures** — "When is the next bus/train?" with live arrival times and delay status
- **Train tracking** — GPS positions, speed, and delay info for every active train
- **Schedule lookups** — Full timetables via GTFS static data, not just the next hour
- **Stop discovery** — Find nearby stops by coordinates
- **Route planning** — Find which routes connect two stops
- **Light rail** — Hudson-Bergen, Newark, and RiverLINE via the same API
- **GTFS-RT feeds** — Raw protobuf feeds for alerts, trip updates, and vehicle positions

## Quick Start

### 1. Get API Credentials

Register at [developer.njtransit.com](https://developer.njtransit.com/registration) to get a username and password.

### 2. Install

```ruby
gem 'njtransit'
```

### 3. Configure

```ruby
require 'njtransit'

NJTransit.configure do |config|
  config.username = ENV['NJTRANSIT_USERNAME']
  config.password = ENV['NJTRANSIT_PASSWORD']
end
```

### 4. Start Querying

```ruby
# Two clients: one for buses/light rail, one for trains
client = NJTransit.client
rail_client = NJTransit.rail_client

# When is the next bus from Port Authority?
client.bus.departures(stop: "PABT", enrich: false)

# Next trains from NY Penn Station
rail_client.rail.train_schedule_19(station: "NY")

# Where is train #3837 right now?
rail_client.rail.train_stop_list(train_id: "3837")

# What stops are within 2000 feet of me?
client.bus.stops_nearby(lat: 40.878, lon: -74.221, radius: 2000, enrich: false)
# radius is in feet

# Light rail routes
client.bus.routes(mode: "HBLR")  # Hudson-Bergen Light Rail
```

## Two Clients, One Gem

NJ Transit splits its API across two hosts. The gem handles this with two clients:

| Client | Host | What it covers |
|--------|------|----------------|
| `NJTransit.client` | pcsdata.njtransit.com | Buses, light rail, bus GTFS-RT |
| `NJTransit.rail_client` | raildata.njtransit.com | Trains, rail GTFS-RT |

Both authenticate automatically. The bus client also supports light rail by passing a `mode` parameter (`HBLR`, `NLR`, `RL`, or `ALL`).

## Capabilities Overview

### Bus & Light Rail (`client.bus`)

Real-time departures, routes, stops, directions, nearby stops/vehicles, and trip tracking. Most methods accept an `enrich` flag — set `enrich: false` if you haven't imported GTFS static data.

### Rail (`rail_client.rail`)

Train schedules (real-time and full-day), station alerts and delay messages, train stop lists, and live vehicle positions for every active train.

### GTFS Static Data

Full offline schedules imported into a local SQLite database. Useful for answering "what's the schedule tomorrow?" when the real-time API only shows the next hour.

```ruby
# Import once
NJTransit::GTFS.import("/path/to/gtfs/data")

# Then query
gtfs = NJTransit::GTFS.new
gtfs.schedule(route: "191", stop: "27005", date: Date.new(2026, 3, 28))
gtfs.routes_between(from: "WBRK", to: "PABT")
```

Rake tasks are also available: `rake njtransit:gtfs:import`, `rake njtransit:gtfs:status`, `rake njtransit:gtfs:clear`.

### GTFS-RT Feeds

Raw protobuf feeds for real-time alerts, trip updates, and vehicle positions:

```ruby
client.bus_gtfs.alerts            # Bus alerts
client.bus_gtfs.vehicle_positions # Bus vehicle positions
rail_client.rail_gtfs.trip_updates # Rail trip updates
```

A newer G2 version of the bus feeds is also available via `client.bus_gtfs_g2`.

## Using with Claude Code

If you have [Claude Code](https://claude.ai/code) installed, the `/njtransit` skill lets you ask transit questions directly from your terminal:

```
/njtransit when is the next train from NY Penn to Trenton?
/njtransit what buses stop near 40.878, -74.221?
/njtransit is the Northeast Corridor delayed?
```

Claude writes and runs Ruby code against the gem to answer your question. It's a good way to explore what the API can do without writing code yourself.

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `NJTRANSIT_USERNAME` | API username | — |
| `NJTRANSIT_PASSWORD` | API password | — |
| `NJTRANSIT_LOG_LEVEL` | `silent`, `info`, or `debug` | `silent` |
| `NJTRANSIT_BASE_URL` | Bus API base URL | `https://pcsdata.njtransit.com` |
| `NJTRANSIT_TIMEOUT` | Request timeout (seconds) | `30` |
| `NJTRANSIT_GTFS_DATABASE_PATH` | SQLite database path | `~/.local/share/njtransit/gtfs.sqlite3` |

## Development

```sh
bin/setup          # Install dependencies
bundle exec rspec  # Run tests (153 specs)
bin/console        # Interactive prompt
```

## Contributing

Bug reports and pull requests are welcome at [github.com/jayrav13/njtransit](https://github.com/jayrav13/njtransit).

## License

MIT — see [LICENSE](https://opensource.org/licenses/MIT).
