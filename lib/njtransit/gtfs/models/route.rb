# frozen_string_literal: true

module NJTransit
  module GTFS
    module Models
      class Route
        class << self
          attr_accessor :db

          def all
            db[:routes].all.map { |row| new(row) }
          end

          def find(identifier)
            row = db[:routes].where(route_id: identifier).first
            row ||= db[:routes].where(route_short_name: identifier).first
            row ? new(row) : nil
          end

          def where(conditions)
            db[:routes].where(conditions).all.map { |row| new(row) }
          end
        end

        attr_reader :route_id, :agency_id, :route_short_name, :route_long_name, :route_type, :route_color

        def initialize(attributes)
          @route_id = attributes[:route_id]
          @agency_id = attributes[:agency_id]
          @route_short_name = attributes[:route_short_name]
          @route_long_name = attributes[:route_long_name]
          @route_type = attributes[:route_type]
          @route_color = attributes[:route_color]
        end

        def short_name
          route_short_name
        end

        def long_name
          route_long_name
        end

        def to_h
          {
            route_id: route_id,
            agency_id: agency_id,
            route_short_name: route_short_name,
            route_long_name: route_long_name,
            short_name: short_name,
            long_name: long_name,
            route_type: route_type,
            route_color: route_color
          }
        end
      end
    end
  end
end
