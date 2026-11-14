# frozen_string_literal: true

RSpec.describe NJTransit::Client do
  let(:client) { described_class.new(username: "test_user", password: "test_pass") }

  before { described_class.default_token_store.clear }

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

    context "when rate limited" do
      before do
        body = '{"errorMessage":"Daily usage limit:10. Your current daily usage: 11"}'
        response = instance_double(Faraday::Response, success?: true, body: body)
        allow(connection).to receive(:post).and_yield(double(body: nil).as_null_object).and_return(response)
      end

      it "raises AuthenticationError with the API error message" do
        expect { client.authenticate! }.to raise_error(
          NJTransit::AuthenticationError,
          "Daily usage limit:10. Your current daily usage: 11"
        )
      end
    end

    context "when token is cached" do
      before do
        allow(connection).to receive(:post).and_yield(double(body: nil).as_null_object).and_return(success_response)
        client.authenticate!
      end

      it "reuses cached token for new client with same base_url" do
        new_client = described_class.new(username: "test_user", password: "test_pass")
        allow(new_client).to receive(:form_connection).and_return(connection)

        new_client.authenticate!

        expect(connection).to have_received(:post).once
        expect(new_client.token).to eq("abc123")
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

    it "deletes the token from the store" do
      store = NJTransit::TokenStores::Memory.new
      client = described_class.new(username: "test_user", password: "test_pass", token_store: store)
      store.write(client.token_key, "cached_token")
      client.clear_token!
      expect(store.read(client.token_key)).to be_nil
    end
  end

  describe "token store" do
    let(:store) { NJTransit::TokenStores::Memory.new }
    let(:connection) { instance_double(Faraday::Connection) }
    let(:auth_response) do
      instance_double(Faraday::Response, success?: true, body: '{"Authenticated": "True", "UserToken": "fresh"}')
    end

    def build_client(**opts)
      described_class.new(username: "test_user", password: "test_pass", token_store: store, **opts).tap do |c|
        allow(c).to receive(:form_connection).and_return(connection)
      end
    end

    before do
      allow(connection).to receive(:post).and_yield(double(body: nil).as_null_object).and_return(auth_response)
    end

    it "uses the shared in-process memory store by default" do
      client = described_class.new(username: "u", password: "p")
      expect(client.token_store).to be(described_class.default_token_store)
    end

    it "writes a new token to the store" do
      client = build_client
      client.authenticate!
      expect(store.read(client.token_key)).to eq("fresh")
    end

    it "reuses a stored token without calling the auth endpoint" do
      client = build_client
      store.write(client.token_key, "persisted")

      expect(client.token).to eq("persisted")
      expect(connection).not_to have_received(:post)
    end

    it "keys tokens by host and username" do
      bus = build_client
      rail = build_client(base_url: "https://raildata.njtransit.com")
      other_user = described_class.new(username: "someone_else", password: "p", token_store: store)

      expect([bus.token_key, rail.token_key, other_user.token_key].uniq.size).to eq(3)
    end

    it "authenticates when the store fails to read" do
      allow(store).to receive(:read).and_raise(IOError, "cache down")
      expect(build_client.token).to eq("fresh")
    end

    it "keeps the token in memory when the store fails to write" do
      allow(store).to receive(:write).and_raise(IOError, "cache down")
      expect(build_client.token).to eq("fresh")
    end

    it "accepts any object with read, write and delete (e.g. Rails.cache)" do
      cache = Class.new do
        def initialize = @data = {}
        def read(key) = @data[key]
        def write(key, value, **) = @data[key] = value
        def delete(key) = @data.delete(key)
      end.new

      client = described_class.new(username: "u", password: "p", token_store: cache)
      cache.write(client.token_key, "from_cache")
      expect(client.token).to eq("from_cache")
    end
  end

  describe ".token_cache (deprecated)" do
    it "still exposes the default store's tokens, with a warning" do
      client = described_class.new(username: "u", password: "p")
      described_class.default_token_store.write(client.token_key, "abc")
      expect { expect(described_class.token_cache).to eq(client.token_key => "abc") }
        .to output(/deprecated/).to_stderr
    end
  end

  describe "#post_form_raw with an expired stored token" do
    let(:store) { NJTransit::TokenStores::Memory.new }
    let(:client) { described_class.new(username: "test_user", password: "test_pass", token_store: store) }
    let(:sent_tokens) { [] }

    def response(body)
      instance_double(Faraday::Response, success?: true, status: 200, body: body)
    end

    before do
      store.write(client.token_key, "stale")
      raw_connection = instance_double(Faraday::Connection)
      form_connection = instance_double(Faraday::Connection)
      allow(client).to receive_messages(raw_connection: raw_connection, form_connection: form_connection)
      allow(form_connection).to receive(:post).and_yield(double(body: nil).as_null_object)
                                              .and_return(response('{"Authenticated": "True", "UserToken": "fresh"}'))
      responses = [response('{"errorMessage":"Invalid token."}'), response("\x0A\x0Dprotobuf")]
      allow(raw_connection).to receive(:post) do |&block|
        req = double(url: nil)
        allow(req).to receive(:body=) { |params| sent_tokens << params[:token] }
        block.call(req)
        responses.shift
      end
    end

    it "replaces the stale token and retries once" do
      expect(client.post_form_raw("/api/GTFSRT/getTripUpdates")).to eq("\x0A\x0Dprotobuf")
      expect(sent_tokens).to eq(%w[stale fresh])
      expect(store.read(client.token_key)).to eq("fresh")
    end
  end
end
