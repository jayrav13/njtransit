# frozen_string_literal: true

require "faraday"
require "faraday/typhoeus"
require "faraday/multipart"
require "json"

require_relative "resources/base"
require_relative "resources/bus"

module NJTransit
  class Client
    attr_reader :username, :password, :log_level, :base_url, :timeout

    def initialize(username:, password:, log_level: "silent", base_url: Configuration::DEFAULT_BASE_URL, timeout: Configuration::DEFAULT_TIMEOUT)
      @username = username
      @password = password
      @log_level = log_level
      @base_url = base_url
      @timeout = timeout
      @token = nil
    end

    def bus
      @bus ||= Resources::Bus.new(self)
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

    def authenticate!
      response = form_connection.post("/api/BUSDV2/authenticateUser") do |req|
        req.body = { username: username, password: password }
      end

      result = parse_body(response.body)

      raise AuthenticationError, "Authentication failed" unless result.is_a?(Hash) && result["Authenticated"] == "True"

      @token = result["UserToken"]
    end

    def token
      authenticate! if @token.nil?
      @token
    end

    def clear_token!
      @token = nil
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

      result = handle_response(response)

      if token_expired?(result) && retry_auth
        clear_token!
        authenticate!
        params[:token] = @token
        return request_form(method, path, params, retry_auth: false)
      end

      check_api_error!(result)
      result
    rescue Faraday::TimeoutError => e
      raise TimeoutError, e.message
    rescue Faraday::ConnectionFailed => e
      raise ConnectionError, e.message
    end

    def token_expired?(result)
      result.is_a?(Hash) && result["errorMessage"] == "Invalid token."
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
