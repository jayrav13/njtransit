# frozen_string_literal: true

require "sequel"
require "fileutils"

module NJTransit
  module GTFS
    # Database module for managing GTFS SQLite storage
    module Database
      class << self
        def connection(path = nil)
          @path = path if path
          @connection ||= begin
            FileUtils.mkdir_p(File.dirname(@path))
            Sequel.sqlite(@path)
          end
        end

        def disconnect
          @connection&.disconnect
          @connection = nil
        end

        def exists?(path)
          return false unless File.exist?(path)

          db = Sequel.sqlite(path)
          db.table_exists?(:agencies) && db.table_exists?(:stops)
        rescue StandardError
          false
        ensure
          db&.disconnect
        end

        def setup_schema!
          create_agencies_table
          create_routes_table
          create_stops_table
          create_trips_table
          create_stop_times_table
          create_calendar_dates_table
          create_shapes_table
          create_import_metadata_table
        end

        def clear!
          db = connection
          %i[agencies routes stops trips stop_times calendar_dates shapes import_metadata].each do |table|
            db.drop_table?(table)
          end
        end

        private

        def create_agencies_table
          connection.create_table?(:agencies) do
            String :agency_id, primary_key: true
            String :agency_name
            String :agency_url
            String :agency_timezone
          end
        end

        def create_routes_table
          connection.create_table?(:routes) do
            String :route_id, primary_key: true
            String :agency_id
            String :route_short_name
            String :route_long_name
            Integer :route_type
            String :route_color
            index :route_short_name
          end
        end

        def create_stops_table
          connection.create_table?(:stops) do
            String :stop_id, primary_key: true
            String :stop_code
            String :stop_name
            Float :stop_lat
            Float :stop_lon
            String :zone_id
            index :stop_code
          end
        end

        def create_trips_table
          connection.create_table?(:trips) do
            String :trip_id, primary_key: true
            String :route_id
            String :service_id
            String :trip_headsign
            Integer :direction_id
            String :shape_id
            index :route_id
            index :service_id
          end
        end

        def create_stop_times_table
          connection.create_table?(:stop_times) do
            primary_key :id
            String :trip_id
            String :stop_id
            String :arrival_time
            String :departure_time
            Integer :stop_sequence
            index :trip_id
            index :stop_id
          end
        end

        def create_calendar_dates_table
          connection.create_table?(:calendar_dates) do
            primary_key :id
            String :service_id
            String :date
            Integer :exception_type
            index %i[service_id date]
          end
        end

        def create_shapes_table
          connection.create_table?(:shapes) do
            primary_key :id
            String :shape_id
            Float :shape_pt_lat
            Float :shape_pt_lon
            Integer :shape_pt_sequence
            index :shape_id
          end
        end

        def create_import_metadata_table
          connection.create_table?(:import_metadata) do
            primary_key :id
            DateTime :imported_at
            String :source_path
          end
        end
      end
    end
  end
end
