# GTFS Static Data Loader Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add GTFS static data loading with SQLite storage and automatic Bus API enrichment.

**Architecture:** Sequel gem for database access, SQLite for persistent storage at XDG-compliant path. GTFS import is a one-time deployment step via Rake task. Bus API methods automatically enrich responses with GTFS data (lat/lon, route names).

**Tech Stack:** Ruby 3.2+, Sequel ~> 5.0, SQLite3 ~> 2.0, Rake

---

## Task 1: Add Dependencies

**Files:**
- Modify: `njtransit.gemspec:36-39`
- Modify: `Gemfile`

**Step 1: Add sequel and sqlite3 to gemspec**

In `njtransit.gemspec`, add after line 39:

```ruby
spec.add_dependency "sequel", "~> 5.0"
spec.add_dependency "sqlite3", "~> 2.0"
```

**Step 2: Run bundle install**

Run: `bundle install`
Expected: Dependencies installed successfully

**Step 3: Commit**

```bash
git add njtransit.gemspec Gemfile.lock
git commit -m "feat: add sequel and sqlite3 dependencies for GTFS"
```

---

## Task 2: Add GTFSNotImportedError

**Files:**
- Modify: `lib/njtransit/error.rb`
- Create: `spec/njtransit/gtfs_not_imported_error_spec.rb`

**Step 1: Write the failing test**

Create `spec/njtransit/gtfs_not_imported_error_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe NJTransit::GTFSNotImportedError do
  describe "#initialize" do
    it "includes the base message" do
      error = described_class.new
      expect(error.message).to include("GTFS data not found")
    end

    it "includes hint when gtfs_path is provided" do
      error = described_class.new(detected_path: "./bus_data")
      expect(error.message).to include("Detected GTFS files at: ./bus_data")
      expect(error.message).to include("rake njtransit:gtfs:import[./bus_data]")
    end

    it "excludes hint when no path detected" do
      error = described_class.new
      expect(error.message).not_to include("Detected GTFS files")
    end
  end

  it "inherits from NJTransit::Error" do
    expect(described_class.superclass).to eq(NJTransit::Error)
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/njtransit/gtfs_not_imported_error_spec.rb -v`
Expected: FAIL with "uninitialized constant NJTransit::GTFSNotImportedError"

**Step 3: Write minimal implementation**

Add to `lib/njtransit/error.rb` after line 37 (before final `end`):

```ruby
  # GTFS not imported
  class GTFSNotImportedError < Error
    def initialize(detected_path: nil)
      message = "GTFS data not found. Run: rake njtransit:gtfs:import[/path/to/bus_data]"
      if detected_path
        message += "\n\nDetected GTFS files at: #{detected_path}"
        message += "\nHint: rake njtransit:gtfs:import[#{detected_path}]"
      end
      super(message)
    end
  end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/njtransit/gtfs_not_imported_error_spec.rb -v`
Expected: PASS (3 examples, 0 failures)

**Step 5: Commit**

```bash
git add lib/njtransit/error.rb spec/njtransit/gtfs_not_imported_error_spec.rb
git commit -m "feat: add GTFSNotImportedError with auto-detection hint"
```

---

## Task 3: Add Configuration for GTFS Database Path

**Files:**
- Modify: `lib/njtransit/configuration.rb`
- Modify: `spec/njtransit/configuration_spec.rb`

**Step 1: Write the failing test**

Add to `spec/njtransit/configuration_spec.rb`:

```ruby
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
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/njtransit/configuration_spec.rb -v`
Expected: FAIL with "undefined method `gtfs_database_path'"

**Step 3: Write minimal implementation**

In `lib/njtransit/configuration.rb`:

Add to attr_accessor on line 9:
```ruby
attr_accessor :username, :password, :base_url, :timeout, :gtfs_database_path
```

Add to initialize method after line 17:
```ruby
@gtfs_database_path = ENV.fetch("NJTRANSIT_GTFS_DATABASE_PATH", nil) || default_gtfs_database_path
```

Add private method before the final `end`:
```ruby
private

def default_gtfs_database_path
  base = ENV["XDG_DATA_HOME"] || File.expand_path("~/.local/share")
  File.join(base, "njtransit", "gtfs.sqlite3")
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/njtransit/configuration_spec.rb -v`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/njtransit/configuration.rb spec/njtransit/configuration_spec.rb
git commit -m "feat: add gtfs_database_path configuration with XDG support"
```

---

## Task 4: Create Test Fixtures

**Files:**
- Create: `spec/fixtures/gtfs/agency.txt`
- Create: `spec/fixtures/gtfs/routes.txt`
- Create: `spec/fixtures/gtfs/stops.txt`
- Create: `spec/fixtures/gtfs/trips.txt`
- Create: `spec/fixtures/gtfs/stop_times.txt`
- Create: `spec/fixtures/gtfs/calendar_dates.txt`
- Create: `spec/fixtures/gtfs/shapes.txt`

**Step 1: Create agency.txt**

```csv
agency_id,agency_name,agency_url,agency_timezone
NJB,NJ TRANSIT BUS,http://www.njtransit.com,America/New_York
```

**Step 2: Create routes.txt**

```csv
route_id,agency_id,route_short_name,route_long_name,route_type,route_color
1,NJB,1,Newark - Jersey City,3,000000
2,NJB,10,Bloomfield - Newark,3,000000
3,NJB,197,Willowbrook - Port Authority,3,FF0000
```

**Step 3: Create stops.txt**

```csv
stop_id,stop_code,stop_name,stop_desc,stop_lat,stop_lon,zone_id
1,WBRK,WILLOWBROOK MALL,,40.852300,-74.256700,NB
2,PABT,PORT AUTHORITY BUS TERMINAL,,40.756600,-73.990900,NY
3,21681,MAIN ST AT CENTER,,40.123400,-74.567800,NB
4,21682,BROAD ST AT MARKET,,40.234500,-74.678900,NK
5,21683,CENTRAL AVE AT 1ST,,40.345600,-74.789000,JC
```

**Step 4: Create trips.txt**

```csv
route_id,service_id,trip_id,trip_headsign,direction_id,block_id,shape_id
3,1,100,197 PORT AUTHORITY,0,BLK001,1
3,1,101,197 PORT AUTHORITY,0,BLK002,1
3,1,102,197 WILLOWBROOK,1,BLK003,2
3,2,103,197 PORT AUTHORITY,0,BLK004,1
1,1,200,1 JERSEY CITY,0,BLK010,3
```

**Step 5: Create stop_times.txt**

```csv
trip_id,arrival_time,departure_time,stop_id,stop_sequence,pickup_type,drop_off_type
100,06:00:00,06:00:00,1,1,0,0
100,06:45:00,06:45:00,2,2,0,0
101,07:00:00,07:00:00,1,1,0,0
101,07:45:00,07:45:00,2,2,0,0
102,08:00:00,08:00:00,2,1,0,0
102,08:45:00,08:45:00,1,2,0,0
103,09:00:00,09:00:00,1,1,0,0
103,09:45:00,09:45:00,2,2,0,0
200,05:30:00,05:30:00,4,1,0,0
200,06:00:00,06:00:00,5,2,0,0
```

**Step 6: Create calendar_dates.txt**

```csv
service_id,date,exception_type
1,20260124,1
1,20260125,1
2,20260126,1
```

**Step 7: Create shapes.txt**

```csv
shape_id,shape_pt_lat,shape_pt_lon,shape_pt_sequence
1,40.852300,-74.256700,1
1,40.800000,-74.100000,2
1,40.756600,-73.990900,3
2,40.756600,-73.990900,1
2,40.800000,-74.100000,2
2,40.852300,-74.256700,3
```

**Step 8: Commit**

```bash
git add spec/fixtures/gtfs/
git commit -m "test: add GTFS fixture files for testing"
```

---

## Task 5: Create GTFS Database Module

**Files:**
- Create: `lib/njtransit/gtfs/database.rb`
- Create: `spec/njtransit/gtfs/database_spec.rb`

**Step 1: Write the failing test**

Create `spec/njtransit/gtfs/database_spec.rb`:

```ruby
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
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/njtransit/gtfs/database_spec.rb -v`
Expected: FAIL with "uninitialized constant NJTransit::GTFS"

**Step 3: Create the directory structure**

Run: `mkdir -p lib/njtransit/gtfs`

**Step 4: Write implementation**

Create `lib/njtransit/gtfs/database.rb`:

```ruby
# frozen_string_literal: true

