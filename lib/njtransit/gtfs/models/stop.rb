# frozen_string_literal: true

module NJTransit
  module GTFS
    module Models
      class Stop
        class << self
          attr_accessor :db

          def all
            db[:stops].all.map { |row| new(row) }
          end

          def find(stop_id)
            row = db[:stops].where(stop_id: stop_id).first
            row ? new(row) : nil
          end

          def find_by_code(stop_code)
            row = db[:stops].where(stop_code: stop_code).first
            row ? new(row) : nil
          end

          def where(conditions)
            db[:stops].where(conditions).all.map { |row| new(row) }
          end
        end

        attr_reader :stop_id, :stop_code, :stop_name, :stop_lat, :stop_lon, :zone_id

        def initialize(attributes)
          @stop_id = attributes[:stop_id]
          @stop_code = attributes[:stop_code]
          @stop_name = attributes[:stop_name]
          @stop_lat = attributes[:stop_lat]
          @stop_lon = attributes[:stop_lon]
          @zone_id = attributes[:zone_id]
        end

        def lat
          stop_lat
        end

        def lon
          stop_lon
        end

        def to_h
          {
            stop_id: stop_id,
            stop_code: stop_code,
            stop_name: stop_name,
            stop_lat: stop_lat,
            stop_lon: stop_lon,
            lat: lat,
            lon: lon,
            zone_id: zone_id
          }
        end
      end
    end
  end
end
