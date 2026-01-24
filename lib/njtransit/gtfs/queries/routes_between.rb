# frozen_string_literal: true

module NJTransit
  module GTFS
    module Queries
      class RoutesBetween
        attr_reader :db, :from, :to

        def initialize(db, from:, to:)
          @db = db
          @from = from
          @to = to
        end

        def call
          from_stop_id = resolve_stop_id(from)
          to_stop_id = resolve_stop_id(to)

          return [] if from_stop_id.nil? || to_stop_id.nil?

          route_ids = find_common_route_ids(from_stop_id, to_stop_id)
          return [] if route_ids.empty?

          route_short_names(route_ids)
        end

        private

        def find_common_route_ids(from_stop_id, to_stop_id)
          common_trips = find_common_trips(from_stop_id, to_stop_id)
          return [] if common_trips.empty?

          db[:trips].where(trip_id: common_trips).select_map(:route_id).uniq
        end

        def find_common_trips(from_stop_id, to_stop_id)
          from_trips = trips_at_stop(from_stop_id)
          to_trips = trips_at_stop(to_stop_id)
          from_trips & to_trips
        end

        def trips_at_stop(stop_id)
          db[:stop_times].where(stop_id: stop_id).select_map(:trip_id)
        end

        def route_short_names(route_ids)
          db[:routes].where(route_id: route_ids).select_map(:route_short_name).uniq
        end

        def resolve_stop_id(identifier)
          # Try as stop_id first
          stop = db[:stops].where(stop_id: identifier).first
          return identifier if stop

          # Try as stop_code
          stop = db[:stops].where(stop_code: identifier).first
          stop&.dig(:stop_id)
        end
      end
    end
  end
end
