# NJTransit

A developer-friendly Ruby gem for interacting with NJTransit's API.

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

**Option 1: Global configuration (recommended for most apps)**

```ruby
NJTransit.configure do |config|
  config.api_key = ENV['NJTRANSIT_API_KEY']
  config.log_level = 'info'  # silent (default), info, or debug
end

client = NJTransit.client
# client.stations.list
# client.routes.find(route_id: 123)
```

**Option 2: Explicit instance (for multiple clients or testing)**

```ruby
client = NJTransit::Client.new(
  api_key: 'your_api_key',
  log_level: 'debug'
)
# client.stations.list
```

### Environment Variables

The gem respects these environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `NJTRANSIT_API_KEY` | Your API key | `nil` |
| `NJTRANSIT_LOG_LEVEL` | Logging verbosity (`silent`, `info`, `debug`) | `silent` |
| `NJTRANSIT_BASE_URL` | API base URL | `https://api.njtransit.com` |
| `NJTRANSIT_TIMEOUT` | Request timeout in seconds | `30` |

### Logging

- **silent** (default): No output
- **info**: Logs request URLs and response status codes
- **debug**: Logs full request/response headers and bodies

### Error Handling

The gem raises specific errors for different HTTP status codes:

```ruby
begin
  client.stations.find(id: 'invalid')
rescue NJTransit::NotFoundError => e
  puts "Station not found: #{e.message}"
rescue NJTransit::AuthenticationError => e
  puts "Invalid API key"
rescue NJTransit::RateLimitError => e
  puts "Rate limited, try again later"
rescue NJTransit::ServerError => e
  puts "NJTransit API is having issues"
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
