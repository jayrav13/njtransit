# frozen_string_literal: true

module NJTransit
  module Resources
    class Bus < Base
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

      def stops(route:, direction:, name_contains: nil)
        params = { route: route, direction: direction }
        params[:namecontains] = name_contains if name_contains
        post_form("/api/BUSDV2/getStops", params)
      end

      def stop_name(stop_number:)
        post_form("/api/BUSDV2/getStopName", stopnum: stop_number)
      end

      def route_trips(location:, route:)
        post_form("/api/BUSDV2/getRouteTrips", location: location, route: route)
      end

      def departures(stop:, route: nil, direction: nil)
        params = { stop: stop }
        params[:route] = route if route
        params[:direction] = direction if direction
        post_form("/api/BUSDV2/getBusDV", params)
      end

      def trip_stops(internal_trip_number:, sched_dep_time:, timing_point_id: nil)
        params = {
          internal_trip_number: internal_trip_number,
          sched_dep_time: sched_dep_time
        }
        params[:timing_point_id] = timing_point_id if timing_point_id
        post_form("/api/BUSDV2/getTripStops", params)
      end

      def stops_nearby(lat:, lon:, radius:, route: nil, direction: nil)
        params = { lat: lat, lon: lon, radius: radius, mode: MODE }
        params[:route] = route if route
        params[:direction] = direction if direction
        post_form("/api/BUSDV2/getBusLocationsData", params)
      end

      def vehicles_nearby(lat:, lon:, radius:)
        post_form("/api/BUSDV2/getVehicleLocations", lat: lat, lon: lon, radius: radius, mode: MODE)
      end

      private

      def post_form(path, params = {})
        params[:token] = client.token
        client.post_form(path, params)
      end
    end
  end
end