require "sequel"
require "fileutils"

module NJTransit
  module GTFS
    module Database
      class << self
        def connection(path = nil)
          @path = path if path
          @connection ||= begin
            FileUtils.mkdir_p(File.dirname(@path))
            Sequel.sqlite(@path)
          end
        end

        def disconnect
          @connection&.disconnect
          @connection = nil
        end

        def exists?(path)
          return false unless File.exist?(path)

          db = Sequel.sqlite(path)
          db.table_exists?(:agencies) && db.table_exists?(:stops)
        rescue StandardError
          false
        ensure
          db&.disconnect
        end

        def setup_schema!
          db = connection

          db.create_table?(:agencies) do
            String :agency_id, primary_key: true
            String :agency_name
            String :agency_url
            String :agency_timezone
          end

          db.create_table?(:routes) do
            String :route_id, primary_key: true
            String :agency_id
            String :route_short_name
            String :route_long_name
            Integer :route_type
            String :route_color
            index :route_short_name
          end

          db.create_table?(:stops) do
            String :stop_id, primary_key: true
            String :stop_code
            String :stop_name
            Float :stop_lat
            Float :stop_lon
            String :zone_id
            index :stop_code
          end

          db.create_table?(:trips) do
            String :trip_id, primary_key: true
            String :route_id
            String :service_id
            String :trip_headsign
            Integer :direction_id
            String :shape_id
            index :route_id
            index :service_id
          end

          db.create_table?(:stop_times) do
            primary_key :id
            String :trip_id
            String :stop_id
            String :arrival_time
            String :departure_time
            Integer :stop_sequence
            index :trip_id
            index :stop_id
          end

          db.create_table?(:calendar_dates) do
            primary_key :id
            String :service_id
            String :date
            Integer :exception_type
            index [:service_id, :date]
          end

          db.create_table?(:shapes) do
            primary_key :id
            String :shape_id
            Float :shape_pt_lat
            Float :shape_pt_lon
            Integer :shape_pt_sequence
            index :shape_id
          end

          db.create_table?(:import_metadata) do
            primary_key :id
            DateTime :imported_at
            String :source_path
          end
        end

        def clear!
          db = connection
          %i[agencies routes stops trips stop_times calendar_dates shapes import_metadata].each do |table|
            db.drop_table?(table)
          end
        end
      end
    end
  end
end
```

**Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/njtransit/gtfs/database_spec.rb -v`
Expected: PASS

**Step 6: Commit**

```bash
git add lib/njtransit/gtfs/database.rb spec/njtransit/gtfs/database_spec.rb
git commit -m "feat: add GTFS database module with schema setup"
```

---

## Task 6: Create GTFS Importer

**Files:**
- Create: `lib/njtransit/gtfs/importer.rb`
- Create: `spec/njtransit/gtfs/importer_spec.rb`

**Step 1: Write the failing test**

Create `spec/njtransit/gtfs/importer_spec.rb`:

```ruby
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
      expect {
        described_class.new(fixtures_path, test_db_path).import
      }.to raise_error(NJTransit::Error, /already exists/)
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
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/njtransit/gtfs/importer_spec.rb -v`
Expected: FAIL with "uninitialized constant NJTransit::GTFS::Importer"

**Step 3: Write implementation**

Create `lib/njtransit/gtfs/importer.rb`:

