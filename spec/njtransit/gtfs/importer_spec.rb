# frozen_string_literal: true

require "fileutils"

RSpec.describe NJTransit::GTFS::Importer do
  let(:fixtures_path) { "spec/fixtures/gtfs" }
  let(:test_db_path) { "tmp/test_import.sqlite3" }

  before do
    FileUtils.mkdir_p("tmp")
    FileUtils.rm_f(test_db_path)
  end

  after do
    NJTransit::GTFS::Database.disconnect
    FileUtils.rm_f(test_db_path)
  end

  describe "#import" do
    subject(:importer) { described_class.new(fixtures_path, test_db_path) }

    it "imports agencies" do
      importer.import
      db = NJTransit::GTFS::Database.connection(test_db_path)
      expect(db[:agencies].count).to eq(1)
    end

    it "imports routes" do
      importer.import
      db = NJTransit::GTFS::Database.connection(test_db_path)
      expect(db[:routes].count).to eq(3)
    end

    it "imports stops" do
      importer.import
      db = NJTransit::GTFS::Database.connection(test_db_path)
      expect(db[:stops].count).to eq(5)
    end

    it "imports trips" do
      importer.import
      db = NJTransit::GTFS::Database.connection(test_db_path)
      expect(db[:trips].count).to eq(5)
    end

    it "imports stop_times" do
      importer.import
      db = NJTransit::GTFS::Database.connection(test_db_path)
      expect(db[:stop_times].count).to eq(10)
    end

    it "imports calendar_dates" do
      importer.import
      db = NJTransit::GTFS::Database.connection(test_db_path)
      expect(db[:calendar_dates].count).to eq(3)
    end

    it "imports shapes" do
      importer.import
      db = NJTransit::GTFS::Database.connection(test_db_path)
      expect(db[:shapes].count).to eq(6)
    end

    it "records import metadata" do
      importer.import
      db = NJTransit::GTFS::Database.connection(test_db_path)
      metadata = db[:import_metadata].first
      expect(metadata[:source_path]).to eq(fixtures_path)
      expect(metadata[:imported_at]).not_to be_nil
    end

    it "clears existing data when force: true" do
      importer.import
      # Import again with force
      described_class.new(fixtures_path, test_db_path).import(force: true)
      db = NJTransit::GTFS::Database.connection(test_db_path)
      expect(db[:import_metadata].count).to eq(1)
    end

    it "raises error if database exists without force" do
      importer.import
      NJTransit::GTFS::Database.disconnect
      expect do
        described_class.new(fixtures_path, test_db_path).import
      end.to raise_error(NJTransit::Error, /already exists/)
    end
  end

  describe "#valid_gtfs_directory?" do
    it "returns true for valid GTFS directory" do
      importer = described_class.new(fixtures_path, test_db_path)
      expect(importer.valid_gtfs_directory?).to be true
    end

    it "returns false for invalid directory" do
      importer = described_class.new("/nonexistent", test_db_path)
      expect(importer.valid_gtfs_directory?).to be false
    end
  end
end
