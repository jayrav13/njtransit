# frozen_string_literal: true

require "fileutils"

RSpec.describe NJTransit::GTFS::Database do
  let(:test_db_path) { "tmp/test_gtfs.sqlite3" }

  before do
    FileUtils.mkdir_p("tmp")
    FileUtils.rm_f(test_db_path)
  end

  after do
    described_class.disconnect
    FileUtils.rm_f(test_db_path)
  end

  describe ".connection" do
    it "creates a Sequel SQLite connection" do
      conn = described_class.connection(test_db_path)
      expect(conn).to be_a(Sequel::SQLite::Database)
    end

    it "creates the database file" do
      described_class.connection(test_db_path)
      expect(File.exist?(test_db_path)).to be true
    end

    it "returns the same connection on subsequent calls" do
      conn1 = described_class.connection(test_db_path)
      conn2 = described_class.connection(test_db_path)
      expect(conn1).to be(conn2)
    end
  end

  describe ".setup_schema!" do
    before { described_class.connection(test_db_path) }

    it "creates the agencies table" do
      described_class.setup_schema!
      expect(described_class.connection(test_db_path).table_exists?(:agencies)).to be true
    end

    it "creates the routes table" do
      described_class.setup_schema!
      expect(described_class.connection(test_db_path).table_exists?(:routes)).to be true
    end

    it "creates the stops table" do
      described_class.setup_schema!
      expect(described_class.connection(test_db_path).table_exists?(:stops)).to be true
    end

    it "creates the trips table" do
      described_class.setup_schema!
      expect(described_class.connection(test_db_path).table_exists?(:trips)).to be true
    end

    it "creates the stop_times table" do
      described_class.setup_schema!
      expect(described_class.connection(test_db_path).table_exists?(:stop_times)).to be true
    end

    it "creates the calendar_dates table" do
      described_class.setup_schema!
      expect(described_class.connection(test_db_path).table_exists?(:calendar_dates)).to be true
    end

    it "creates the shapes table" do
      described_class.setup_schema!
      expect(described_class.connection(test_db_path).table_exists?(:shapes)).to be true
    end
  end

  describe ".exists?" do
    it "returns false when database does not exist" do
      expect(described_class.exists?(test_db_path)).to be false
    end

    it "returns true when database exists" do
      described_class.connection(test_db_path)
      described_class.setup_schema!
      described_class.disconnect
      expect(described_class.exists?(test_db_path)).to be true
    end
  end
end
