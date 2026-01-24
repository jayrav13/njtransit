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

    it "allows setting api_key" do
      described_class.configure do |config|
        config.api_key = "test_key"
      end

      expect(described_class.configuration.api_key).to eq("test_key")
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
        config.api_key = "test_key"
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

  describe ".reset!" do
    it "clears configuration and client" do
      described_class.configure { |c| c.api_key = "test" }
      original_config = described_class.configuration

      described_class.reset!

      expect(described_class.configuration).not_to be(original_config)
    end
  end
end
