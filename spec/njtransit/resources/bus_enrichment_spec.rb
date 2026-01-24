# frozen_string_literal: true

require "fileutils"

RSpec.describe "Bus API Enrichment" do
  let(:test_db_path) { "tmp/test_enrichment.sqlite3" }
  let(:client) { instance_double(NJTransit::Client) }
  let(:bus) { NJTransit::Resources::Bus.new(client) }

  before do
    FileUtils.mkdir_p("tmp")
    FileUtils.rm_f(test_db_path)
    allow(NJTransit.configuration).to receive(:gtfs_database_path).and_return(test_db_path)
    NJTransit::GTFS.import("spec/fixtures/gtfs")
    allow(client).to receive(:token).and_return("test_token")
  end

  after do
    NJTransit::GTFS::Database.disconnect
    FileUtils.rm_f(test_db_path)
  end

  describe "#stops with enrichment" do
    let(:api_response) do
      [
        { "stop_id" => "WBRK", "stop_name" => "WILLOWBROOK" },
        { "stop_id" => "PABT", "stop_name" => "PORT AUTHORITY" }
      ]
    end

    before do
      allow(client).to receive(:post_form).and_return(api_response)
    end

    it "adds lat/lon from GTFS by default" do
      result = bus.stops(route: "197", direction: "New York")
      expect(result.first["stop_lat"]).to eq(40.8523)
      expect(result.first["stop_lon"]).to eq(-74.2567)
    end

    it "skips enrichment when enrich: false" do
      result = bus.stops(route: "197", direction: "New York", enrich: false)
      expect(result.first).not_to have_key("stop_lat")
    end
  end

  describe "#departures with enrichment" do
    let(:api_response) do
      [
        { "stop_id" => "WBRK", "route" => "197" }
      ]
    end

    before do
      allow(client).to receive(:post_form).and_return(api_response)
    end

    it "adds stop coordinates and route name" do
      result = bus.departures(stop: "WBRK")
      expect(result.first["stop_lat"]).to eq(40.8523)
      expect(result.first["route_long_name"]).to eq("Willowbrook - Port Authority")
    end
  end

  describe "when GTFS not imported" do
    before do
      NJTransit::GTFS.clear!
      NJTransit::GTFS::Database.disconnect
      FileUtils.rm_f(test_db_path)
    end

    it "raises GTFSNotImportedError for enriched calls" do
      expect do
        bus.stops(route: "197", direction: "New York")
      end.to raise_error(NJTransit::GTFSNotImportedError)
    end

    it "succeeds with enrich: false" do
      allow(client).to receive(:post_form).and_return([])
      expect do
        bus.stops(route: "197", direction: "New York", enrich: false)
      end.not_to raise_error
    end
  end
end
