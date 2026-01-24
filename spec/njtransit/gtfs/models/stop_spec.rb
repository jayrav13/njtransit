# frozen_string_literal: true

require "fileutils"

RSpec.describe NJTransit::GTFS::Models::Stop do
  let(:fixtures_path) { "spec/fixtures/gtfs" }
  let(:test_db_path) { "tmp/test_models.sqlite3" }

  before(:all) do
    FileUtils.mkdir_p("tmp")
    FileUtils.rm_f("tmp/test_models.sqlite3")
    NJTransit::GTFS::Importer.new("spec/fixtures/gtfs", "tmp/test_models.sqlite3").import
  end

  after(:all) do
    NJTransit::GTFS::Database.disconnect
    FileUtils.rm_f("tmp/test_models.sqlite3")
  end

  before do
    described_class.db = NJTransit::GTFS::Database.connection(test_db_path)
  end

  describe ".all" do
    it "returns all stops" do
      stops = described_class.all
      expect(stops.count).to eq(5)
    end
  end

  describe ".find" do
    it "finds stop by stop_id" do
      stop = described_class.find("1")
      expect(stop.stop_code).to eq("WBRK")
    end

    it "returns nil when not found" do
      stop = described_class.find("nonexistent")
      expect(stop).to be_nil
    end
  end

  describe ".find_by_code" do
    it "finds stop by stop_code" do
      stop = described_class.find_by_code("WBRK")
      expect(stop.stop_name).to eq("WILLOWBROOK MALL")
    end

    it "returns nil when not found" do
      stop = described_class.find_by_code("XXXXX")
      expect(stop).to be_nil
    end
  end

  describe ".where" do
    it "filters by attributes" do
      stops = described_class.where(zone_id: "NB")
      expect(stops.count).to eq(2)
    end
  end

  describe "instance methods" do
    let(:stop) { described_class.find_by_code("WBRK") }

    it "has lat accessor" do
      expect(stop.lat).to eq(40.8523)
    end

    it "has lon accessor" do
      expect(stop.lon).to eq(-74.2567)
    end

    it "converts to hash" do
      hash = stop.to_h
      expect(hash[:stop_id]).to eq("1")
      expect(hash[:stop_code]).to eq("WBRK")
      expect(hash[:lat]).to eq(40.8523)
      expect(hash[:lon]).to eq(-74.2567)
    end
  end
end
