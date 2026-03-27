# frozen_string_literal: true

module NJTransit
  module Resources
    class RailGTFS < Base
      # Returns Rail GTFS static schedule data as ZIP binary
      def schedule_data
        client.post_form_raw("/api/GTFSRT/getGTFS")
      end

      # Returns Rail GTFS-RT alerts as protobuf binary
      def alerts
        client.post_form_raw("/api/GTFSRT/getAlerts")
      end

      # Returns Rail GTFS-RT trip updates as protobuf binary
      def trip_updates
        client.post_form_raw("/api/GTFSRT/getTripUpdates")
      end

      # Returns Rail GTFS-RT vehicle positions as protobuf binary
      def vehicle_positions
        client.post_form_raw("/api/GTFSRT/getVehiclePositions")
      end
    end
  end
end