```ruby
# frozen_string_literal: true

require "csv"

module NJTransit
  module GTFS
    class Importer
      REQUIRED_FILES = %w[agency.txt routes.txt stops.txt].freeze
      OPTIONAL_FILES = %w[trips.txt stop_times.txt calendar_dates.txt shapes.txt].freeze

      attr_reader :source_path, :db_path

      def initialize(source_path, db_path)
        @source_path = source_path
        @db_path = db_path
      end

      def import(force: false)
        if Database.exists?(db_path) && !force
          raise NJTransit::Error, "GTFS database already exists at #{db_path}. Use force: true to reimport."
        end

        Database.disconnect
        FileUtils.rm_f(db_path) if force

        Database.connection(db_path)
        Database.setup_schema!

        import_agencies
        import_routes
        import_stops
        import_trips
        import_stop_times
        import_calendar_dates
        import_shapes
        record_metadata
      end

      def valid_gtfs_directory?
        return false unless File.directory?(source_path)

        REQUIRED_FILES.all? { |f| File.exist?(File.join(source_path, f)) }
      end

      private

      def import_agencies
        import_csv("agency.txt", :agencies) do |row|
          {
            agency_id: row["agency_id"],
            agency_name: row["agency_name"],
            agency_url: row["agency_url"],
            agency_timezone: row["agency_timezone"]
          }
        end
      end

      def import_routes
        import_csv("routes.txt", :routes) do |row|
          {
            route_id: row["route_id"],
            agency_id: row["agency_id"],
            route_short_name: row["route_short_name"],
            route_long_name: row["route_long_name"],
            route_type: row["route_type"]&.to_i,
            route_color: row["route_color"]
          }
        end
      end

      def import_stops
        import_csv("stops.txt", :stops) do |row|
          {
            stop_id: row["stop_id"],
            stop_code: row["stop_code"],
            stop_name: row["stop_name"],
            stop_lat: row["stop_lat"]&.to_f,
            stop_lon: row["stop_lon"]&.to_f,
            zone_id: row["zone_id"]
          }
        end
      end

      def import_trips
        import_csv("trips.txt", :trips) do |row|
          {
            trip_id: row["trip_id"],
            route_id: row["route_id"],
            service_id: row["service_id"],
            trip_headsign: row["trip_headsign"],
            direction_id: row["direction_id"]&.to_i,
            shape_id: row["shape_id"]
          }
        end
      end

      def import_stop_times
        import_csv("stop_times.txt", :stop_times, batch_size: 10_000) do |row|
          {
            trip_id: row["trip_id"],
            stop_id: row["stop_id"],
            arrival_time: row["arrival_time"],
            departure_time: row["departure_time"],
            stop_sequence: row["stop_sequence"]&.to_i
          }
        end
      end

      def import_calendar_dates
        import_csv("calendar_dates.txt", :calendar_dates) do |row|
          {
            service_id: row["service_id"],
            date: row["date"],
            exception_type: row["exception_type"]&.to_i
          }
        end
      end

      def import_shapes
        import_csv("shapes.txt", :shapes, batch_size: 50_000) do |row|
          {
            shape_id: row["shape_id"],
            shape_pt_lat: row["shape_pt_lat"]&.to_f,
            shape_pt_lon: row["shape_pt_lon"]&.to_f,
            shape_pt_sequence: row["shape_pt_sequence"]&.to_i
          }
        end
      end

      def import_csv(filename, table, batch_size: 1000)
        path = File.join(source_path, filename)
        return unless File.exist?(path)

        db = Database.connection
        batch = []

        CSV.foreach(path, headers: true) do |row|
          batch << yield(row)

          if batch.size >= batch_size
            db[table].multi_insert(batch)
            batch.clear
          end
        end

        db[table].multi_insert(batch) unless batch.empty?
      end

      def record_metadata
        Database.connection[:import_metadata].insert(
          imported_at: Time.now,
          source_path: source_path
        )
      end
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/njtransit/gtfs/importer_spec.rb -v`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/njtransit/gtfs/importer.rb spec/njtransit/gtfs/importer_spec.rb
git commit -m "feat: add GTFS importer with batch CSV parsing"
```

---

## Task 7: Create GTFS Models (Stop, Route)

**Files:**
- Create: `lib/njtransit/gtfs/models/stop.rb`
- Create: `lib/njtransit/gtfs/models/route.rb`
- Create: `spec/njtransit/gtfs/models/stop_spec.rb`
- Create: `spec/njtransit/gtfs/models/route_spec.rb`

**Step 1: Write the failing test for Stop**

Create `spec/njtransit/gtfs/models/stop_spec.rb`:

```ruby
# frozen_string_literal: true

require "fileutils"

RSpec.describe NJTransit::GTFS::Models::Stop do
  let(:fixtures_path) { "spec/fixtures/gtfs" }
  let(:test_db_path) { "tmp/test_models.sqlite3" }

  before(:all) do
    FileUtils.mkdir_p("tmp")
    FileUtils.rm_f("tmp/test_models.sqlite3")
    NJTransit::GTFS::Importer.new("spec/fixtures/gtfs", "tmp/test_models.sqlite3").import
  end

  after(:all) do
    NJTransit::GTFS::Database.disconnect
    FileUtils.rm_f("tmp/test_models.sqlite3")
  end

  before do
    described_class.db = NJTransit::GTFS::Database.connection(test_db_path)
  end

  describe ".all" do
    it "returns all stops" do
      stops = described_class.all
      expect(stops.count).to eq(5)
    end
  end

  describe ".find" do
    it "finds stop by stop_id" do
      stop = described_class.find("1")
      expect(stop.stop_code).to eq("WBRK")
    end

    it "returns nil when not found" do
      stop = described_class.find("nonexistent")
      expect(stop).to be_nil
    end
  end

  describe ".find_by_code" do
    it "finds stop by stop_code" do
      stop = described_class.find_by_code("WBRK")
      expect(stop.stop_name).to eq("WILLOWBROOK MALL")
    end

    it "returns nil when not found" do
      stop = described_class.find_by_code("XXXXX")
      expect(stop).to be_nil
    end
  end

  describe ".where" do
    it "filters by attributes" do
      stops = described_class.where(zone_id: "NB")
      expect(stops.count).to eq(2)
    end
  end

  describe "instance methods" do
    let(:stop) { described_class.find_by_code("WBRK") }

    it "has lat accessor" do
      expect(stop.lat).to eq(40.8523)
    end

    it "has lon accessor" do
      expect(stop.lon).to eq(-74.2567)
    end

    it "converts to hash" do
      hash = stop.to_h
      expect(hash[:stop_id]).to eq("1")
      expect(hash[:stop_code]).to eq("WBRK")
      expect(hash[:lat]).to eq(40.8523)
      expect(hash[:lon]).to eq(-74.2567)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/njtransit/gtfs/models/stop_spec.rb -v`
Expected: FAIL with "uninitialized constant"

**Step 3: Create directories**

Run: `mkdir -p lib/njtransit/gtfs/models spec/njtransit/gtfs/models`

**Step 4: Write Stop implementation**

Create `lib/njtransit/gtfs/models/stop.rb`:

```ruby
# frozen_string_literal: true

