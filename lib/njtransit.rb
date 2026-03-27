# frozen_string_literal: true

require_relative "njtransit/version"
require_relative "njtransit/configuration"
require_relative "njtransit/error"
require_relative "njtransit/client"
require_relative "njtransit/gtfs"

module NJTransit
  class << self
    def configure
      yield(configuration)
    end

    def configuration
      @configuration ||= Configuration.new
    end

    # Bus API client (pcsdata.njtransit.com)
    def client
      @client ||= Client.new(**configuration.to_h)
    end

    # Rail API client (raildata.njtransit.com)
    def rail_client
      @rail_client ||= Client.new(
        **configuration.to_h, base_url: Configuration::DEFAULT_RAIL_BASE_URL,
                              auth_path: "/api/TrainData/getToken"
      )
    end

    def reset!
      @configuration = nil
      @client = nil
      @rail_client = nil
    end
  end
end

require_relative "njtransit/railtie" if defined?(Rails::Railtie)
