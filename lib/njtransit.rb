# frozen_string_literal: true

require_relative "njtransit/version"
require_relative "njtransit/configuration"
require_relative "njtransit/error"
require_relative "njtransit/client"
require_relative "njtransit/gtfs/database"
require_relative "njtransit/gtfs/importer"
require_relative "njtransit/gtfs/models/stop"
require_relative "njtransit/gtfs/models/route"
require_relative "njtransit/gtfs/queries/routes_between"

module NJTransit
  class << self
    def configure
      yield(configuration)
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def client
      @client ||= Client.new(**configuration.to_h)
    end

    def reset!
      @configuration = nil
      @client = nil
    end
  end
end