module NJTransit
  module GTFS
    module Models
      class Stop
        class << self
          attr_accessor :db

          def all
            db[:stops].all.map { |row| new(row) }
          end

          def find(stop_id)
            row = db[:stops].where(stop_id: stop_id).first
            row ? new(row) : nil
          end

          def find_by_code(stop_code)
            row = db[:stops].where(stop_code: stop_code).first
            row ? new(row) : nil
          end

          def where(conditions)
            db[:stops].where(conditions).all.map { |row| new(row) }
          end
        end

        attr_reader :stop_id, :stop_code, :stop_name, :stop_lat, :stop_lon, :zone_id

        def initialize(attributes)
          @stop_id = attributes[:stop_id]
          @stop_code = attributes[:stop_code]
          @stop_name = attributes[:stop_name]
          @stop_lat = attributes[:stop_lat]
          @stop_lon = attributes[:stop_lon]
          @zone_id = attributes[:zone_id]
        end

        def lat
          stop_lat
        end

        def lon
          stop_lon
        end

        def to_h
          {
            stop_id: stop_id,
            stop_code: stop_code,
            stop_name: stop_name,
            stop_lat: stop_lat,
            stop_lon: stop_lon,
            lat: lat,
            lon: lon,
            zone_id: zone_id
          }
        end
      end
    end
  end
end
```

**Step 5: Write the failing test for Route**

Create `spec/njtransit/gtfs/models/route_spec.rb`:

```ruby
# frozen_string_literal: true

require "fileutils"

RSpec.describe NJTransit::GTFS::Models::Route do
  let(:test_db_path) { "tmp/test_models.sqlite3" }

  before(:all) do
    FileUtils.mkdir_p("tmp")
    FileUtils.rm_f("tmp/test_models.sqlite3")
    NJTransit::GTFS::Importer.new("spec/fixtures/gtfs", "tmp/test_models.sqlite3").import
  end

  after(:all) do
    NJTransit::GTFS::Database.disconnect
    FileUtils.rm_f("tmp/test_models.sqlite3")
  end

  before do
    described_class.db = NJTransit::GTFS::Database.connection(test_db_path)
  end

  describe ".all" do
    it "returns all routes" do
      routes = described_class.all
      expect(routes.count).to eq(3)
    end
  end

  describe ".find" do
    it "finds route by route_id" do
      route = described_class.find("3")
      expect(route.route_short_name).to eq("197")
    end

    it "finds route by short_name" do
      route = described_class.find("197")
      expect(route.route_id).to eq("3")
    end

    it "returns nil when not found" do
      route = described_class.find("nonexistent")
      expect(route).to be_nil
    end
  end

  describe "instance methods" do
    let(:route) { described_class.find("197") }

    it "has short_name accessor" do
      expect(route.short_name).to eq("197")
    end

    it "has long_name accessor" do
      expect(route.long_name).to eq("Willowbrook - Port Authority")
    end

    it "converts to hash" do
      hash = route.to_h
      expect(hash[:route_id]).to eq("3")
      expect(hash[:short_name]).to eq("197")
    end
  end
end
```

**Step 6: Write Route implementation**

Create `lib/njtransit/gtfs/models/route.rb`:

```ruby
# frozen_string_literal: true

module NJTransit
  module GTFS
    module Models
      class Route
        class << self
          attr_accessor :db

          def all
            db[:routes].all.map { |row| new(row) }
          end

          def find(identifier)
            row = db[:routes].where(route_id: identifier).first
            row ||= db[:routes].where(route_short_name: identifier).first
            row ? new(row) : nil
          end

          def where(conditions)
            db[:routes].where(conditions).all.map { |row| new(row) }
          end
        end

        attr_reader :route_id, :agency_id, :route_short_name, :route_long_name, :route_type, :route_color

        def initialize(attributes)
          @route_id = attributes[:route_id]
          @agency_id = attributes[:agency_id]
          @route_short_name = attributes[:route_short_name]
          @route_long_name = attributes[:route_long_name]
          @route_type = attributes[:route_type]
          @route_color = attributes[:route_color]
        end

        def short_name
          route_short_name
        end

        def long_name
          route_long_name
        end

        def to_h
          {
            route_id: route_id,
            agency_id: agency_id,
            route_short_name: route_short_name,
            route_long_name: route_long_name,
            short_name: short_name,
            long_name: long_name,
            route_type: route_type,
            route_color: route_color
          }
        end
      end
    end
  end
end
```

**Step 7: Run tests to verify they pass**

Run: `bundle exec rspec spec/njtransit/gtfs/models/ -v`
Expected: PASS

**Step 8: Commit**

```bash
git add lib/njtransit/gtfs/models/ spec/njtransit/gtfs/models/
git commit -m "feat: add Stop and Route GTFS models"
```

---

## Task 8: Create Routes Between Query

**Files:**
- Create: `lib/njtransit/gtfs/queries/routes_between.rb`
- Create: `spec/njtransit/gtfs/queries/routes_between_spec.rb`

**Step 1: Write the failing test**

Create `spec/njtransit/gtfs/queries/routes_between_spec.rb`:

```ruby
# frozen_string_literal: true

require "fileutils"

RSpec.describe NJTransit::GTFS::Queries::RoutesBetween do
  let(:test_db_path) { "tmp/test_queries.sqlite3" }

  before(:all) do
    FileUtils.mkdir_p("tmp")
    FileUtils.rm_f("tmp/test_queries.sqlite3")
    NJTransit::GTFS::Importer.new("spec/fixtures/gtfs", "tmp/test_queries.sqlite3").import
  end

  after(:all) do
    NJTransit::GTFS::Database.disconnect
    FileUtils.rm_f("tmp/test_queries.sqlite3")
  end

  let(:db) { NJTransit::GTFS::Database.connection(test_db_path) }

  describe "#call" do
    it "finds routes serving both stops" do
      query = described_class.new(db, from: "WBRK", to: "PABT")
      routes = query.call
      expect(routes).to include("197")
    end

    it "returns empty array when no routes connect stops" do
      query = described_class.new(db, from: "21681", to: "21682")
      routes = query.call
      expect(routes).to be_empty
    end

    it "accepts stop_id or stop_code" do
      query = described_class.new(db, from: "1", to: "2")
      routes = query.call
      expect(routes).to include("197")
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/njtransit/gtfs/queries/routes_between_spec.rb -v`
Expected: FAIL with "uninitialized constant"

**Step 3: Create directories**

Run: `mkdir -p lib/njtransit/gtfs/queries spec/njtransit/gtfs/queries`

**Step 4: Write implementation**

Create `lib/njtransit/gtfs/queries/routes_between.rb`:

```ruby
# frozen_string_literal: true

