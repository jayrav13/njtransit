# frozen_string_literal: true

RSpec.describe NJTransit::GTFSNotImportedError do
  describe "#initialize" do
    it "includes the base message" do
      error = described_class.new
      expect(error.message).to include("GTFS data not found")
    end

    it "includes hint when gtfs_path is provided" do
      error = described_class.new(detected_path: "./bus_data")
      expect(error.message).to include("Detected GTFS files at: ./bus_data")
      expect(error.message).to include("rake njtransit:gtfs:import[./bus_data]")
    end

    it "excludes hint when no path detected" do
      error = described_class.new
      expect(error.message).not_to include("Detected GTFS files")
    end
  end

  it "inherits from NJTransit::Error" do
    expect(described_class.superclass).to eq(NJTransit::Error)
  end
end
