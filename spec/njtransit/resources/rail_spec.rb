# frozen_string_literal: true

RSpec.describe NJTransit::Resources::Rail do
  let(:client) { instance_double(NJTransit::Client, token: "test_token") }
  let(:rail) { described_class.new(client) }

  before do
    allow(client).to receive(:post_form).and_return([])
  end

  describe "#stations" do
    it "calls the correct endpoint" do
      rail.stations
      expect(client).to have_received(:post_form).with(
        "/api/TrainData/getStationList",
        { token: "test_token" }
      )
    end
  end

  describe "#station_messages" do
    it "calls with station code" do
      rail.station_messages(station: "NP")
      expect(client).to have_received(:post_form).with(
        "/api/TrainData/getStationMSG",
        { token: "test_token", station: "NP", line: "" }
      )
    end

    it "calls with line code" do
      rail.station_messages(line: "NE")
      expect(client).to have_received(:post_form).with(
        "/api/TrainData/getStationMSG",
        { token: "test_token", station: "", line: "NE" }
      )
    end
  end

  describe "#station_schedule" do
    it "calls with station code" do
      rail.station_schedule(station: "NP")
      expect(client).to have_received(:post_form).with(
        "/api/TrainData/getStationSchedule",
        { token: "test_token", station: "NP", NJT_Only: "1" }
      )
    end
  end

  describe "#train_schedule" do
    it "calls with station code" do
      rail.train_schedule(station: "NP")
      expect(client).to have_received(:post_form).with(
        "/api/TrainData/getTrainSchedule",
        { token: "test_token", station: "NP", NJT_Only: "1" }
      )
    end
  end

  describe "#train_schedule_19" do
    it "calls with station code" do
      rail.train_schedule_19(station: "NP")
      expect(client).to have_received(:post_form).with(
        "/api/TrainData/getTrainSchedule19Rec",
        { token: "test_token", station: "NP", NJT_Only: "1" }
      )
    end
  end

  describe "#train_stop_list" do
    it "calls with train ID" do
      rail.train_stop_list(train_id: "3837")
      expect(client).to have_received(:post_form).with(
        "/api/TrainData/getTrainStopList",
        { token: "test_token", trainID: "3837" }
      )
    end
  end

  describe "#vehicle_data" do
    it "calls the correct endpoint" do
      rail.vehicle_data
      expect(client).to have_received(:post_form).with(
        "/api/TrainData/getVehicleData",
        { token: "test_token" }
      )
    end
  end
end
