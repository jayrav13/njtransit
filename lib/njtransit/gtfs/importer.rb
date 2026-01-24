# frozen_string_literal: true

require "csv"

module NJTransit
  module GTFS
    class Importer
      REQUIRED_FILES = %w[agency.txt routes.txt stops.txt].freeze
      OPTIONAL_FILES = %w[trips.txt stop_times.txt calendar_dates.txt shapes.txt].freeze

      # Table configurations: [filename, table, batch_size, field_mapper]
      TABLE_CONFIGS = {
        agencies: ["agency.txt", 1000, ->(r) { agency_fields(r) }],
        routes: ["routes.txt", 1000, ->(r) { route_fields(r) }],
        stops: ["stops.txt", 1000, ->(r) { stop_fields(r) }],
        trips: ["trips.txt", 1000, ->(r) { trip_fields(r) }],
        stop_times: ["stop_times.txt", 10_000, ->(r) { stop_time_fields(r) }],
        calendar_dates: ["calendar_dates.txt", 1000, ->(r) { calendar_date_fields(r) }],
        shapes: ["shapes.txt", 50_000, ->(r) { shape_fields(r) }]
      }.freeze

      attr_reader :source_path, :db_path

      def initialize(source_path, db_path)
        @source_path = source_path
        @db_path = db_path
      end

      def import(force: false)
        validate_can_import!(force)
        prepare_database(force)
        import_all_tables
        record_metadata
      end

      def valid_gtfs_directory?
        return false unless File.directory?(source_path)

        REQUIRED_FILES.all? { |f| File.exist?(File.join(source_path, f)) }
      end

      class << self
        def agency_fields(row)
          { agency_id: row["agency_id"], agency_name: row["agency_name"],
            agency_url: row["agency_url"], agency_timezone: row["agency_timezone"] }
        end

        def route_fields(row)
          { route_id: row["route_id"], agency_id: row["agency_id"], route_short_name: row["route_short_name"],
            route_long_name: row["route_long_name"], route_type: row["route_type"]&.to_i, route_color: row["route_color"] }
        end

        def stop_fields(row)
          { stop_id: row["stop_id"], stop_code: row["stop_code"], stop_name: row["stop_name"],
            stop_lat: row["stop_lat"]&.to_f, stop_lon: row["stop_lon"]&.to_f, zone_id: row["zone_id"] }
        end

        def trip_fields(row)
          { trip_id: row["trip_id"], route_id: row["route_id"], service_id: row["service_id"],
            trip_headsign: row["trip_headsign"], direction_id: row["direction_id"]&.to_i, shape_id: row["shape_id"] }
        end

        def stop_time_fields(row)
          { trip_id: row["trip_id"], stop_id: row["stop_id"], arrival_time: row["arrival_time"],
            departure_time: row["departure_time"], stop_sequence: row["stop_sequence"]&.to_i }
        end

        def calendar_date_fields(row)
          { service_id: row["service_id"], date: row["date"], exception_type: row["exception_type"]&.to_i }
        end

        def shape_fields(row)
          { shape_id: row["shape_id"], shape_pt_lat: row["shape_pt_lat"]&.to_f,
            shape_pt_lon: row["shape_pt_lon"]&.to_f, shape_pt_sequence: row["shape_pt_sequence"]&.to_i }
        end
      end

      private

      def validate_can_import!(force)
        return unless Database.exists?(db_path) && !force

        raise NJTransit::Error, "GTFS database already exists at #{db_path}. Use force: true to reimport."
      end

      def prepare_database(force)
        Database.disconnect
        FileUtils.rm_f(db_path) if force
        Database.connection(db_path)
        Database.setup_schema!
      end

      def import_all_tables
        TABLE_CONFIGS.each do |table, (filename, batch_size, mapper)|
          import_csv(filename, table, batch_size: batch_size, &mapper)
        end
      end

      def import_csv(filename, table, batch_size: 1000)
        path = File.join(source_path, filename)
        return unless File.exist?(path)

        batch = []
        CSV.foreach(path, headers: true) do |row|
          batch << yield(row)
          flush_batch(table, batch) if batch.size >= batch_size
        end
        flush_batch(table, batch)
      end

      def flush_batch(table, batch)
        return if batch.empty?

        Database.connection[table].multi_insert(batch)
        batch.clear
      end

      def record_metadata
        Database.connection[:import_metadata].insert(imported_at: Time.now, source_path: source_path)
      end
    end
  end
end