module NJTransit
  module GTFS
    module Queries
      class RoutesBetween
        attr_reader :db, :from, :to

        def initialize(db, from:, to:)
          @db = db
          @from = from
          @to = to
        end

        def call
          from_stop_id = resolve_stop_id(from)
          to_stop_id = resolve_stop_id(to)

          return [] if from_stop_id.nil? || to_stop_id.nil?

          # Find trips that stop at both locations
          from_trips = db[:stop_times].where(stop_id: from_stop_id).select_map(:trip_id)
          to_trips = db[:stop_times].where(stop_id: to_stop_id).select_map(:trip_id)

          common_trips = from_trips & to_trips
          return [] if common_trips.empty?

          # Get route_ids for those trips
          route_ids = db[:trips].where(trip_id: common_trips).select_map(:route_id).uniq

          # Get route short names
          db[:routes].where(route_id: route_ids).select_map(:route_short_name).uniq
        end

        private

        def resolve_stop_id(identifier)
          # Try as stop_id first
          stop = db[:stops].where(stop_id: identifier).first
          return identifier if stop

          # Try as stop_code
          stop = db[:stops].where(stop_code: identifier).first
          stop&.dig(:stop_id)
        end
      end
    end
  end
end
```

**Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/njtransit/gtfs/queries/routes_between_spec.rb -v`
Expected: PASS

**Step 6: Commit**

```bash
git add lib/njtransit/gtfs/queries/ spec/njtransit/gtfs/queries/
git commit -m "feat: add routes_between query"
```

---

## Task 9: Create Schedule Query

**Files:**
- Create: `lib/njtransit/gtfs/queries/schedule.rb`
- Create: `spec/njtransit/gtfs/queries/schedule_spec.rb`

**Step 1: Write the failing test**

Create `spec/njtransit/gtfs/queries/schedule_spec.rb`:

```ruby
# frozen_string_literal: true

require "fileutils"

RSpec.describe NJTransit::GTFS::Queries::Schedule do
  let(:test_db_path) { "tmp/test_queries.sqlite3" }

  before(:all) do
    FileUtils.mkdir_p("tmp")
    FileUtils.rm_f("tmp/test_queries.sqlite3")
    NJTransit::GTFS::Importer.new("spec/fixtures/gtfs", "tmp/test_queries.sqlite3").import
  end

  after(:all) do
    NJTransit::GTFS::Database.disconnect
    FileUtils.rm_f("tmp/test_queries.sqlite3")
  end

  let(:db) { NJTransit::GTFS::Database.connection(test_db_path) }

  describe "#call" do
    it "returns schedule for route at stop on date" do
      # Date 20260124 has service_id 1
      query = described_class.new(db, route: "197", stop: "WBRK", date: Date.new(2026, 1, 24))
      schedule = query.call
      expect(schedule).not_to be_empty
      expect(schedule.first).to have_key(:arrival_time)
      expect(schedule.first).to have_key(:departure_time)
      expect(schedule.first).to have_key(:trip_id)
    end

    it "returns empty array when no service on date" do
      query = described_class.new(db, route: "197", stop: "WBRK", date: Date.new(2026, 1, 20))
      schedule = query.call
      expect(schedule).to be_empty
    end

    it "orders by arrival time" do
      query = described_class.new(db, route: "197", stop: "WBRK", date: Date.new(2026, 1, 24))
      schedule = query.call
      times = schedule.map { |s| s[:arrival_time] }
      expect(times).to eq(times.sort)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/njtransit/gtfs/queries/schedule_spec.rb -v`
Expected: FAIL with "uninitialized constant"

**Step 3: Write implementation**

Create `lib/njtransit/gtfs/queries/schedule.rb`:

```ruby
# frozen_string_literal: true

module NJTransit
  module GTFS
    module Queries
      class Schedule
        attr_reader :db, :route, :stop, :date

        def initialize(db, route:, stop:, date:)
          @db = db
          @route = route
          @stop = stop
          @date = date
        end

        def call
          route_id = resolve_route_id
          stop_id = resolve_stop_id
          service_ids = active_service_ids

          return [] if route_id.nil? || stop_id.nil? || service_ids.empty?

          # Find trips for this route on active services
          trip_ids = db[:trips]
            .where(route_id: route_id, service_id: service_ids)
            .select_map(:trip_id)

          return [] if trip_ids.empty?

          # Get stop times for these trips at this stop
          db[:stop_times]
            .where(trip_id: trip_ids, stop_id: stop_id)
            .order(:arrival_time)
            .all
            .map do |row|
              {
                trip_id: row[:trip_id],
                arrival_time: row[:arrival_time],
                departure_time: row[:departure_time],
                stop_sequence: row[:stop_sequence]
              }
            end
        end

        private

        def resolve_route_id
          route_row = db[:routes].where(route_id: route).first
          route_row ||= db[:routes].where(route_short_name: route).first
          route_row&.dig(:route_id)
        end

        def resolve_stop_id
          stop_row = db[:stops].where(stop_id: stop).first
          stop_row ||= db[:stops].where(stop_code: stop).first
          stop_row&.dig(:stop_id)
        end

        def active_service_ids
          date_str = date.strftime("%Y%m%d")
          db[:calendar_dates]
            .where(date: date_str, exception_type: 1)
            .select_map(:service_id)
        end
      end
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/njtransit/gtfs/queries/schedule_spec.rb -v`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/njtransit/gtfs/queries/schedule.rb spec/njtransit/gtfs/queries/schedule_spec.rb
git commit -m "feat: add schedule query"
```

---

## Task 10: Create Main GTFS Module

**Files:**
- Create: `lib/njtransit/gtfs.rb`
- Update: `lib/njtransit.rb`
- Create: `spec/njtransit/gtfs_spec.rb`

**Step 1: Write the failing test**

Create `spec/njtransit/gtfs_spec.rb`:

```ruby
# frozen_string_literal: true

require "fileutils"

