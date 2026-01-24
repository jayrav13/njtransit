# frozen_string_literal: true

module NJTransit
  class Configuration
    VALID_LOG_LEVELS = %w[silent info debug].freeze
    DEFAULT_BASE_URL = "https://api.njtransit.com"
    DEFAULT_TIMEOUT = 30

    attr_accessor :api_key, :base_url, :timeout
    attr_reader :log_level

    def initialize
      @api_key = ENV.fetch("NJTRANSIT_API_KEY", nil)
      @log_level = ENV.fetch("NJTRANSIT_LOG_LEVEL", "silent")
      @base_url = ENV.fetch("NJTRANSIT_BASE_URL", DEFAULT_BASE_URL)
      @timeout = ENV.fetch("NJTRANSIT_TIMEOUT", DEFAULT_TIMEOUT).to_i
    end

    def log_level=(level)
      level = level.to_s.downcase
      unless VALID_LOG_LEVELS.include?(level)
        raise ArgumentError, "Invalid log level: #{level}. Valid levels: #{VALID_LOG_LEVELS.join(", ")}"
      end

      @log_level = level
    end

    def to_h
      {
        api_key: api_key,
        log_level: log_level,
        base_url: base_url,
        timeout: timeout
      }
    end
  end
end
