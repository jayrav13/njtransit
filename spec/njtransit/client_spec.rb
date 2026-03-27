# frozen_string_literal: true

RSpec.describe NJTransit::Client do
  let(:client) { described_class.new(username: "test_user", password: "test_pass") }

  describe "#initialize" do
    it "sets username" do
      expect(client.username).to eq("test_user")
    end

    it "sets password" do
      expect(client.password).to eq("test_pass")
    end

    it "sets default base_url" do
      expect(client.base_url).to eq("https://pcsdata.njtransit.com")
    end

    it "sets default timeout" do
      expect(client.timeout).to eq(30)
    end

    it "sets default log_level" do
      expect(client.log_level).to eq("silent")
    end
  end

  describe "#bus" do
    it "returns a Bus resource" do
      expect(client.bus).to be_a(NJTransit::Resources::Bus)
    end

    it "memoizes the Bus resource" do
      expect(client.bus).to be(client.bus)
    end
  end

  describe "#rail" do
    it "returns a Rail resource" do
      expect(client.rail).to be_a(NJTransit::Resources::Rail)
    end
  end

  describe "#bus_gtfs" do
    it "returns a BusGTFS resource" do
      expect(client.bus_gtfs).to be_a(NJTransit::Resources::BusGTFS)
    end
  end

  describe "#bus_gtfs_g2" do
    it "returns a BusGTFS resource with G2 prefix" do
      expect(client.bus_gtfs_g2).to be_a(NJTransit::Resources::BusGTFS)
    end
  end

  describe "#rail_gtfs" do
    it "returns a RailGTFS resource" do
      expect(client.rail_gtfs).to be_a(NJTransit::Resources::RailGTFS)
    end
  end

  describe "#authenticate!" do
    let(:success_response) do
      instance_double(Faraday::Response, success?: true, body: '{"Authenticated": "True", "UserToken": "abc123"}')
    end

    let(:failure_response) do
      instance_double(Faraday::Response, success?: true, body: '{"Authenticated": "False", "UserToken": ""}')
    end

    let(:connection) { instance_double(Faraday::Connection) }

    before do
      allow(client).to receive(:form_connection).and_return(connection)
    end

    context "when authentication succeeds" do
      before do
        allow(connection).to receive(:post).and_yield(double(body: nil).as_null_object).and_return(success_response)
      end

      it "sets the token" do
        client.authenticate!
        expect(client.token).to eq("abc123")
      end
    end

    context "when authentication fails" do
      before do
        allow(connection).to receive(:post).and_yield(double(body: nil).as_null_object).and_return(failure_response)
      end

      it "raises AuthenticationError" do
        expect { client.authenticate! }.to raise_error(NJTransit::AuthenticationError, "Authentication failed")
      end
    end
  end

  describe "#token" do
    it "calls authenticate! if token is nil" do
      allow(client).to receive(:authenticate!)
      client.token
      expect(client).to have_received(:authenticate!)
    end
  end

  describe "#clear_token!" do
    it "clears the cached token" do
      client.instance_variable_set(:@token, "existing_token")
      client.clear_token!
      expect(client.instance_variable_get(:@token)).to be_nil
    end
  end
end
