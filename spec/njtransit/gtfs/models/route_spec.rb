# frozen_string_literal: true

require "fileutils"

RSpec.describe NJTransit::GTFS::Models::Route do
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
    it "returns all routes" do
      routes = described_class.all
      expect(routes.count).to eq(3)
    end
  end

  describe ".find" do
    it "finds route by route_id" do
      route = described_class.find("3")
      expect(route.route_short_name).to eq("197")
    end

    it "finds route by short_name" do
      route = described_class.find("197")
      expect(route.route_id).to eq("3")
    end

    it "returns nil when not found" do
      route = described_class.find("nonexistent")
      expect(route).to be_nil
    end
  end

  describe "instance methods" do
    let(:route) { described_class.find("197") }

    it "has short_name accessor" do
      expect(route.short_name).to eq("197")
    end

    it "has long_name accessor" do
      expect(route.long_name).to eq("Willowbrook - Port Authority")
    end

    it "converts to hash" do
      hash = route.to_h
      expect(hash[:route_id]).to eq("3")
      expect(hash[:short_name]).to eq("197")
    end
  end
end
