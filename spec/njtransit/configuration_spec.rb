# frozen_string_literal: true

RSpec.describe NJTransit::Configuration do
  let(:config) { described_class.new }

  describe "#initialize" do
    before do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("NJTRANSIT_USERNAME", nil).and_return(nil)
      allow(ENV).to receive(:fetch).with("NJTRANSIT_PASSWORD", nil).and_return(nil)
    end

    it "sets default base_url" do
      expect(config.base_url).to eq("https://pcsdata.njtransit.com")
    end

    it "sets default timeout" do
      expect(config.timeout).to eq(30)
    end

    it "sets default log_level" do
      expect(config.log_level).to eq("silent")
    end

    it "defaults username to nil" do
      expect(config.username).to be_nil
    end

    it "defaults password to nil" do
      expect(config.password).to be_nil
    end
  end

  describe "#log_level=" do
    it "accepts valid log levels" do
      %w[silent info debug].each do |level|
        expect { config.log_level = level }.not_to raise_error
        expect(config.log_level).to eq(level)
      end
    end

    it "rejects invalid log levels" do
      expect { config.log_level = "invalid" }.to raise_error(ArgumentError, /Invalid log level/)
    end

    it "normalizes log level to lowercase" do
      config.log_level = "DEBUG"
      expect(config.log_level).to eq("debug")
    end
  end

  describe "#gtfs_database_path" do
    it "defaults to XDG_DATA_HOME if set" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("NJTRANSIT_GTFS_DATABASE_PATH", anything).and_return(nil)
      allow(ENV).to receive(:[]).with("XDG_DATA_HOME").and_return("/custom/xdg")

      config = described_class.new
      expect(config.gtfs_database_path).to eq("/custom/xdg/njtransit/gtfs.sqlite3")
    end

    it "defaults to ~/.local/share/njtransit when XDG_DATA_HOME not set" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("NJTRANSIT_GTFS_DATABASE_PATH", anything).and_return(nil)
      allow(ENV).to receive(:[]).with("XDG_DATA_HOME").and_return(nil)

      config = described_class.new
      expect(config.gtfs_database_path).to eq(File.expand_path("~/.local/share/njtransit/gtfs.sqlite3"))
    end

    it "can be overridden via environment variable" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("NJTRANSIT_GTFS_DATABASE_PATH", anything).and_return("/custom/path/gtfs.db")

      config = described_class.new
      expect(config.gtfs_database_path).to eq("/custom/path/gtfs.db")
    end

    it "can be set directly" do
      config = described_class.new
      config.gtfs_database_path = "/my/path/gtfs.sqlite3"
      expect(config.gtfs_database_path).to eq("/my/path/gtfs.sqlite3")
    end
  end

  describe "#to_h" do
    before do
      config.username = "test_user"
      config.password = "test_pass"
      config.log_level = "debug"
    end

    it "returns a hash of configuration values" do
      expect(config.to_h).to eq(
        username: "test_user",
        password: "test_pass",
        log_level: "debug",
        base_url: "https://pcsdata.njtransit.com",
        timeout: 30
      )
    end
  end
end
