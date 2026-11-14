# frozen_string_literal: true

require "faraday"
require "faraday/typhoeus"
require "faraday/multipart"
require "json"

require_relative "resources/base"
require_relative "resources/bus"
require_relative "resources/rail"
require_relative "resources/bus_gtfs"
require_relative "resources/rail_gtfs"

module NJTransit
  class Client
    DEFAULT_AUTH_PATH = "/api/BUSDV2/authenticateUser"

    # Each GTFS-RT API issues its own tokens; a bus or rail API token is rejected there.
    GTFS_AUTH_PATH = "/api/GTFS/authenticateUser"
    GTFS_G2_AUTH_PATH = "/api/GTFSG2/authenticateUser"
    RAIL_GTFS_AUTH_PATH = "/api/GTFSRT/getToken"

    attr_reader :username, :password, :log_level, :base_url, :timeout, :auth_path, :token_store

    def initialize(username:, password:, log_level: "silent", base_url: Configuration::DEFAULT_BASE_URL,
                   timeout: Configuration::DEFAULT_TIMEOUT, auth_path: DEFAULT_AUTH_PATH, token_store: nil)
      @username = username
      @token_store = token_store ? TokenStores.validate!(token_store) : self.class.default_token_store
      @password = password
      @log_level = log_level
      @base_url = base_url
      @timeout = timeout
      @auth_path = auth_path
      @token = nil
    end

    def bus
      @bus ||= Resources::Bus.new(self)
    end

    def rail
      @rail ||= Resources::Rail.new(self)
    end

    def bus_gtfs
      @bus_gtfs ||= Resources::BusGTFS.new(api_client(GTFS_AUTH_PATH))
    end

    def bus_gtfs_g2
      @bus_gtfs_g2 ||= Resources::BusGTFS.new(api_client(GTFS_G2_AUTH_PATH), api_prefix: "/api/GTFSG2")
    end

    def rail_gtfs
      @rail_gtfs ||= Resources::RailGTFS.new(api_client(RAIL_GTFS_AUTH_PATH))
    end

    def get(path, params = {})
      request(:get, path, params)
    end

    def post(path, body = {})
      request(:post, path, body)
    end

    def post_form(path, params = {})
      request_form(:post, path, params)
    end

    def put(path, body = {})
      request(:put, path, body)
    end

    def patch(path, body = {})
      request(:patch, path, body)
    end

    def delete(path, params = {})
      request(:delete, path, params)
    end

    def post_form_raw(path, params = {})
      request_form_raw(:post, path, params)
    end

    def authenticate!
      cached = read_stored_token
      if cached
        @token = cached
        return @token
      end

      response = form_connection.post(auth_path) do |req|
        req.body = { username: username, password: password }
      end

      result = parse_body(response.body)

      unless result.is_a?(Hash) && result["Authenticated"] == "True"
        message = result.is_a?(Hash) && result["errorMessage"] ? result["errorMessage"] : "Authentication failed"
        raise AuthenticationError, message
      end

      @token = result["UserToken"]
      write_stored_token(@token)
      @token
    end

    def token
      authenticate! if @token.nil?
      @token
    end

    # Forget this client's token. The stored copy is deleted only if it is still the
    # token this client held, so a fresh token another client just stored survives.
    def clear_token!
      stale = @token
      @token = nil
      store_call(:delete, token_key) if stale.nil? || read_stored_token == stale
    end

    # Store key for this client's token: one per host, auth endpoint (i.e. API) and username.
    def token_key
      "njtransit:token:#{base_url}#{auth_path}:#{username}"
    end

    # A client for another API on this host (its own auth endpoint and token), sharing
    # this client's credentials, timeout, logging and token store.
    def api_client(api_auth_path)
      return self if api_auth_path == auth_path

      @api_clients ||= {}
      @api_clients[api_auth_path] ||= self.class.new(
        username: username, password: password, log_level: log_level, base_url: base_url,
        timeout: timeout, auth_path: api_auth_path, token_store: token_store
      )
    end

    def self.default_token_store
      @default_token_store ||= TokenStores::Memory.new
    end

    # Deprecated: use default_token_store, or configure a token_store.
    def self.token_cache
      warn "[njtransit] Client.token_cache is deprecated; use Client.default_token_store " \
           "or configure token_store. Keys are now \"njtransit:token:<base_url>:<username>\"."
      default_token_store.to_h
    end

    def self.clear_token_cache!
      default_token_store.clear
    end

    private

    def request(method, path, params_or_body = {})
      response = json_connection.public_send(method) do |req|
        req.url(path)
        if %i[get delete].include?(method)
          req.params = params_or_body
        else
          req.body = JSON.generate(params_or_body)
        end
      end

      handle_response(response)
    rescue Faraday::TimeoutError => e
      raise TimeoutError, e.message
    rescue Faraday::ConnectionFailed => e
      raise ConnectionError, e.message
    end

    def request_form(method, path, params = {}, retry_auth: true)
      response = form_connection.public_send(method) do |req|
        req.url(path)
        req.body = params
      end

      if retry_auth && auth_failure?(response)
        clear_token!
        authenticate!
        params[:token] = @token
        return request_form(method, path, params, retry_auth: false)
      end

      result = handle_response(response)
      check_api_error!(result)
      result
    rescue Faraday::TimeoutError => e
      raise TimeoutError, e.message
    rescue Faraday::ConnectionFailed => e
      raise ConnectionError, e.message
    end

    def request_form_raw(method, path, params = {}, retry_auth: true)
      params[:token] = token
      response = raw_connection.public_send(method) do |req|
        req.url(path)
        req.body = params
      end

      if retry_auth && auth_failure?(response)
        clear_token!
        return request_form_raw(method, path, params, retry_auth: false)
      end

      raise error_for_status(response.status).new(error_message(response), response: response) unless response.success?

      # Feeds are protobuf, which never starts with "{": a JSON body is an API error.
      check_api_error!(parse_body(response.body)) if json_body?(response.body)
      response.body
    rescue Faraday::TimeoutError => e
      raise TimeoutError, e.message
    rescue Faraday::ConnectionFailed => e
      raise ConnectionError, e.message
    end

    # A token NJ Transit rejected: a 401/403, or a JSON errorMessage about an invalid token at
    # any status. Both hosts answer HTTP 500, worded "Invalid token." (rail) or
    # "Invalid Token. Please authenticate user." (bus).
    def auth_failure?(response)
      return true if [401, 403].include?(response.status)
      return false unless json_body?(response.body)

      result = parse_body(response.body)
      result.is_a?(Hash) && result["errorMessage"].to_s.match?(/invalid token/i)
    end

    def json_body?(body)
      body.is_a?(String) && body.start_with?("{")
    end

    def read_stored_token
      store_call(:read, token_key)
    end

    def write_stored_token(token)
      store_call(:write, token_key, token)
    end

    # A broken store must not break requests: fall back to authenticating, but always
    # warn (whatever log_level is), since each fallback spends a capped token.
    def store_call(method, *)
      token_store.public_send(method, *)
    rescue StandardError => e
      warn "[njtransit] token store #{method} failed: #{e.class}: #{e.message}"
      nil
    end

    def check_api_error!(result)
      return unless result.is_a?(Hash) && result["errorMessage"]

      raise APIError, result["errorMessage"]
    end

    def json_connection
      @json_connection ||= Faraday.new(url: base_url) do |f|
        f.request :json
        f.response :logger, logger, { headers: log_headers?, bodies: log_bodies? } if logging_enabled?
        f.adapter :typhoeus
        f.options.timeout = timeout
        f.options.open_timeout = timeout
        f.headers["Content-Type"] = "application/json"
        f.headers["Accept"] = "application/json"
      end
    end

    def form_connection
      @form_connection ||= Faraday.new(url: base_url) do |f|
        f.request :multipart
        f.request :url_encoded
        f.response :logger, logger, { headers: log_headers?, bodies: log_bodies? } if logging_enabled?
        f.adapter :typhoeus
        f.options.timeout = timeout
        f.options.open_timeout = timeout
        f.headers["Accept"] = "text/plain"
      end
    end

    def raw_connection
      @raw_connection ||= Faraday.new(url: base_url) do |f|
        f.request :multipart
        f.request :url_encoded
        f.adapter :typhoeus
        f.options.timeout = timeout
        f.options.open_timeout = timeout
        f.headers["Accept"] = "*/*"
      end
    end

    def handle_response(response)
      return parse_body(response.body) if response.success?

      raise error_for_status(response.status).new(
        error_message(response),
        response: response
      )
    end

    def parse_body(body)
      return nil if body.nil? || body.empty?

      JSON.parse(body)
    rescue JSON::ParserError
      body
    end

    def error_message(response)
      parsed = parse_body(response.body)
      if parsed.is_a?(Hash)
        parsed["error"] || parsed["message"] || parsed["errorMessage"] || response.body
      else
        response.body
      end
    end

    def error_for_status(status)
      case status
      when 400 then BadRequestError
      when 401 then AuthenticationError
      when 403 then ForbiddenError
      when 404 then NotFoundError
      when 405 then MethodNotAllowedError
      when 409 then ConflictError
      when 410 then GoneError
      when 422 then UnprocessableEntityError
      when 429 then RateLimitError
      when 500 then InternalServerError
      when 502 then BadGatewayError
      when 503 then ServiceUnavailableError
      when 504 then GatewayTimeoutError
      when 400..499 then ClientError
      when 500..599 then ServerError
      else Error
      end
    end

    def logging_enabled?
      %w[info debug].include?(log_level)
    end

    def log_headers?
      log_level == "debug"
    end

    def log_bodies?
      log_level == "debug"
    end

    def logger
      @logger ||= Logger.new($stdout).tap do |log|
        log.level = log_level == "debug" ? Logger::DEBUG : Logger::INFO
        log.formatter = proc do |severity, _datetime, _progname, msg|
          "[NJTransit #{severity}] #{msg}\n"
        end
      end
    end
  end
end
