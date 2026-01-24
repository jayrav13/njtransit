# frozen_string_literal: true

require "rake"

namespace :njtransit do
  namespace :gtfs do
    desc "Import GTFS data from specified path"
    task :import, [:path] do |_t, args|
      require "njtransit"

      path = args[:path]
      if path.nil? || path.empty?
        detected = NJTransit::GTFS.detect_gtfs_path
        if detected
          puts "No path specified. Detected GTFS data at: #{detected}"
          print "Use this path? [Y/n] "
          response = $stdin.gets&.strip&.downcase
          path = detected if response.nil? || response.empty? || response == "y"
        end
      end

      if path.nil? || path.empty?
        puts "Usage: rake njtransit:gtfs:import[/path/to/gtfs/data]"
        exit 1
      end

      puts "Importing GTFS data from #{path}..."
      NJTransit::GTFS.import(path, force: ENV["FORCE"] == "true")
      status = NJTransit::GTFS.status
      puts "Import complete!"
      puts "  Routes: #{status[:routes]}"
      puts "  Stops: #{status[:stops]}"
      puts "  Trips: #{status[:trips]}"
      puts "  Stop times: #{status[:stop_times]}"
      puts "  Database: #{status[:path]}"
    end

    desc "Show GTFS import status"
    task :status do
      require "njtransit"

      status = NJTransit::GTFS.status
      if status[:imported]
        puts "GTFS Status: Imported"
        puts "  Database: #{status[:path]}"
        puts "  Routes: #{status[:routes]}"
        puts "  Stops: #{status[:stops]}"
        puts "  Trips: #{status[:trips]}"
        puts "  Stop times: #{status[:stop_times]}"
        puts "  Imported at: #{status[:imported_at]}"
        puts "  Source: #{status[:source_path]}"
      else
        puts "GTFS Status: Not imported"
        puts "  Database path: #{status[:path]}"
        detected = NJTransit::GTFS.detect_gtfs_path
        puts "  Detected GTFS data: #{detected}" if detected
      end
    end

    desc "Clear GTFS database"
    task :clear do
      require "njtransit"

      print "Are you sure you want to clear the GTFS database? [y/N] "
      response = $stdin.gets&.strip&.downcase
      if response == "y"
        NJTransit::GTFS.clear!
        puts "GTFS database cleared."
      else
        puts "Cancelled."
      end
    end
  end
end
