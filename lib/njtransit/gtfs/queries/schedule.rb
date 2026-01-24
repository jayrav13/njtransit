# frozen_string_literal: true

module NJTransit
  module GTFS
    module Queries
      class Schedule
        attr_reader :db, :route, :stop, :date

        def initialize(db, route:, stop:, date:)
          @db = db
          @route = route
          @stop = stop
          @date = date
        end

        def call
          route_id = resolve_route_id
          stop_id = resolve_stop_id
          service_ids = active_service_ids

          return [] if route_id.nil? || stop_id.nil? || service_ids.empty?

          trip_ids = find_trip_ids(route_id, service_ids)
          return [] if trip_ids.empty?

          fetch_stop_times(trip_ids, stop_id)
        end

        private

        def find_trip_ids(route_id, service_ids)
          db[:trips]
            .where(route_id: route_id, service_id: service_ids)
            .select_map(:trip_id)
        end

        def fetch_stop_times(trip_ids, stop_id)
          db[:stop_times]
            .where(trip_id: trip_ids, stop_id: stop_id)
            .order(:arrival_time)
            .all
            .map { |row| format_stop_time(row) }
        end

        def format_stop_time(row)
          {
            trip_id: row[:trip_id],
            arrival_time: row[:arrival_time],
            departure_time: row[:departure_time],
            stop_sequence: row[:stop_sequence]
          }
        end

        def resolve_route_id
          route_row = db[:routes].where(route_id: route).first
          route_row ||= db[:routes].where(route_short_name: route).first
          route_row&.dig(:route_id)
        end

        def resolve_stop_id
          stop_row = db[:stops].where(stop_id: stop).first
          stop_row ||= db[:stops].where(stop_code: stop).first
          stop_row&.dig(:stop_id)
        end

        def active_service_ids
          date_str = date.strftime("%Y%m%d")
          db[:calendar_dates]
            .where(date: date_str, exception_type: 1)
            .select_map(:service_id)
        end
      end
    end
  end
end
