# frozen_string_literal: true

require "faraday"
require "faraday/typhoeus"
require "json"

module NJTransit
  class Client
    attr_reader :api_key, :log_level, :base_url, :timeout

    def initialize(api_key:, log_level: "silent", base_url: Configuration::DEFAULT_BASE_URL, timeout: Configuration::DEFAULT_TIMEOUT)
      @api_key = api_key
      @log_level = log_level
      @base_url = base_url
      @timeout = timeout
    end

    def get(path, params = {})
      request(:get, path, params)
    end

    def post(path, body = {})
      request(:post, path, body)
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

    private

    def request(method, path, params_or_body = {})
      response = connection.public_send(method) do |req|
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

    def connection
      @connection ||= Faraday.new(url: base_url) do |f|
        f.request :json
        f.response :logger, logger, { headers: log_headers?, bodies: log_bodies? } if logging_enabled?
        f.adapter :typhoeus
        f.options.timeout = timeout
        f.options.open_timeout = timeout
        f.headers["Content-Type"] = "application/json"
        f.headers["Accept"] = "application/json"
        configure_auth(f)
      end
    end

    def configure_auth(faraday)
      # TODO: Configure authentication based on NJTransit API requirements
      # This will be updated once we review the API documentation
      faraday.headers["Authorization"] = "Bearer #{api_key}" if api_key
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
        parsed["error"] || parsed["message"] || response.body
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