RSpec.describe NJTransit::GTFS do
  let(:fixtures_path) { "spec/fixtures/gtfs" }
  let(:test_db_path) { "tmp/test_gtfs_main.sqlite3" }

  before do
    FileUtils.mkdir_p("tmp")
    FileUtils.rm_f(test_db_path)
    allow(NJTransit.configuration).to receive(:gtfs_database_path).and_return(test_db_path)
  end

  after do
    NJTransit::GTFS::Database.disconnect
    FileUtils.rm_f(test_db_path)
  end

  describe ".import" do
    it "imports GTFS data" do
      described_class.import(fixtures_path)
      expect(NJTransit::GTFS::Database.exists?(test_db_path)).to be true
    end

    it "raises error for invalid directory" do
      expect {
        described_class.import("/nonexistent")
      }.to raise_error(NJTransit::Error, /Invalid GTFS directory/)
    end
  end

  describe ".status" do
    context "when not imported" do
      it "returns imported: false" do
        status = described_class.status
        expect(status[:imported]).to be false
      end
    end

    context "when imported" do
      before { described_class.import(fixtures_path) }

      it "returns imported: true" do
        status = described_class.status
        expect(status[:imported]).to be true
      end

      it "returns record counts" do
        status = described_class.status
        expect(status[:routes]).to eq(3)
        expect(status[:stops]).to eq(5)
      end
    end
  end

  describe ".new" do
    context "when GTFS imported" do
      before { described_class.import(fixtures_path) }

      it "returns a query interface" do
        gtfs = described_class.new
        expect(gtfs).to be_a(NJTransit::GTFS::QueryInterface)
      end
    end

    context "when GTFS not imported" do
      it "raises GTFSNotImportedError" do
        expect {
          described_class.new
        }.to raise_error(NJTransit::GTFSNotImportedError)
      end
    end
  end

  describe ".detect_gtfs_path" do
    it "returns nil when no GTFS files found" do
      expect(described_class.detect_gtfs_path).to be_nil
    end

    it "returns path when GTFS files exist" do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with("./docs/api/njtransit/bus_data/agency.txt").and_return(true)
      allow(File).to receive(:directory?).with("./docs/api/njtransit/bus_data").and_return(true)

      expect(described_class.detect_gtfs_path).to eq("./docs/api/njtransit/bus_data")
    end
  end
end

RSpec.describe NJTransit::GTFS::QueryInterface do
  let(:fixtures_path) { "spec/fixtures/gtfs" }
  let(:test_db_path) { "tmp/test_gtfs_query.sqlite3" }

  before(:all) do
    FileUtils.mkdir_p("tmp")
    FileUtils.rm_f("tmp/test_gtfs_query.sqlite3")
    allow(NJTransit.configuration).to receive(:gtfs_database_path).and_return("tmp/test_gtfs_query.sqlite3")
    NJTransit::GTFS.import("spec/fixtures/gtfs")
  end

  after(:all) do
    NJTransit::GTFS::Database.disconnect
    FileUtils.rm_f("tmp/test_gtfs_query.sqlite3")
  end

  let(:gtfs) { NJTransit::GTFS.new }

  before do
    allow(NJTransit.configuration).to receive(:gtfs_database_path).and_return(test_db_path)
  end

  describe "#stops" do
    it "provides stop query methods" do
      expect(gtfs.stops.all.count).to eq(5)
    end

    it "finds by code" do
      stop = gtfs.stops.find_by_code("WBRK")
      expect(stop.stop_name).to eq("WILLOWBROOK MALL")
    end
  end

  describe "#routes" do
    it "provides route query methods" do
      expect(gtfs.routes.all.count).to eq(3)
    end
  end

  describe "#routes_between" do
    it "finds routes between two stops" do
      routes = gtfs.routes_between(from: "WBRK", to: "PABT")
      expect(routes).to include("197")
    end
  end

  describe "#schedule" do
    it "returns schedule for route/stop/date" do
      schedule = gtfs.schedule(route: "197", stop: "WBRK", date: Date.new(2026, 1, 24))
      expect(schedule).not_to be_empty
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/njtransit/gtfs_spec.rb -v`
Expected: FAIL

**Step 3: Write implementation**

Create `lib/njtransit/gtfs.rb`:

```ruby
# frozen_string_literal: true

require_relative "gtfs/database"
require_relative "gtfs/importer"
require_relative "gtfs/models/stop"
require_relative "gtfs/models/route"
require_relative "gtfs/queries/routes_between"
require_relative "gtfs/queries/schedule"

module NJTransit
  module GTFS
    SEARCH_PATHS = [
      "./bus_data",
      "./vendor/bus_data",
      "./docs/api/njtransit/bus_data"
    ].freeze

    class << self
      def import(source_path, force: false)
        importer = Importer.new(source_path, database_path)

        unless importer.valid_gtfs_directory?
          raise NJTransit::Error, "Invalid GTFS directory: #{source_path}. Must contain agency.txt, routes.txt, stops.txt"
        end

        importer.import(force: force)
      end

      def status
        path = database_path
        return { imported: false, path: path } unless Database.exists?(path)

        Database.connection(path)
        db = Database.connection

        metadata = db[:import_metadata].order(Sequel.desc(:id)).first

        {
          imported: true,
          path: path,
          routes: db[:routes].count,
          stops: db[:stops].count,
          trips: db[:trips].count,
          stop_times: db[:stop_times].count,
          imported_at: metadata&.dig(:imported_at),
          source_path: metadata&.dig(:source_path)
        }
      end

      def new
        path = database_path

        unless Database.exists?(path)
          detected = detect_gtfs_path
          raise GTFSNotImportedError.new(detected_path: detected)
        end

        QueryInterface.new(path)
      end

      def detect_gtfs_path
        SEARCH_PATHS.find do |path|
          File.directory?(path) && File.exist?(File.join(path, "agency.txt"))
        end
      end

      def clear!
        Database.connection(database_path)
        Database.clear!
        Database.disconnect
        FileUtils.rm_f(database_path)
      end

      private

      def database_path
        NJTransit.configuration.gtfs_database_path
      end
    end

    class QueryInterface
      attr_reader :db

      def initialize(db_path)
        Database.connection(db_path)
        @db = Database.connection
        setup_models
      end

      def stops
        Models::Stop
      end

      def routes
        Models::Route
      end

      def routes_between(from:, to:)
        Queries::RoutesBetween.new(db, from: from, to: to).call
      end

      def schedule(route:, stop:, date:)
        Queries::Schedule.new(db, route: route, stop: stop, date: date).call
      end

      private

      def setup_models
        Models::Stop.db = db
        Models::Route.db = db
      end
    end
  end
end
```

**Step 4: Update lib/njtransit.rb**

Add after line 5 (`require_relative "njtransit/client"`):

```ruby
require_relative "njtransit/gtfs"
```

**Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/njtransit/gtfs_spec.rb -v`
Expected: PASS

