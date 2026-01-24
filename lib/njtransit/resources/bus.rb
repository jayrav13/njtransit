# frozen_string_literal: true

require_relative "bus/enrichment"

module NJTransit
  module Resources
    class Bus < Base
      include BusEnrichment

      MODE = "BUS"

      def locations
        post_form("/api/BUSDV2/getLocations", mode: MODE)
      end

      def routes
        post_form("/api/BUSDV2/getBusRoutes", mode: MODE)
      end

      def directions(route:)
        post_form("/api/BUSDV2/getBusDirectionsData", route: route)
      end

      def stops(route:, direction:, name_contains: nil, enrich: true)
        ensure_gtfs_available! if enrich
        params = { route: route, direction: direction }
        params[:namecontains] = name_contains if name_contains
        result = post_form("/api/BUSDV2/getStops", params)
        enrich ? enrich_stops(result) : result
      end

      def stop_name(stop_number:, enrich: true)
        ensure_gtfs_available! if enrich
        result = post_form("/api/BUSDV2/getStopName", stopnum: stop_number)
        enrich ? enrich_stop_name(result, stop_number) : result
      end

      def route_trips(location:, route:)
        post_form("/api/BUSDV2/getRouteTrips", location: location, route: route)
      end

      def departures(stop:, route: nil, direction: nil, enrich: true)
        ensure_gtfs_available! if enrich
        params = { stop: stop }
        params[:route] = route if route
        params[:direction] = direction if direction
        result = post_form("/api/BUSDV2/getBusDV", params)
        enrich ? enrich_departures(result) : result
      end

      def trip_stops(internal_trip_number:, sched_dep_time:, timing_point_id: nil)
        params = {
          internal_trip_number: internal_trip_number,
          sched_dep_time: sched_dep_time
        }
        params[:timing_point_id] = timing_point_id if timing_point_id
        post_form("/api/BUSDV2/getTripStops", params)
      end

      def stops_nearby(lat:, lon:, radius:, enrich: true, **options)
        ensure_gtfs_available! if enrich
        params = { lat: lat, lon: lon, radius: radius, mode: MODE }
        params[:route] = options[:route] if options[:route]
        params[:direction] = options[:direction] if options[:direction]
        result = post_form("/api/BUSDV2/getBusLocationsData", params)
        enrich ? enrich_stops_nearby(result) : result
      end

      def vehicles_nearby(lat:, lon:, radius:, enrich: true)
        ensure_gtfs_available! if enrich
        result = post_form("/api/BUSDV2/getVehicleLocations", lat: lat, lon: lon, radius: radius, mode: MODE)
        enrich ? enrich_vehicles(result) : result
      end

      private

      def post_form(path, params = {})
        params[:token] = client.token
        client.post_form(path, params)
      end
    end
  end
end
