# NJ Transit Bus API Integration Design

## Overview

Add support for the NJ Transit BUSDV2 API, providing access to bus schedules, real-time departures, stops, routes, and vehicle locations.

## Configuration

Replace `api_key` with `username` and `password`. Update default `base_url` to production endpoint.

```ruby
NJTransit.configure do |c|
  c.username = ENV["NJTRANSIT_USERNAME"]
  c.password = ENV["NJTRANSIT_PASSWORD"]
  c.base_url = "https://pcsdata.njtransit.com"  # new default
  c.timeout = 30
end
```

## Authentication

Lazy authentication by default:

1. First API call checks for cached token
2. If no token, call `authenticateUser` with username/password
3. Cache token in memory on client instance
4. If response contains `{"errorMessage": "Invalid token."}`, re-authenticate once and retry
5. If re-auth fails, raise `NJTransit::AuthenticationError`

No cross-process token persistence. Each client instance manages its own token.

## Client Changes

The Bus API requires `multipart/form-data` POST requests (not JSON).

Add `post_form` method to client:

```ruby
def post_form(path, params = {})
  response = connection.post(path) do |req|
    req.body = params  # Faraday handles form encoding
  end
  handle_response(response)
end
```

The `Bus` resource injects the token automatically into all requests.

## Bus Resource

Single flat resource at `client.bus` with hardcoded `mode: "BUS"`. Future modes (light rail, etc.) will be separate resources using the same underlying API.

### Methods

| Method | Required Params | Optional Params | API Endpoint |
|--------|----------------|-----------------|--------------|
| `locations` | - | - | `getLocations` |
| `routes` | - | - | `getBusRoutes` |
| `directions` | `route:` | - | `getBusDirectionsData` |
| `stops` | `route:`, `direction:` | `name_contains:` | `getStops` |
| `stop_name` | `stop_number:` | - | `getStopName` |
| `route_trips` | `location:`, `route:` | - | `getRouteTrips` |
| `departures` | `stop:` | `route:`, `direction:` | `getBusDV` |
| `trip_stops` | `internal_trip_number:`, `sched_dep_time:` | `timing_point_id:` | `getTripStops` |
| `stops_nearby` | `lat:`, `lon:`, `radius:` | `route:`, `direction:` | `getBusLocationsData` |
| `vehicles_nearby` | `lat:`, `lon:`, `radius:` | - | `getVehicleLocations` |

### Return Values

All methods return raw hashes/arrays as returned by the API. No object wrapping.

## Error Handling

The Bus API returns errors in response body, not HTTP status codes.

Detection:
- Check response for `errorMessage` key
- `"Invalid token."` → re-authenticate, retry once, raise `AuthenticationError` if still failing
- Other `errorMessage` values → raise `NJTransit::APIError`

New error class:

```ruby
class APIError < Error; end
```

Existing errors (ConnectionError, TimeoutError, HTTP status errors) remain unchanged.

## File Structure

```
lib/njtransit/
├── configuration.rb      # Modified: username/password, new base_url
├── client.rb             # Modified: post_form, token management, bus accessor
├── error.rb              # Modified: add APIError
└── resources/
    ├── base.rb           # Unchanged
    └── bus.rb            # New
```

## Usage Example

```ruby
NJTransit.configure do |c|
  c.username = "myuser"
  c.password = "mypass"
end

client = NJTransit.client

# Get all routes
client.bus.routes

# Get real-time departures at Port Authority
client.bus.departures(stop: "PABT")

# Find vehicles near Newark
client.bus.vehicles_nearby(lat: 40.737, lon: -74.170, radius: 2000)
```