**Step 6: Commit**

```bash
git add lib/njtransit/gtfs.rb lib/njtransit.rb spec/njtransit/gtfs_spec.rb
git commit -m "feat: add main GTFS module with query interface"
```

---

## Task 11: Add Rake Tasks

**Files:**
- Create: `lib/njtransit/tasks.rb`
- Create: `lib/njtransit/railtie.rb`

**Step 1: Create Rake tasks**

Create `lib/njtransit/tasks.rb`:

```ruby
# frozen_string_literal: true

require "rake"

namespace :njtransit do
  namespace :gtfs do
    desc "Import GTFS data from specified path"
    task :import, [:path] do |_t, args|
      require "njtransit"

      path = args[:path]
      if path.nil? || path.empty?
        detected = NJTransit::GTFS.detect_gtfs_path
        if detected
          puts "No path specified. Detected GTFS data at: #{detected}"
          print "Use this path? [Y/n] "
          response = $stdin.gets&.strip&.downcase
          path = detected if response.nil? || response.empty? || response == "y"
        end
      end

      if path.nil? || path.empty?
        puts "Usage: rake njtransit:gtfs:import[/path/to/gtfs/data]"
        exit 1
      end

      puts "Importing GTFS data from #{path}..."
      NJTransit::GTFS.import(path, force: ENV["FORCE"] == "true")
      status = NJTransit::GTFS.status
      puts "Import complete!"
      puts "  Routes: #{status[:routes]}"
      puts "  Stops: #{status[:stops]}"
      puts "  Trips: #{status[:trips]}"
      puts "  Stop times: #{status[:stop_times]}"
      puts "  Database: #{status[:path]}"
    end

    desc "Show GTFS import status"
    task :status do
      require "njtransit"

      status = NJTransit::GTFS.status
      if status[:imported]
        puts "GTFS Status: Imported"
        puts "  Database: #{status[:path]}"
        puts "  Routes: #{status[:routes]}"
        puts "  Stops: #{status[:stops]}"
        puts "  Trips: #{status[:trips]}"
        puts "  Stop times: #{status[:stop_times]}"
        puts "  Imported at: #{status[:imported_at]}"
        puts "  Source: #{status[:source_path]}"
      else
        puts "GTFS Status: Not imported"
        puts "  Database path: #{status[:path]}"
        detected = NJTransit::GTFS.detect_gtfs_path
        puts "  Detected GTFS data: #{detected}" if detected
      end
    end

    desc "Clear GTFS database"
    task :clear do
      require "njtransit"

      print "Are you sure you want to clear the GTFS database? [y/N] "
      response = $stdin.gets&.strip&.downcase
      if response == "y"
        NJTransit::GTFS.clear!
        puts "GTFS database cleared."
      else
        puts "Cancelled."
      end
    end
  end
end
```

**Step 2: Create Railtie for Rails auto-loading**

Create `lib/njtransit/railtie.rb`:

```ruby
# frozen_string_literal: true

module NJTransit
  class Railtie < Rails::Railtie
    rake_tasks do
      load "njtransit/tasks.rb"
    end
  end
end
```

**Step 3: Update lib/njtransit.rb to load railtie**

Add at the end of the file (before final `end`):

```ruby
require_relative "njtransit/railtie" if defined?(Rails::Railtie)
```

**Step 4: Commit**

```bash
git add lib/njtransit/tasks.rb lib/njtransit/railtie.rb lib/njtransit.rb
git commit -m "feat: add Rake tasks for GTFS import/status/clear"
```

---

## Task 12: Add Bus API Enrichment

**Files:**
- Modify: `lib/njtransit/resources/bus.rb`
- Create: `spec/njtransit/resources/bus_enrichment_spec.rb`

**Step 1: Write the failing test**

Create `spec/njtransit/resources/bus_enrichment_spec.rb`:

```ruby
# frozen_string_literal: true

require "fileutils"

RSpec.describe "Bus API Enrichment" do
  let(:test_db_path) { "tmp/test_enrichment.sqlite3" }
  let(:client) { instance_double(NJTransit::Client) }
  let(:bus) { NJTransit::Resources::Bus.new(client) }

  before do
    FileUtils.mkdir_p("tmp")
    FileUtils.rm_f(test_db_path)
    allow(NJTransit.configuration).to receive(:gtfs_database_path).and_return(test_db_path)
    NJTransit::GTFS.import("spec/fixtures/gtfs")
    allow(client).to receive(:token).and_return("test_token")
  end

  after do
    NJTransit::GTFS::Database.disconnect
    FileUtils.rm_f(test_db_path)
  end

  describe "#stops with enrichment" do
    let(:api_response) do
      [
        { "stop_id" => "WBRK", "stop_name" => "WILLOWBROOK" },
        { "stop_id" => "PABT", "stop_name" => "PORT AUTHORITY" }
      ]
    end

    before do
      allow(client).to receive(:post_form).and_return(api_response)
    end

    it "adds lat/lon from GTFS by default" do
      result = bus.stops(route: "197", direction: "New York")
      expect(result.first["stop_lat"]).to eq(40.8523)
      expect(result.first["stop_lon"]).to eq(-74.2567)
    end

    it "skips enrichment when enrich: false" do
      result = bus.stops(route: "197", direction: "New York", enrich: false)
      expect(result.first).not_to have_key("stop_lat")
    end
  end

  describe "#departures with enrichment" do
    let(:api_response) do
      [
        { "stop_id" => "WBRK", "route" => "197" }
      ]
    end

    before do
      allow(client).to receive(:post_form).and_return(api_response)
    end

    it "adds stop coordinates and route name" do
      result = bus.departures(stop: "WBRK")
      expect(result.first["stop_lat"]).to eq(40.8523)
      expect(result.first["route_long_name"]).to eq("Willowbrook - Port Authority")
    end
  end

  describe "when GTFS not imported" do
    before do
      NJTransit::GTFS.clear!
      NJTransit::GTFS::Database.disconnect
      FileUtils.rm_f(test_db_path)
    end

    it "raises GTFSNotImportedError for enriched calls" do
      expect {
        bus.stops(route: "197", direction: "New York")
      }.to raise_error(NJTransit::GTFSNotImportedError)
    end

    it "succeeds with enrich: false" do
      allow(client).to receive(:post_form).and_return([])
      expect {
        bus.stops(route: "197", direction: "New York", enrich: false)
      }.not_to raise_error
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/njtransit/resources/bus_enrichment_spec.rb -v`
Expected: FAIL (enrichment not implemented)

