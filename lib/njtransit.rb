# frozen_string_literal: true

require "monitor"

require_relative "njtransit/version"
require_relative "njtransit/configuration"
require_relative "njtransit/error"
require_relative "njtransit/token_stores"
require_relative "njtransit/client"
require_relative "njtransit/gtfs"

module NJTransit
  CLIENTS_LOCK = Monitor.new
  private_constant :CLIENTS_LOCK

  class << self
    def configure
      yield(configuration)
    end

    def configuration
      @configuration ||= Configuration.new
    end

    # Bus API client (pcsdata.njtransit.com)
    # Memoized under a lock, so threads share one client (and its per-API clients).
    def client
      @client || CLIENTS_LOCK.synchronize { @client ||= Client.new(**configuration.to_h) }
    end

    # Rail API client (raildata.njtransit.com)
    def rail_client
      @rail_client || CLIENTS_LOCK.synchronize do
        @rail_client ||= Client.new(
          **configuration.to_h, base_url: Configuration::DEFAULT_RAIL_BASE_URL,
                                auth_path: "/api/TrainData/getToken"
        )
      end
    end

    def reset!
      CLIENTS_LOCK.synchronize do
        @configuration = nil
        @client = nil
        @rail_client = nil
      end
    end
  end
end

require_relative "njtransit/railtie" if defined?(Rails::Railtie)
