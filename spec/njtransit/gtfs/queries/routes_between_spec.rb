# frozen_string_literal: true

require "fileutils"

RSpec.describe NJTransit::GTFS::Queries::RoutesBetween do
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
    it "finds routes serving both stops" do
      query = described_class.new(db, from: "WBRK", to: "PABT")
      routes = query.call
      expect(routes).to include("197")
    end

    it "returns empty array when no routes connect stops" do
      query = described_class.new(db, from: "21681", to: "21682")
      routes = query.call
      expect(routes).to be_empty
    end

    it "accepts stop_id or stop_code" do
      query = described_class.new(db, from: "1", to: "2")
      routes = query.call
      expect(routes).to include("197")
    end
  end
end
