# frozen_string_literal: true

require "fileutils"

RSpec.describe NJTransit::GTFS do
  let(:fixtures_path) { "spec/fixtures/gtfs" }
  let(:test_db_path) { "tmp/test_gtfs_main.sqlite3" }

  before do
    FileUtils.mkdir_p("tmp")
    FileUtils.rm_f(test_db_path)
    allow(NJTransit.configuration).to receive(:gtfs_database_path).and_return(test_db_path)
  end

  after do
    NJTransit::GTFS::Database.disconnect
    FileUtils.rm_f(test_db_path)
  end

  describe ".import" do
    it "imports GTFS data" do
      described_class.import(fixtures_path)
      expect(NJTransit::GTFS::Database.exists?(test_db_path)).to be true
    end

    it "raises error for invalid directory" do
      expect do
        described_class.import("/nonexistent")
      end.to raise_error(NJTransit::Error, /Invalid GTFS directory/)
    end
  end

  describe ".status" do
    context "when not imported" do
      it "returns imported: false" do
        status = described_class.status
        expect(status[:imported]).to be false
      end
    end

    context "when imported" do
      before { described_class.import(fixtures_path) }

      it "returns imported: true" do
        status = described_class.status
        expect(status[:imported]).to be true
      end

      it "returns record counts" do
        status = described_class.status
        expect(status[:routes]).to eq(3)
        expect(status[:stops]).to eq(5)
      end
    end
  end

  describe ".new" do
    context "when GTFS imported" do
      before { described_class.import(fixtures_path) }

      it "returns a query interface" do
        gtfs = described_class.new
        expect(gtfs).to be_a(NJTransit::GTFS::QueryInterface)
      end
    end

    context "when GTFS not imported" do
      it "raises GTFSNotImportedError" do
        expect do
          described_class.new
        end.to raise_error(NJTransit::GTFSNotImportedError)
      end
    end
  end

  describe ".detect_gtfs_path" do
    it "returns nil when no GTFS files found" do
      allow(File).to receive(:directory?).and_call_original
      allow(File).to receive(:exist?).and_call_original
      NJTransit::GTFS::SEARCH_PATHS.each do |path|
        allow(File).to receive(:directory?).with(path).and_return(false)
      end
      expect(described_class.detect_gtfs_path).to be_nil
    end

    it "returns path when GTFS files exist" do
      allow(File).to receive(:directory?).and_call_original
      allow(File).to receive(:exist?).and_call_original
      NJTransit::GTFS::SEARCH_PATHS.each do |path|
        allow(File).to receive(:directory?).with(path).and_return(false)
      end
      allow(File).to receive(:directory?).with("./docs/api/njtransit/bus_data").and_return(true)
      allow(File).to receive(:exist?).with("./docs/api/njtransit/bus_data/agency.txt").and_return(true)

      expect(described_class.detect_gtfs_path).to eq("./docs/api/njtransit/bus_data")
    end
  end
end

RSpec.describe NJTransit::GTFS::QueryInterface do
  let(:fixtures_path) { "spec/fixtures/gtfs" }
  let(:test_db_path) { "tmp/test_gtfs_query.sqlite3" }

  before do
    FileUtils.mkdir_p("tmp")
    FileUtils.rm_f(test_db_path)
    allow(NJTransit.configuration).to receive(:gtfs_database_path).and_return(test_db_path)
    NJTransit::GTFS.import(fixtures_path)
  end

  after do
    NJTransit::GTFS::Database.disconnect
    FileUtils.rm_f(test_db_path)
  end

  let(:gtfs) { NJTransit::GTFS.new }

  describe "#stops" do
    it "provides stop query methods" do
      expect(gtfs.stops.all.count).to eq(5)
    end

    it "finds by code" do
      stop = gtfs.stops.find_by_code("WBRK")
      expect(stop.stop_name).to eq("WILLOWBROOK MALL")
    end
  end

  describe "#routes" do
    it "provides route query methods" do
      expect(gtfs.routes.all.count).to eq(3)
    end
  end

  describe "#routes_between" do
    it "finds routes between two stops" do
      routes = gtfs.routes_between(from: "WBRK", to: "PABT")
      expect(routes).to include("197")
    end
  end

  describe "#schedule" do
    it "returns schedule for route/stop/date" do
      schedule = gtfs.schedule(route: "197", stop: "WBRK", date: Date.new(2026, 1, 24))
      expect(schedule).not_to be_empty
    end
  end
end
