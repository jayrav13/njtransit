---
title: NJTransit Ruby gem
---

# NJTransit

A Ruby gem for NJ Transit's real-time and schedule data: buses, trains and light rail.

[![Gem Version](https://badge.fury.io/rb/njtransit.svg)](https://rubygems.org/gems/njtransit)

- **Real-time departures** for buses, trains and light rail
- **Train tracking:** GPS positions, speed and delay for every active train
- **Full schedules** from GTFS static data, not just the next hour
- **GTFS-RT feeds:** raw protobuf alerts, trip updates and vehicle positions

## Get started

Register at [developer.njtransit.com](https://developer.njtransit.com/registration) for API credentials, then:

```ruby
# Gemfile
gem 'njtransit'
```

```ruby
require 'njtransit'

NJTransit.configure do |config|
  config.username = ENV['NJTRANSIT_USERNAME']
  config.password = ENV['NJTRANSIT_PASSWORD']
end

# Next trains from NY Penn Station
NJTransit.rail_client.rail.train_schedule_19(station: "NY")
```

## Documentation

- [README](https://github.com/jayrav13/njtransit#readme): every capability, both clients, GTFS static data, environment variables and the Claude Code skill
- [CHANGELOG](https://github.com/jayrav13/njtransit/blob/main/CHANGELOG.md)
- [RubyGems](https://rubygems.org/gems/njtransit)
- [Source on GitHub](https://github.com/jayrav13/njtransit)

## Design plans

- [Gem design](plans/2025-01-24-njtransit-gem-design.md)
- [Bus API design](plans/2026-01-24-bus-api-design.md)
- [GTFS loader design](plans/2026-01-24-gtfs-loader-design.md)
- [GTFS implementation](plans/2026-01-24-gtfs-implementation.md)
- [Dev infrastructure and agent](superpowers/plans/2026-03-26-dev-infra-and-agent.md)

MIT licensed.
