# frozen_string_literal: true

RSpec.describe NJTransit::Resources::Bus do
  let(:client) { instance_double(NJTransit::Client, token: "test_token") }
  let(:bus) { described_class.new(client) }

  before do
    allow(client).to receive(:post_form).and_return([])
  end

  describe "#locations" do
    it "calls the correct endpoint with mode" do
      bus.locations
      expect(client).to have_received(:post_form).with(
        "/api/BUSDV2/getLocations",
        { token: "test_token", mode: "BUS" }
      )
    end
  end

  describe "#routes" do
    it "calls the correct endpoint with mode" do
      bus.routes
      expect(client).to have_received(:post_form).with(
        "/api/BUSDV2/getBusRoutes",
        { token: "test_token", mode: "BUS" }
      )
    end
  end

  describe "#directions" do
    it "calls the correct endpoint with route" do
      bus.directions(route: "1")
      expect(client).to have_received(:post_form).with(
        "/api/BUSDV2/getBusDirectionsData",
        { token: "test_token", route: "1" }
      )
    end
  end

  describe "#stops" do
    it "calls the correct endpoint with required params" do
      bus.stops(route: "1", direction: "Newark", enrich: false)
      expect(client).to have_received(:post_form).with(
        "/api/BUSDV2/getStops",
        { token: "test_token", route: "1", direction: "Newark" }
      )
    end

    it "includes name_contains when provided" do
      bus.stops(route: "1", direction: "Newark", name_contains: "BROAD", enrich: false)
      expect(client).to have_received(:post_form).with(
        "/api/BUSDV2/getStops",
        { token: "test_token", route: "1", direction: "Newark", namecontains: "BROAD" }
      )
    end
  end

  describe "#stop_name" do
    it "calls the correct endpoint with stop_number" do
      bus.stop_name(stop_number: "19159", enrich: false)
      expect(client).to have_received(:post_form).with(
        "/api/BUSDV2/getStopName",
        { token: "test_token", stopnum: "19159" }
      )
    end
  end

  describe "#route_trips" do
    it "calls the correct endpoint with location and route" do
      bus.route_trips(location: "PABT", route: "113")
      expect(client).to have_received(:post_form).with(
        "/api/BUSDV2/getRouteTrips",
        { token: "test_token", location: "PABT", route: "113" }
      )
    end
  end

  describe "#departures" do
    it "calls the correct endpoint with stop" do
      bus.departures(stop: "PABT", enrich: false)
      expect(client).to have_received(:post_form).with(
        "/api/BUSDV2/getBusDV",
        { token: "test_token", stop: "PABT" }
      )
    end

    it "includes optional route and direction" do
      bus.departures(stop: "PABT", route: "164", direction: "Newark", enrich: false)
      expect(client).to have_received(:post_form).with(
        "/api/BUSDV2/getBusDV",
        { token: "test_token", stop: "PABT", route: "164", direction: "Newark" }
      )
    end
  end

  describe "#trip_stops" do
    it "calls the correct endpoint with required params" do
      bus.trip_stops(internal_trip_number: "19624134", sched_dep_time: "6/22/2023 12:50:00 AM")
      expect(client).to have_received(:post_form).with(
        "/api/BUSDV2/getTripStops",
        { token: "test_token", internal_trip_number: "19624134", sched_dep_time: "6/22/2023 12:50:00 AM" }
      )
    end

    it "includes optional timing_point_id" do
      bus.trip_stops(internal_trip_number: "19624134", sched_dep_time: "6/22/2023 12:50:00 AM", timing_point_id: "NWYKPABT")
      expect(client).to have_received(:post_form).with(
        "/api/BUSDV2/getTripStops",
        { token: "test_token", internal_trip_number: "19624134", sched_dep_time: "6/22/2023 12:50:00 AM", timing_point_id: "NWYKPABT" }
      )
    end
  end

  describe "#stops_nearby" do
    it "calls the correct endpoint with location params" do
      bus.stops_nearby(lat: 40.737, lon: -74.170, radius: 2000, enrich: false)
      expect(client).to have_received(:post_form).with(
        "/api/BUSDV2/getBusLocationsData",
        { token: "test_token", lat: 40.737, lon: -74.170, radius: 2000, mode: "BUS" }
      )
    end

    it "includes optional route and direction" do
      bus.stops_nearby(lat: 40.737, lon: -74.170, radius: 2000, route: "1", direction: "Newark", enrich: false)
      expect(client).to have_received(:post_form).with(
        "/api/BUSDV2/getBusLocationsData",
        { token: "test_token", lat: 40.737, lon: -74.170, radius: 2000, mode: "BUS", route: "1", direction: "Newark" }
      )
    end
  end

  describe "#vehicles_nearby" do
    it "calls the correct endpoint with location params" do
      bus.vehicles_nearby(lat: 40.737, lon: -74.170, radius: 2000, enrich: false)
      expect(client).to have_received(:post_form).with(
        "/api/BUSDV2/getVehicleLocations",
        { token: "test_token", lat: 40.737, lon: -74.170, radius: 2000, mode: "BUS" }
      )
    end
  end
end
