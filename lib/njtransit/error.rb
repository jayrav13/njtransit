# frozen_string_literal: true

module NJTransit
  class Error < StandardError
    attr_reader :response

    def initialize(message = nil, response: nil)
      @response = response
      super(message)
    end
  end

  # API-level errors (returned in response body)
  class APIError < Error; end

  # Client errors (4xx)
  class ClientError < Error; end
  class BadRequestError < ClientError; end        # 400
  class AuthenticationError < ClientError; end    # 401
  class ForbiddenError < ClientError; end         # 403
  class NotFoundError < ClientError; end          # 404
  class MethodNotAllowedError < ClientError; end  # 405
  class ConflictError < ClientError; end          # 409
  class GoneError < ClientError; end              # 410
  class UnprocessableEntityError < ClientError; end # 422
  class RateLimitError < ClientError; end # 429

  # Server errors (5xx)
  class ServerError < Error; end
  class InternalServerError < ServerError; end    # 500
  class BadGatewayError < ServerError; end        # 502
  class ServiceUnavailableError < ServerError; end # 503
  class GatewayTimeoutError < ServerError; end # 504

  # Connection issues
  class ConnectionError < Error; end
  class TimeoutError < ConnectionError; end

  # GTFS not imported
  class GTFSNotImportedError < Error
    def initialize(detected_path: nil)
      message = "GTFS data not found. Run: rake njtransit:gtfs:import[/path/to/bus_data]"
      if detected_path
        message += "\n\nDetected GTFS files at: #{detected_path}"
        message += "\nHint: rake njtransit:gtfs:import[#{detected_path}]"
      end
      super(message)
    end
  end
end