**Step 3: Write implementation**

Replace `lib/njtransit/resources/bus.rb`:

```ruby
# frozen_string_literal: true

module NJTransit
  module Resources
    class Bus < Base
      MODE = "BUS"

      def locations
        post_form("/api/BUSDV2/getLocations", mode: MODE)
      end

      def routes
        post_form("/api/BUSDV2/getBusRoutes", mode: MODE)
      end

      def directions(route:)
        post_form("/api/BUSDV2/getBusDirectionsData", route: route)
      end

      def stops(route:, direction:, name_contains: nil, enrich: true)
        params = { route: route, direction: direction }
        params[:namecontains] = name_contains if name_contains
        result = post_form("/api/BUSDV2/getStops", params)
        enrich ? enrich_stops(result) : result
      end

      def stop_name(stop_number:, enrich: true)
        result = post_form("/api/BUSDV2/getStopName", stopnum: stop_number)
        enrich ? enrich_stop_name(result, stop_number) : result
      end

      def route_trips(location:, route:)
        post_form("/api/BUSDV2/getRouteTrips", location: location, route: route)
      end

      def departures(stop:, route: nil, direction: nil, enrich: true)
        params = { stop: stop }
        params[:route] = route if route
        params[:direction] = direction if direction
        result = post_form("/api/BUSDV2/getBusDV", params)
        enrich ? enrich_departures(result) : result
      end

      def trip_stops(internal_trip_number:, sched_dep_time:, timing_point_id: nil)
        params = {
          internal_trip_number: internal_trip_number,
          sched_dep_time: sched_dep_time
        }
        params[:timing_point_id] = timing_point_id if timing_point_id
        post_form("/api/BUSDV2/getTripStops", params)
      end

      def stops_nearby(lat:, lon:, radius:, route: nil, direction: nil, enrich: true)
        params = { lat: lat, lon: lon, radius: radius, mode: MODE }
        params[:route] = route if route
        params[:direction] = direction if direction
        result = post_form("/api/BUSDV2/getBusLocationsData", params)
        enrich ? enrich_stops_nearby(result) : result
      end

      def vehicles_nearby(lat:, lon:, radius:, enrich: true)
        result = post_form("/api/BUSDV2/getVehicleLocations", lat: lat, lon: lon, radius: radius, mode: MODE)
        enrich ? enrich_vehicles(result) : result
      end

      private

      def post_form(path, params = {})
        params[:token] = client.token
        client.post_form(path, params)
      end

      def gtfs
        @gtfs ||= GTFS.new
      end

      def enrich_stops(stops)
        return stops unless stops.is_a?(Array)

        stops.each do |stop|
          stop_code = stop["stop_id"] || stop[:stop_id]
          next unless stop_code

          gtfs_stop = gtfs.stops.find_by_code(stop_code.to_s)
          next unless gtfs_stop

          stop["stop_lat"] = gtfs_stop.lat
          stop["stop_lon"] = gtfs_stop.lon
          stop["zone_id"] = gtfs_stop.zone_id
        end
        stops
      end

      def enrich_stop_name(result, stop_number)
        gtfs_stop = gtfs.stops.find_by_code(stop_number.to_s)
        return result unless gtfs_stop

        if result.is_a?(Hash)
          result["stop_lat"] = gtfs_stop.lat
          result["stop_lon"] = gtfs_stop.lon
        end
        result
      end

      def enrich_departures(departures)
        return departures unless departures.is_a?(Array)

        departures.each do |dep|
          # Enrich stop info
          stop_code = dep["stop_id"] || dep[:stop_id]
          if stop_code
            gtfs_stop = gtfs.stops.find_by_code(stop_code.to_s)
            if gtfs_stop
              dep["stop_lat"] = gtfs_stop.lat
              dep["stop_lon"] = gtfs_stop.lon
            end
          end

          # Enrich route info
          route_name = dep["route"] || dep[:route]
          if route_name
            gtfs_route = gtfs.routes.find(route_name.to_s)
            dep["route_long_name"] = gtfs_route.long_name if gtfs_route
          end
        end
        departures
      end

      def enrich_stops_nearby(stops)
        return stops unless stops.is_a?(Array)

        stops.each do |stop|
          stop_code = stop["stop_id"] || stop[:stop_id]
          next unless stop_code

          gtfs_stop = gtfs.stops.find_by_code(stop_code.to_s)
          stop["zone_id"] = gtfs_stop.zone_id if gtfs_stop
        end
        stops
      end

      def enrich_vehicles(vehicles)
        return vehicles unless vehicles.is_a?(Array)

        vehicles.each do |vehicle|
          route_name = vehicle["route"] || vehicle[:route]
          next unless route_name

          gtfs_route = gtfs.routes.find(route_name.to_s)
          vehicle["route_long_name"] = gtfs_route.long_name if gtfs_route
        end
        vehicles
      end
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/njtransit/resources/bus_enrichment_spec.rb -v`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/njtransit/resources/bus.rb spec/njtransit/resources/bus_enrichment_spec.rb
git commit -m "feat: add automatic GTFS enrichment to Bus API responses"
```

---

## Task 13: Run Full Test Suite

**Step 1: Run all tests**

Run: `bundle exec rspec --format documentation`
Expected: All tests pass

**Step 2: Run RuboCop**

Run: `bundle exec rubocop`
Expected: No offenses (or fix any that appear)

**Step 3: Commit any fixes**

```bash
git add -A
git commit -m "chore: fix rubocop offenses"
```

---

## Task 14: Update README

**Files:**
- Modify: `README.md`

Add GTFS documentation section covering:
- Installation (bundle install)
- GTFS import (rake task)
- Query API usage
- Bus API enrichment
- Configuration options

**Commit:**

```bash
git add README.md
git commit -m "docs: add GTFS loader documentation to README"
```

---

## Summary

This plan implements the GTFS static data loader with:

1. **Dependencies:** Sequel + SQLite3
2. **Database:** XDG-compliant SQLite storage with full schema
3. **Importer:** Batch CSV parsing with progress
4. **Models:** Stop, Route with query methods
5. **Queries:** routes_between, schedule
6. **Rake tasks:** import, status, clear
7. **Enrichment:** Automatic GTFS data in Bus API responses
8. **Testing:** Full coverage with fixtures

Total: ~14 tasks, each with TDD approach (test → implement → verify → commit)
