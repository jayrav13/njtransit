# NJTransit Ruby Gem Design

## Overview

A developer-friendly Ruby gem for interacting with NJTransit's API. Designed for both personal use and open-source distribution.

## Design Decisions

| Aspect | Decision | Rationale |
|--------|----------|-----------|
| Name | `njtransit` | Simple, direct, recognizable |
| Ruby version | 3.2+ | Modern Ruby, allows newest syntax |
| HTTP client | Faraday + Typhoeus adapter | Typhoeus performance with Faraday middleware flexibility |
| Logging | Environment-based (silent/info/debug) | Selective logging based on `NJTRANSIT_LOG_LEVEL` |
| Testing | RSpec | Most common for gems, expressive syntax |
| API pattern | Global config + explicit instances | Convenience for simple apps, flexibility for advanced use |
| Errors | Comprehensive hierarchy | Granular error handling for all HTTP status codes |

## Architecture

### Module Structure

```
lib/
├── njtransit.rb              # Entry point, global config
└── njtransit/
    ├── version.rb
    ├── configuration.rb      # Config object with env var defaults
    ├── client.rb             # HTTP client (Faraday + Typhoeus)
    ├── error.rb              # Error class hierarchy
    └── resources/            # One file per API domain
        └── base.rb           # Base class for resources
```

### Usage Patterns

**Global configuration (convenience):**

```ruby
NJTransit.configure do |config|
  config.api_key = ENV['NJTRANSIT_API_KEY']
  config.log_level = 'debug'  # silent, info, or debug
end

client = NJTransit.client
client.stations.list
```

**Explicit instance (flexibility):**

```ruby
client = NJTransit::Client.new(
  api_key: "your_key",
  log_level: "info"
)
client.stations.list
```

Both patterns use the same `Client` class - no code duplication.

### Configuration

Supports environment variables with sensible defaults:

- `NJTRANSIT_API_KEY` - API key (required for most endpoints)
- `NJTRANSIT_LOG_LEVEL` - Logging verbosity (silent/info/debug, default: silent)
- `NJTRANSIT_BASE_URL` - API base URL (overridable for testing)
- `NJTRANSIT_TIMEOUT` - Request timeout in seconds (default: 30)

### Error Hierarchy

```
NJTransit::Error
├── ClientError (4xx)
│   ├── BadRequestError (400)
│   ├── AuthenticationError (401)
│   ├── ForbiddenError (403)
│   ├── NotFoundError (404)
│   ├── MethodNotAllowedError (405)
│   ├── ConflictError (409)
│   ├── GoneError (410)
│   ├── UnprocessableEntityError (422)
│   └── RateLimitError (429)
├── ServerError (5xx)
│   ├── InternalServerError (500)
│   ├── BadGatewayError (502)
│   ├── ServiceUnavailableError (503)
│   └── GatewayTimeoutError (504)
└── ConnectionError
    └── TimeoutError
```

All errors include the original response for inspection.

### Logging Levels

- **silent** (default): No output
- **info**: Request URLs and response status codes
- **debug**: Full request/response headers and bodies

## Next Steps

1. Drop NJTransit API documentation into `docs/api/`
2. Review available endpoints
3. Create resource classes for each API domain (stations, routes, schedules, etc.)
4. Add comprehensive specs with mocked responses
5. Document usage in README

## Notes

- `docs/api/` is gitignored - API docs are private/behind auth
- Full API coverage is the goal - establish patterns early, then the rest becomes mechanical
