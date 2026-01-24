# NJTransit

A developer-friendly Ruby gem for interacting with NJTransit's real-time Bus API and GTFS static data.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'njtransit'
```

And then execute:

```sh
bundle install
```

Or install it yourself as:

```sh
gem install njtransit
```

## Usage

### Configuration

```ruby
NJTransit.configure do |config|
  config.username = ENV['NJTRANSIT_USERNAME']
  config.password = ENV['NJTRANSIT_PASSWORD']
  config.log_level = 'info'  # silent (default), info, or debug
end

client = NJTransit.client
```

### Bus API

The Bus API provides real-time data for NJ Transit buses:

```ruby
# Get all routes
client.bus.routes

# Get directions for a route
client.bus.directions(route: "197")

# Get stops for a route and direction
client.bus.stops(route: "197", direction: "New York")

# Get departures from a stop
client.bus.departures(stop: "WBRK")

# Get nearby stops
client.bus.stops_nearby(lat: 40.8523, lon: -74.2567, radius: 0.5)

# Get nearby vehicles
client.bus.vehicles_nearby(lat: 40.8523, lon: -74.2567, radius: 0.5)
```

### GTFS Static Data

GTFS (General Transit Feed Specification) data provides complete schedule and stop information. This data complements the real-time API with:

- Stop coordinates (lat/lon)
- Route discovery (find all routes between two stops)
- Full day schedules (not just the next hour)

#### Importing GTFS Data

GTFS data must be imported before use. This is typically done during deployment:

```ruby
# Via Ruby
NJTransit::GTFS.import("/path/to/gtfs/data")

# Check import status
NJTransit::GTFS.status
# => { imported: true, routes: 261, stops: 16594, ... }
```

Or via Rake tasks:

```bash
# Import GTFS data
rake njtransit:gtfs:import[/path/to/gtfs/data]

# Check status
rake njtransit:gtfs:status

# Clear database
rake njtransit:gtfs:clear
```

For non-Rails apps, add to your Rakefile:

```ruby
require 'njtransit/tasks'
```

#### Querying GTFS Data

```ruby
gtfs = NJTransit::GTFS.new

# Find stops
gtfs.stops.all
gtfs.stops.find_by_code("WBRK")
# => Stop with lat: 40.8523, lon: -74.2567

# Find routes
gtfs.routes.all
gtfs.routes.find("197")

# Find routes between two stops
gtfs.routes_between(from: "WBRK", to: "PABT")
# => ["194", "197", "198"]

# Get full day schedule
gtfs.schedule(route: "197", stop: "WBRK", date: Date.today)
# => [{ trip_id: "...", arrival_time: "06:00:00", ... }, ...]
```

### Automatic Enrichment

By default, Bus API responses are automatically enriched with GTFS data:

```ruby
# Stops include lat/lon from GTFS
client.bus.stops(route: "197", direction: "New York")
# => [{ "stop_id" => "WBRK", "stop_lat" => 40.8523, "stop_lon" => -74.2567, ... }]

# Departures include route long name
client.bus.departures(stop: "WBRK")
# => [{ "route" => "197", "route_long_name" => "Willowbrook - Port Authority", ... }]
```

To disable enrichment (e.g., if GTFS isn't imported):

```ruby
client.bus.stops(route: "197", direction: "New York", enrich: false)
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `NJTRANSIT_USERNAME` | API username | `nil` |
| `NJTRANSIT_PASSWORD` | API password | `nil` |
| `NJTRANSIT_LOG_LEVEL` | Logging verbosity | `silent` |
| `NJTRANSIT_BASE_URL` | API base URL | `https://pcsdata.njtransit.com` |
| `NJTRANSIT_TIMEOUT` | Request timeout in seconds | `30` |
| `NJTRANSIT_GTFS_DATABASE_PATH` | SQLite database path | `~/.local/share/njtransit/gtfs.sqlite3` |

### Error Handling

```ruby
begin
  client.bus.stops(route: "197", direction: "New York")
rescue NJTransit::GTFSNotImportedError => e
  puts "GTFS not imported: #{e.message}"
  # Or use enrich: false to skip GTFS
rescue NJTransit::AuthenticationError => e
  puts "Invalid credentials"
rescue NJTransit::RateLimitError => e
  puts "Rate limited, try again later"
rescue NJTransit::Error => e
  puts "Something went wrong: #{e.message}"
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bundle exec rspec` to run the tests. You can also run `bin/console` for an interactive prompt.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/jayrav13/njtransit. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/jayrav13/njtransit/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the NJTransit project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/jayrav13/njtransit/blob/main/CODE_OF_CONDUCT.md).
