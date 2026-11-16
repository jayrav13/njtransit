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

  describe "shared store, concurrent expiry" do
    let(:store) { NJTransit::TokenStores::Memory.new }
    let(:connection) { instance_double(Faraday::Connection) }
    let(:clients) do
      Array.new(2) do
        described_class.new(username: "u", password: "p", token_store: store).tap do |c|
          allow(c).to receive(:form_connection).and_return(connection)
        end
      end
    end

    before do
      auth = instance_double(Faraday::Response, success?: true, body: '{"Authenticated": "True", "UserToken": "fresh"}')
      allow(connection).to receive(:post).and_yield(double(body: nil).as_null_object).and_return(auth)
      store.write(clients.first.token_key, "stale")
      clients.each(&:token) # both now hold "stale"
    end

    it "does not delete a fresh token another client stored, so one expiry costs one auth call" do
      a, b = clients
      a.clear_token!
      a.token
      b.clear_token!

      expect(b.token).to eq("fresh")
      expect(connection).to have_received(:post).once
    end
  end

  describe "token store validation and failures" do
    it "rejects a store without read, write and delete" do
      expect { described_class.new(username: "u", password: "p", token_store: "tokens.json") }
        .to raise_error(ArgumentError, /token_store/)
    end

    it "warns on stderr when the store fails, even with logging silent" do
      store = NJTransit::TokenStores::Memory.new
      allow(store).to receive(:read).and_raise(IOError, "disk gone")
      client = described_class.new(username: "u", password: "p", token_store: store)
      allow(client).to receive(:authenticate!) { client.send(:read_stored_token) }

      expect { client.token }.to output(/token store read failed: IOError: disk gone/).to_stderr
    end
  end

  describe "#post_form_raw with an expired stored token" do
    let(:store) { NJTransit::TokenStores::Memory.new }
    let(:client) { described_class.new(username: "test_user", password: "test_pass", token_store: store) }
    let(:sent_tokens) { [] }
    let(:raw_responses) { [response('{"errorMessage":"Invalid token."}'), response("\x0A\x0Dprotobuf")] }

    def response(body, status: 200)
      instance_double(Faraday::Response, success?: status == 200, status: status, body: body)
    end

    before do
      store.write(client.token_key, "stale")
      raw_connection = instance_double(Faraday::Connection)
      form_connection = instance_double(Faraday::Connection)
      allow(client).to receive_messages(raw_connection: raw_connection, form_connection: form_connection)
      allow(form_connection).to receive(:post).and_yield(double(body: nil).as_null_object)
                                              .and_return(response('{"Authenticated": "True", "UserToken": "fresh"}'))
      allow(raw_connection).to receive(:post) do |&block|
        req = double(url: nil)
        allow(req).to receive(:body=) { |params| sent_tokens << params[:token] }
        block.call(req)
        raw_responses.shift
      end
    end

    it "replaces the stale token and retries once" do
      expect(client.post_form_raw("/api/GTFSRT/getTripUpdates")).to eq("\x0A\x0Dprotobuf")
      expect(sent_tokens).to eq(%w[stale fresh])
      expect(store.read(client.token_key)).to eq("fresh")
    end

    context "when the bus feed rejects the token with an HTTP 500" do
      let(:raw_responses) do
        [response('{"errorMessage":"Invalid Token. Please authenticate user."}', status: 500),
         response("\x0A\x0Dprotobuf")]
      end

      it "replaces the stale token and retries once" do
        expect(client.post_form_raw("/api/GTFS/getTripUpdates")).to eq("\x0A\x0Dprotobuf")
        expect(sent_tokens).to eq(%w[stale fresh])
      end
    end

    context "when the rail feed rejects the token with an HTTP 500 twice" do
      let(:raw_responses) { Array.new(2) { response('{"errorMessage":"Invalid token."}', status: 500) } }

      it "raises after one retry" do
        expect { client.post_form_raw("/api/GTFSRT/getTripUpdates") }
          .to raise_error(NJTransit::InternalServerError, "Invalid token.")
        expect(sent_tokens).to eq(%w[stale fresh])
      end
    end

    context "when a 500 is not about the token" do
      let(:raw_responses) { [response('{"errorMessage":"Something broke"}', status: 500)] }

      it "raises without re-authenticating" do
        expect { client.post_form_raw("/api/GTFS/getTripUpdates") }
          .to raise_error(NJTransit::InternalServerError, "Something broke")
        expect(sent_tokens).to eq(%w[stale])
      end
    end

    context "when the expired token comes back as a 401" do
      let(:raw_responses) { [response("Unauthorized", status: 401), response("\x0A\x0Dprotobuf")] }

      it "replaces the stale token and retries once" do
        expect(client.post_form_raw("/api/GTFSRT/getTripUpdates")).to eq("\x0A\x0Dprotobuf")
        expect(store.read(client.token_key)).to eq("fresh")
      end
    end

    context "when the retry still gets a JSON error" do
      let(:raw_responses) { Array.new(2) { response('{"errorMessage":"Invalid token."}') } }

      it "raises instead of returning the JSON as feed bytes" do
        expect { client.post_form_raw("/api/GTFSRT/getTripUpdates") }
          .to raise_error(NJTransit::APIError, "Invalid token.")
      end
    end

    context "when the API returns a non-token JSON error" do
      let(:raw_responses) { [response('{"errorMessage":"Daily usage limit:10"}')] }

      it "raises without re-authenticating" do
        expect { client.post_form_raw("/api/GTFSRT/getTripUpdates") }
          .to raise_error(NJTransit::APIError, "Daily usage limit:10")
        expect(sent_tokens).to eq(%w[stale])
      end
    end
  end

  describe "GTFS-RT auth endpoints" do
    let(:store) { NJTransit::TokenStores::Memory.new }
    let(:bus) { described_class.new(username: "u", password: "p", token_store: store, timeout: 7, log_level: "info") }
    let(:rail) do
      described_class.new(username: "u", password: "p", token_store: store,
                          base_url: "https://raildata.njtransit.com", auth_path: "/api/TrainData/getToken")
    end

    it "authenticates each feed API at its own endpoint" do
      expect([bus.bus_gtfs.client.auth_path, bus.bus_gtfs_g2.client.auth_path, rail.rail_gtfs.client.auth_path])
        .to eq(%w[/api/GTFS/authenticateUser /api/GTFSG2/authenticateUser /api/GTFSRT/getToken])
    end

    it "keeps the JSON APIs on their own endpoints" do
      expect([bus.bus.client.auth_path, rail.rail.client.auth_path])
        .to eq(%w[/api/BUSDV2/authenticateUser /api/TrainData/getToken])
    end

    it "gives every API its own token key" do
      keys = [bus.token_key, bus.bus_gtfs.client.token_key, bus.bus_gtfs_g2.client.token_key,
              rail.token_key, rail.rail_gtfs.client.token_key]
      expect(keys.uniq.size).to eq(5)
    end

    it "shares the parent's credentials, host, timeout, logging and token store" do
      feed = bus.bus_gtfs.client
      expect([feed.username, feed.password, feed.base_url, feed.timeout, feed.log_level, feed.token_store])
        .to eq(["u", "p", bus.base_url, 7, "info", store])
    end

    it "keys tokens by host, auth endpoint and username" do
      expect(bus.token_key).to eq("njtransit:token:https://pcsdata.njtransit.com/api/BUSDV2/authenticateUser:u")
    end
  end

  describe "#post_form with a token rejected as HTTP 500" do
    let(:client) { described_class.new(username: "u", password: "p", token_store: NJTransit::TokenStores::Memory.new) }
    let(:auth_calls) { [] }
    let(:sent_tokens) { [] }

    def response(body, status: 200)
      instance_double(Faraday::Response, success?: status == 200, status: status, body: body)
    end

    before do
      connection = instance_double(Faraday::Connection)
      allow(client).to receive(:form_connection).and_return(connection)
      queue = [response('{"errorMessage":"Invalid Token. Please authenticate user."}', status: 500),
               response('{"Authenticated": "True", "UserToken": "fresh"}'),
               response('[{"ok": true}]')]
      allow(connection).to receive(:post) do |path = nil, &block|
        req = double(url: nil)
        allow(req).to receive(:body=) { |params| sent_tokens << params[:token] unless path }
        auth_calls << path if path
        block&.call(req)
        queue.shift
      end
    end

    it "re-authenticates and retries once with the fresh token" do
      expect(client.post_form("/api/BUSDV2/getRoutes", token: "stale")).to eq([{ "ok" => true }])
      expect(auth_calls).to eq(["/api/BUSDV2/authenticateUser"])
      expect(sent_tokens).to eq(%w[stale fresh])
    end
  end

  # Plain-Ruby fakes (no rspec doubles) so they are safe to call from many threads.
  describe "concurrent token rejection on one client" do
    let(:store) { NJTransit::TokenStores::Memory.new }
    let(:client) { described_class.new(username: "u", password: "p", token_store: store) }
    let(:lock) { Mutex.new }
    let(:mints) { [] }
    let(:sent) { [] }

    def thread_count = 5

    def response(status, body)
      Struct.new(:status, :body, :success?).new(status, body, status == 200)
    end

    # Holds each request that sent the stale token until every thread has sent it, so all are rejected together.
    def latch
      waiting = 0
      cond = ConditionVariable.new
      lambda do
        lock.synchronize do
          waiting += 1
          cond.broadcast if waiting >= thread_count
          cond.wait(lock, 1) while waiting < thread_count
        end
      end
    end

    # Answers the auth endpoint (mint) and every request: the stale token is rejected, any other gets `success`.
    def fake_connection(success)
      wait = latch
      fake = Struct.new(:auth_path, :body) { def url(_path) = nil }
      spec = self
      Object.new.tap do |conn|
        conn.define_singleton_method(:post) do |auth_path = nil, &block|
          req = fake.new(auth_path)
          block.call(req)
          auth_path ? spec.mint : spec.answer(req.body[:token], success, wait)
        end
      end
    end

    def answer(token, success, wait)
      lock.synchronize { sent << token }
      return success unless token == "stale"

      wait.call
      response(500, '{"errorMessage":"Invalid token."}')
    end

    def mint
      count = lock.synchronize { mints << :mint }.size
      sleep 0.05 # widen the window in which other threads also handle their rejection
      response(200, %({"Authenticated": "True", "UserToken": "fresh#{count}"}))
    end

    def run_threads(&)
      Array.new(thread_count) { Thread.new(&) }.map(&:value)
    end

    before { store.write(client.token_key, "stale") }

    context "with GTFS-RT feeds (the raw path)" do
      before do
        conn = fake_connection(response(200, "\x0A\x0Dprotobuf"))
        client.define_singleton_method(:form_connection) { conn }
        client.define_singleton_method(:raw_connection) { conn }
      end

      it "mints exactly one token and retries every request with it" do
        results = run_threads { client.post_form_raw("/api/GTFSRT/getTripUpdates") }

        expect(results).to all(eq("\x0A\x0Dprotobuf"))
        expect(mints.size).to eq(1)
        expect(sent.tally).to eq("stale" => thread_count, "fresh1" => thread_count)
        expect(store.read(client.token_key)).to eq("fresh1")
      end
    end

    context "with JSON form requests" do
      before do
        conn = fake_connection(response(200, '[{"ok": true}]'))
        client.define_singleton_method(:form_connection) { conn }
      end

      it "mints exactly one token and retries every request with it" do
        results = run_threads { client.post_form("/api/BUSDV2/getRoutes", token: client.token) }

        expect(results).to all(eq([{ "ok" => true }]))
        expect(mints.size).to eq(1)
        expect(sent.tally).to eq("stale" => thread_count, "fresh1" => thread_count)
      end
    end
  end

  describe "a rejected token that was already replaced" do
    let(:store) { NJTransit::TokenStores::Memory.new }
    let(:client) { described_class.new(username: "u", password: "p", token_store: store) }
    let(:sent_tokens) { [] }
    let(:form_connection) { instance_double(Faraday::Connection) }

    def response(body, status: 200)
      instance_double(Faraday::Response, success?: status == 200, status: status, body: body)
    end

    # The first request is rejected; `on_reject` simulates what other threads or clients did meanwhile.
    def stub_feed(&on_reject)
      raw_connection = instance_double(Faraday::Connection)
      allow(client).to receive_messages(raw_connection: raw_connection, form_connection: form_connection)
      allow(form_connection).to receive(:post)
      allow(raw_connection).to receive(:post) { |&block| feed_response(block, on_reject) }
    end

    def feed_response(block, on_reject)
      req = double(url: nil)
      allow(req).to receive(:body=) { |params| sent_tokens << params[:token] }
      block.call(req)
      return response("\x0A\x0Dprotobuf") if sent_tokens.size > 1

      on_reject.call
      response('{"errorMessage":"Invalid token."}', status: 500)
    end

    before do
      store.write(client.token_key, "stale")
      client.token
    end

    it "retries with the token another thread on this client minted, without minting or deleting it" do
      stub_feed do
        client.instance_variable_set(:@token, "fresh")
        store.write(client.token_key, "fresh")
      end

      expect(client.post_form_raw("/api/GTFSRT/getTripUpdates")).to eq("\x0A\x0Dprotobuf")
      expect(sent_tokens).to eq(%w[stale fresh])
      expect(form_connection).not_to have_received(:post)
      expect(store.read(client.token_key)).to eq("fresh")
    end

    it "adopts a newer token another client stored, without minting or deleting it" do
      stub_feed { store.write(client.token_key, "from_elsewhere") }

      expect(client.post_form_raw("/api/GTFSRT/getTripUpdates")).to eq("\x0A\x0Dprotobuf")
      expect(sent_tokens).to eq(%w[stale from_elsewhere])
      expect(form_connection).not_to have_received(:post)
      expect(store.read(client.token_key)).to eq("from_elsewhere")
    end
  end

  describe "#api_client under concurrent first use" do
    it "returns one shared client per auth path" do
      parent = described_class.new(username: "u", password: "p")
      allow(described_class).to receive(:new).and_wrap_original do |original, **kwargs|
        sleep 0.02
        original.call(**kwargs)
      end

      clients = Array.new(5) { Thread.new { parent.api_client(described_class::GTFS_G2_AUTH_PATH) } }.map(&:value)
      expect(clients.uniq(&:object_id).size).to eq(1)
    end
  end
end
