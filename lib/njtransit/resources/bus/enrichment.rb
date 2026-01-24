# frozen_string_literal: true

module NJTransit
  module Resources
    # GTFS enrichment for Bus API responses
    module BusEnrichment
      private

      def ensure_gtfs_available!
        gtfs
      end

      def gtfs
        @gtfs ||= GTFS.new
      end

      def enrich_stops(stops)
        return stops unless stops.is_a?(Array)

        stops.each { |stop| enrich_stop_record(stop) }
      end

      def enrich_stop_record(stop)
        stop_code = stop["stop_id"] || stop[:stop_id]
        return unless stop_code

        gtfs_stop = gtfs.stops.find_by_code(stop_code.to_s)
        return unless gtfs_stop

        stop["stop_lat"] = gtfs_stop.lat
        stop["stop_lon"] = gtfs_stop.lon
        stop["zone_id"] = gtfs_stop.zone_id
      end

      def enrich_stop_name(result, stop_number)
        gtfs_stop = gtfs.stops.find_by_code(stop_number.to_s)
        return result unless gtfs_stop

        if result.is_a?(Hash)
          result["stop_lat"] = gtfs_stop.lat
          result["stop_lon"] = gtfs_stop.lon
        end
        result
      end

      def enrich_departures(departures)
        return departures unless departures.is_a?(Array)

        departures.each { |dep| enrich_departure_record(dep) }
      end

      def enrich_departure_record(dep)
        enrich_departure_stop(dep)
        enrich_departure_route(dep)
      end

      def enrich_departure_stop(dep)
        stop_code = dep["stop_id"] || dep[:stop_id]
        return unless stop_code

        gtfs_stop = gtfs.stops.find_by_code(stop_code.to_s)
        return unless gtfs_stop

        dep["stop_lat"] = gtfs_stop.lat
        dep["stop_lon"] = gtfs_stop.lon
      end

      def enrich_departure_route(dep)
        route_name = dep["route"] || dep[:route]
        return unless route_name

        gtfs_route = gtfs.routes.find(route_name.to_s)
        dep["route_long_name"] = gtfs_route.long_name if gtfs_route
      end

      def enrich_stops_nearby(stops)
        return stops unless stops.is_a?(Array)

        stops.each { |stop| enrich_stop_zone(stop) }
      end

      def enrich_stop_zone(stop)
        stop_code = stop["stop_id"] || stop[:stop_id]
        return unless stop_code

        gtfs_stop = gtfs.stops.find_by_code(stop_code.to_s)
        stop["zone_id"] = gtfs_stop.zone_id if gtfs_stop
      end

      def enrich_vehicles(vehicles)
        return vehicles unless vehicles.is_a?(Array)

        vehicles.each { |vehicle| enrich_vehicle_route(vehicle) }
      end

      def enrich_vehicle_route(vehicle)
        route_name = vehicle["route"] || vehicle[:route]
        return unless route_name

        gtfs_route = gtfs.routes.find(route_name.to_s)
        vehicle["route_long_name"] = gtfs_route.long_name if gtfs_route
      end
    end
  end
end
