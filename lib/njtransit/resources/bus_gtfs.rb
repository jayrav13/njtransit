# frozen_string_literal: true

module NJTransit
  module Resources
    class BusGTFS < Base
      DEFAULT_PREFIX = "/api/GTFS"

      def initialize(client, api_prefix: DEFAULT_PREFIX)
        super(client)
        @api_prefix = api_prefix
      end

      # Returns GTFS static schedule data as ZIP binary
      def schedule_data
        client.post_form_raw("#{@api_prefix}/getGTFS")
      end

      # Returns GTFS-RT alerts as protobuf binary
      def alerts
        client.post_form_raw("#{@api_prefix}/getAlerts")
      end

      # Returns GTFS-RT trip updates as protobuf binary
      def trip_updates
        client.post_form_raw("#{@api_prefix}/getTripUpdates")
      end

      # Returns GTFS-RT vehicle positions as protobuf binary
      def vehicle_positions
        client.post_form_raw("#{@api_prefix}/getVehiclePositions")
      end
    end
  end
end
