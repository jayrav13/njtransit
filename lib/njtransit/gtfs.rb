# frozen_string_literal: true

require_relative "gtfs/database"
require_relative "gtfs/importer"
require_relative "gtfs/models/stop"
require_relative "gtfs/models/route"
require_relative "gtfs/queries/routes_between"
require_relative "gtfs/queries/schedule"

module NJTransit
  module GTFS
    SEARCH_PATHS = [
      "./bus_data",
      "./vendor/bus_data",
      "./docs/api/njtransit/bus_data"
    ].freeze

    class << self
      def import(source_path, force: false)
        importer = Importer.new(source_path, database_path)
        validate_gtfs_directory!(importer, source_path)
        importer.import(force: force)
      end

      def status
        path = database_path
        return { imported: false, path: path } unless Database.exists?(path)

        build_status_hash(path)
      end

      def new
        path = database_path

        unless Database.exists?(path)
          detected = detect_gtfs_path
          raise GTFSNotImportedError.new(detected_path: detected)
        end

        QueryInterface.new(path)
      end

      def detect_gtfs_path
        SEARCH_PATHS.find do |path|
          File.directory?(path) && File.exist?(File.join(path, "agency.txt"))
        end
      end

      def clear!
        Database.connection(database_path)
        Database.clear!
        Database.disconnect
        FileUtils.rm_f(database_path)
      end

      private

      def database_path
        NJTransit.configuration.gtfs_database_path
      end

      def validate_gtfs_directory!(importer, source_path)
        return if importer.valid_gtfs_directory?

        raise NJTransit::Error, "Invalid GTFS directory: #{source_path}. Must contain agency.txt, routes.txt, stops.txt"
      end

      def build_status_hash(path)
        Database.connection(path)
        db = Database.connection

        { imported: true, path: path }.merge(table_counts(db)).merge(metadata_info(db))
      end

      def table_counts(db)
        { routes: db[:routes].count, stops: db[:stops].count,
          trips: db[:trips].count, stop_times: db[:stop_times].count }
      end

      def metadata_info(db)
        metadata = db[:import_metadata].order(Sequel.desc(:id)).first
        { imported_at: metadata&.dig(:imported_at), source_path: metadata&.dig(:source_path) }
      end
    end

    class QueryInterface
      attr_reader :db

      def initialize(db_path)
        Database.connection(db_path)
        @db = Database.connection
        setup_models
      end

      def stops
        Models::Stop
      end

      def routes
        Models::Route
      end

      def routes_between(from:, to:)
        Queries::RoutesBetween.new(db, from: from, to: to).call
      end

      def schedule(route:, stop:, date:)
        Queries::Schedule.new(db, route: route, stop: stop, date: date).call
      end

      private

      def setup_models
        Models::Stop.db = db
        Models::Route.db = db
      end
    end
  end
end
