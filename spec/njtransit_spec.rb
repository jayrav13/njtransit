# frozen_string_literal: true

RSpec.describe NJTransit do
  it "has a version number" do
    expect(NJTransit::VERSION).not_to be_nil
  end

  describe ".configure" do
    after { described_class.reset! }

    it "yields configuration" do
      expect { |b| described_class.configure(&b) }.to yield_with_args(NJTransit::Configuration)
    end

    it "allows setting username" do
      described_class.configure do |config|
        config.username = "test_user"
      end

      expect(described_class.configuration.username).to eq("test_user")
    end

    it "allows setting password" do
      described_class.configure do |config|
        config.password = "test_pass"
      end

      expect(described_class.configuration.password).to eq("test_pass")
    end

    it "allows setting log_level" do
      described_class.configure do |config|
        config.log_level = "debug"
      end

      expect(described_class.configuration.log_level).to eq("debug")
    end
  end

  describe ".client" do
    before do
      described_class.configure do |config|
        config.username = "test_user"
        config.password = "test_pass"
      end
    end

    after { described_class.reset! }

    it "returns a Client instance" do
      expect(described_class.client).to be_a(NJTransit::Client)
    end

    it "memoizes the client" do
      expect(described_class.client).to be(described_class.client)
    end
  end

  describe ".rail_client" do
    before do
      described_class.configure do |config|
        config.username = "test_user"
        config.password = "test_pass"
      end
    end

    after { described_class.reset! }

    it "returns a Client instance" do
      expect(described_class.rail_client).to be_a(NJTransit::Client)
    end

    it "uses the rail base URL" do
      expect(described_class.rail_client.base_url).to eq("https://raildata.njtransit.com")
    end

    it "uses the rail auth path" do
      expect(described_class.rail_client.auth_path).to eq("/api/TrainData/getToken")
    end

    it "memoizes the rail client" do
      expect(described_class.rail_client).to be(described_class.rail_client)
    end
  end

  describe ".reset!" do
    it "clears configuration and client" do
      described_class.configure { |c| c.username = "test" }
      original_config = described_class.configuration

      described_class.reset!

      expect(described_class.configuration).not_to be(original_config)
    end
  end
end
