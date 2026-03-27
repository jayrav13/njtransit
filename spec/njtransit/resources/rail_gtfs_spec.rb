# frozen_string_literal: true

RSpec.describe NJTransit::Resources::RailGTFS do
  let(:client) { instance_double(NJTransit::Client, token: "test_token") }
  let(:rail_gtfs) { described_class.new(client) }

  before do
    allow(client).to receive(:post_form_raw).and_return("binary_data")
  end

  it "fetches schedule data" do
    rail_gtfs.schedule_data
    expect(client).to have_received(:post_form_raw).with("/api/GTFSRT/getGTFS")
  end

  it "fetches alerts" do
    rail_gtfs.alerts
    expect(client).to have_received(:post_form_raw).with("/api/GTFSRT/getAlerts")
  end

  it "fetches trip updates" do
    rail_gtfs.trip_updates
    expect(client).to have_received(:post_form_raw).with("/api/GTFSRT/getTripUpdates")
  end

  it "fetches vehicle positions" do
    rail_gtfs.vehicle_positions
    expect(client).to have_received(:post_form_raw).with("/api/GTFSRT/getVehiclePositions")
  end
end
