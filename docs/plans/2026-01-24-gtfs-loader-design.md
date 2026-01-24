# GTFS Static Data Loader Design

**Date:** 2026-01-24
**Issue:** [#3 - Add GTFS static data loader for complete/deterministic dataset](https://github.com/jayrav13/njtransit/issues/3)
**Status:** Approved

## Problem

The real-time Bus API has limitations that prevent building a complete dataset:

| Limitation | Impact |
|------------|--------|
| No lat/lon in `stops()` response | Can't plot stops on a map |
| `departures()` only shows ~1hr window | Miss routes with later trips |
| No route discovery | Can't find "all routes from A to B" |

GTFS static data solves these gaps and enables enriching real-time API responses with complete information.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    NJTransit Gem                        │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────┐          ┌─────────────────────────┐  │
│  │  Bus API    │─────────▶│  GTFS (enrichment)      │  │
│  │  (real-time)│          │                         │  │
│  └─────────────┘          │  ┌───────────────────┐  │  │
│                           │  │  Sequel + SQLite  │  │  │
│  ┌─────────────┐          │  └───────────────────┘  │  │
│  │  GTFS API   │─────────▶│           │             │  │
│  │  (static)   │          │           ▼             │  │
│  └─────────────┘          │  ~/.local/share/        │  │
│                           │  njtransit/gtfs.sqlite3 │  │
│                           └─────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

**Key decisions:**

- **Sequel gem** for database access (lightweight, clean DSL)
- **SQLite** stored in XDG-compliant location, configurable via `NJTransit.configure`
- **GTFS import is a deployment step** - errors raised if missing at runtime
- **Bus API enriches responses by default** with GTFS data

## File Structure

```
lib/njtransit/
├── gtfs.rb                     # Main GTFS module (import, new, status)
├── gtfs/
│   ├── database.rb             # Sequel connection, schema setup
│   ├── importer.rb             # Parses CSV files, populates DB
│   ├── models/
│   │   ├── agency.rb           # Sequel::Model classes
│   │   ├── route.rb
│   │   ├── stop.rb
│   │   ├── trip.rb
│   │   ├── stop_time.rb
│   │   ├── calendar_date.rb
│   │   └── shape.rb
│   └── queries/
│       ├── routes_between.rb   # Find routes serving two stops
│       └── schedule.rb         # Full day schedule for route/stop
├── tasks.rb                    # Rake task definitions
└── railtie.rb                  # Auto-load tasks in Rails

# Updated existing files:
lib/njtransit/configuration.rb  # Add gtfs_database_path option
lib/njtransit/resources/bus.rb  # Add enrichment logic
lib/njtransit/error.rb          # Add GTFSNotImportedError
```

## Database Schema

```sql
CREATE TABLE agencies (
  agency_id TEXT PRIMARY KEY,
  agency_name TEXT,
  agency_url TEXT,
  agency_timezone TEXT
);

CREATE TABLE routes (
  route_id TEXT PRIMARY KEY,
  agency_id TEXT,
  route_short_name TEXT,
  route_long_name TEXT,
  route_type INTEGER,
  route_color TEXT
);

CREATE TABLE stops (
  stop_id TEXT PRIMARY KEY,
  stop_code TEXT,
  stop_name TEXT,
  stop_lat REAL,
  stop_lon REAL,
  zone_id TEXT
);

CREATE TABLE trips (
  trip_id TEXT PRIMARY KEY,
  route_id TEXT,
  service_id TEXT,
  trip_headsign TEXT,
  direction_id INTEGER,
  shape_id TEXT
);

CREATE TABLE stop_times (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  trip_id TEXT,
  stop_id TEXT,
  arrival_time TEXT,
  departure_time TEXT,
  stop_sequence INTEGER
);

CREATE TABLE calendar_dates (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  service_id TEXT,
  date TEXT,
  exception_type INTEGER
);

CREATE TABLE shapes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  shape_id TEXT,
  shape_pt_lat REAL,
  shape_pt_lon REAL,
  shape_pt_sequence INTEGER
);

-- Indexes
CREATE INDEX idx_stops_stop_code ON stops(stop_code);
CREATE INDEX idx_routes_short_name ON routes(route_short_name);
CREATE INDEX idx_trips_route_id ON trips(route_id);
CREATE INDEX idx_trips_service_id ON trips(service_id);
CREATE INDEX idx_stop_times_trip_id ON stop_times(trip_id);
CREATE INDEX idx_stop_times_stop_id ON stop_times(stop_id);
CREATE INDEX idx_calendar_dates_service_id_date ON calendar_dates(service_id, date);
CREATE INDEX idx_shapes_shape_id ON shapes(shape_id);
```

## GTFS Import API

```ruby
# Import (deployment time)
NJTransit::GTFS.import("/path/to/bus_data/")
NJTransit::GTFS.import("/path/to/bus_data/", force: true)  # Re-import, clears existing

# Status check
NJTransit::GTFS.status
# => {
#      imported: true,
#      path: "~/.local/share/njtransit/gtfs.sqlite3",
#      routes: 261,
#      stops: 16594,
#      trips: 45843,
#      imported_at: 2026-01-24
#    }
```

### Rake Tasks

```ruby
# In user's Rakefile
require 'njtransit/tasks'

# Provides:
# rake njtransit:gtfs:import[/path/to/bus_data]
# rake njtransit:gtfs:status
# rake njtransit:gtfs:clear
```

Rails apps auto-load tasks via Railtie.

## GTFS Query API

```ruby
gtfs = NJTransit::GTFS.new

# Stops
gtfs.stops.all                          # => [Stop, Stop, ...]
gtfs.stops.find("stop_id_value")        # => Stop (by stop_id)
gtfs.stops.find_by_code("21681")        # => Stop (by stop_code)
gtfs.stops.where(zone_id: "NB")         # => [Stop, ...]

# Routes
gtfs.routes.all
gtfs.routes.find("197")                 # => Route (by route_id or short_name)

# Route discovery
gtfs.routes_between(from: "WBRK", to: "PABT")
# => ["194", "197", "198"]

# Schedule
gtfs.schedule(route: "197", stop: "WBRK", date: Date.today)
# => [{ trip_id: "...", arrival_time: "06:45:00", departure_time: "06:45:00" }, ...]
```

### Model Objects

```ruby
stop = gtfs.stops.find_by_code("21681")
stop.stop_id      # => "1"
stop.stop_code    # => "21681"
stop.stop_name    # => "WILLOWBROOK MALL"
stop.lat          # => 40.8523
stop.lon          # => -74.2567
stop.to_h         # => { stop_id: "1", stop_code: "21681", ... }
```

## Bus API Enrichment

Enrichment is **ON by default**. GTFS data is merged into Bus API responses automatically.

```ruby
# Enriched (default)
client.bus.stops(route: "191", direction: "New York")
# => [{ "stop_id" => "21681", "stop_name" => "WILLOWBROOK MALL",
#       "stop_lat" => 40.8523, "stop_lon" => -74.2567 }, ...]

# Opt-out
client.bus.stops(route: "191", direction: "New York", enrich: false)
# => Original unenriched response
```

### Enrichment by Method

| Method | Enrichment |
|--------|------------|
| `stops(route:, direction:)` | Add lat/lon from GTFS |
| `departures(stop:)` | Add stop lat/lon, route long_name |
| `stop_name(stop:)` | Add lat/lon |
| `stops_nearby(lat:, lon:)` | Already has coords, add zone_id |
| `vehicles_nearby(lat:, lon:)` | Add route long_name |

### Error Handling

If GTFS hasn't been imported, enriched calls raise `GTFSNotImportedError`:

```ruby
client.bus.stops(route: "191", direction: "New York")
# => raises NJTransit::GTFSNotImportedError:
#    "GTFS data not found. Run: rake njtransit:gtfs:import[/path/to/bus_data]"
#
#    Detected GTFS files at: ./docs/api/njtransit/bus_data/
#    Hint: rake njtransit:gtfs:import[./docs/api/njtransit/bus_data/]
```

Calls with `enrich: false` work without GTFS.

## Configuration

```ruby
NJTransit.configure do |config|
  # Existing
  config.username = "..."
  config.password = "..."

  # New
  config.gtfs_database_path = "/custom/path/gtfs.sqlite3"  # optional
end
```

### Default Path Resolution

1. `config.gtfs_database_path` if set
2. `$XDG_DATA_HOME/njtransit/gtfs.sqlite3` if XDG_DATA_HOME set
3. `~/.local/share/njtransit/gtfs.sqlite3`

### Auto-Detection Paths

For helpful error messages, these paths are checked for GTFS files:

```ruby
GTFS_SEARCH_PATHS = [
  "./bus_data",
  "./vendor/bus_data",
  "./docs/api/njtransit/bus_data",
  "#{Gem.loaded_specs['njtransit']&.gem_dir}/data/bus_data"
]
```

## Dependencies

```ruby
# Gemfile additions
gem "sequel", "~> 5.0"
gem "sqlite3", "~> 2.0"
```

## Testing Strategy

### Unit Tests (mocked, fast)

```
spec/njtransit/gtfs/importer_spec.rb     # CSV parsing, error handling
spec/njtransit/gtfs/models/*_spec.rb     # Model attributes, queries
spec/njtransit/gtfs/queries/*_spec.rb    # routes_between, schedule logic
```

### Integration Tests (real SQLite, fixtures)

```
spec/integration/gtfs_spec.rb            # Full import/query workflows
```

### Fixtures

```
spec/fixtures/gtfs/
├── agency.txt      # 1 agency
├── routes.txt      # 10 routes
├── stops.txt       # 50 stops
├── trips.txt       # 100 trips
├── stop_times.txt  # 500 stop times
├── calendar_dates.txt
└── shapes.txt
```

### Bus Enrichment Tests

```
spec/njtransit/resources/bus_spec.rb
- Responses include GTFS fields when enriched
- enrich: false skips enrichment
- GTFSNotImportedError raised when DB missing
```

## Deployment

GTFS import runs once during deployment:

```dockerfile
# Dockerfile
RUN bundle exec rake njtransit:gtfs:import[/app/vendor/bus_data/]
```

```ruby
# Capistrano
after 'deploy:published', 'njtransit:gtfs:import'
```

```yaml
# CI/CD pipeline
- run: bundle exec rake njtransit:gtfs:import[./bus_data/]
```
