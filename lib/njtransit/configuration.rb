# frozen_string_literal: true

module NJTransit
  class Configuration
    VALID_LOG_LEVELS = %w[silent info debug].freeze
    DEFAULT_BASE_URL = "https://pcsdata.njtransit.com"
    DEFAULT_TIMEOUT = 30

    attr_accessor :username, :password, :base_url, :timeout, :gtfs_database_path
    attr_reader :log_level

    def initialize
      @username = ENV.fetch("NJTRANSIT_USERNAME", nil)
      @password = ENV.fetch("NJTRANSIT_PASSWORD", nil)
      @log_level = ENV.fetch("NJTRANSIT_LOG_LEVEL", "silent")
      @base_url = ENV.fetch("NJTRANSIT_BASE_URL", DEFAULT_BASE_URL)
      @timeout = ENV.fetch("NJTRANSIT_TIMEOUT", DEFAULT_TIMEOUT).to_i
      @gtfs_database_path = ENV.fetch("NJTRANSIT_GTFS_DATABASE_PATH", nil) || default_gtfs_database_path
    end

    def log_level=(level)
      level = level.to_s.downcase
      unless VALID_LOG_LEVELS.include?(level)
        raise ArgumentError,
              "Invalid log level: #{level}. Valid levels: #{VALID_LOG_LEVELS.join(", ")}"
      end

      @log_level = level
    end

    def to_h
      {
        username: username,
        password: password,
        log_level: log_level,
        base_url: base_url,
        timeout: timeout
      }
    end

    private

    def default_gtfs_database_path
      base = ENV["XDG_DATA_HOME"] || File.expand_path("~/.local/share")
      File.join(base, "njtransit", "gtfs.sqlite3")
    end
  end
end
