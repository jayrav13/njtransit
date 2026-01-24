# frozen_string_literal: true

require "fileutils"

RSpec.describe NJTransit::GTFS::Queries::Schedule do
  let(:test_db_path) { "tmp/test_queries.sqlite3" }

  before(:all) do
    FileUtils.mkdir_p("tmp")
    FileUtils.rm_f("tmp/test_queries.sqlite3")
    NJTransit::GTFS::Importer.new("spec/fixtures/gtfs", "tmp/test_queries.sqlite3").import
  end

  after(:all) do
    NJTransit::GTFS::Database.disconnect
    FileUtils.rm_f("tmp/test_queries.sqlite3")
  end

  let(:db) { NJTransit::GTFS::Database.connection(test_db_path) }

  describe "#call" do
    it "returns schedule for route at stop on date" do
      # Date 20260124 has service_id 1
      query = described_class.new(db, route: "197", stop: "WBRK", date: Date.new(2026, 1, 24))
      schedule = query.call
      expect(schedule).not_to be_empty
      expect(schedule.first).to have_key(:arrival_time)
      expect(schedule.first).to have_key(:departure_time)
      expect(schedule.first).to have_key(:trip_id)
    end

    it "returns empty array when no service on date" do
      query = described_class.new(db, route: "197", stop: "WBRK", date: Date.new(2026, 1, 20))
      schedule = query.call
      expect(schedule).to be_empty
    end

    it "orders by arrival time" do
      query = described_class.new(db, route: "197", stop: "WBRK", date: Date.new(2026, 1, 24))
      schedule = query.call
      times = schedule.map { |s| s[:arrival_time] }
      expect(times).to eq(times.sort)
    end
  end
end
