# frozen_string_literal: true

RSpec.describe NJTransit::Resources::BusGTFS do
  let(:client) { instance_double(NJTransit::Client, token: "test_token") }

  before do
    allow(client).to receive(:post_form_raw).and_return("binary_data")
  end

  describe "with default prefix (V1)" do
    let(:bus_gtfs) { described_class.new(client) }

    it "fetches schedule data" do
      bus_gtfs.schedule_data
      expect(client).to have_received(:post_form_raw).with("/api/GTFS/getGTFS")
    end

    it "fetches alerts" do
      bus_gtfs.alerts
      expect(client).to have_received(:post_form_raw).with("/api/GTFS/getAlerts")
    end

    it "fetches trip updates" do
      bus_gtfs.trip_updates
      expect(client).to have_received(:post_form_raw).with("/api/GTFS/getTripUpdates")
    end

    it "fetches vehicle positions" do
      bus_gtfs.vehicle_positions
      expect(client).to have_received(:post_form_raw).with("/api/GTFS/getVehiclePositions")
    end
  end

  describe "with G2 prefix" do
    let(:bus_gtfs_g2) { described_class.new(client, api_prefix: "/api/GTFSG2") }

    it "fetches schedule data from G2 endpoint" do
      bus_gtfs_g2.schedule_data
      expect(client).to have_received(:post_form_raw).with("/api/GTFSG2/getGTFS")
    end

    it "fetches alerts from G2 endpoint" do
      bus_gtfs_g2.alerts
      expect(client).to have_received(:post_form_raw).with("/api/GTFSG2/getAlerts")
    end

    it "fetches trip updates from G2 endpoint" do
      bus_gtfs_g2.trip_updates
      expect(client).to have_received(:post_form_raw).with("/api/GTFSG2/getTripUpdates")
    end

    it "fetches vehicle positions from G2 endpoint" do
      bus_gtfs_g2.vehicle_positions
      expect(client).to have_received(:post_form_raw).with("/api/GTFSG2/getVehiclePositions")
    end
  end
end
