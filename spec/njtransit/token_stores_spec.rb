# frozen_string_literal: true

require "tmpdir"

RSpec.shared_examples "a token store" do
  it "returns nil for an unknown key" do
    expect(store.read("missing")).to be_nil
  end

  it "reads back a written token" do
    store.write("key", "abc123")
    expect(store.read("key")).to eq("abc123")
  end

  it "keeps keys separate" do
    store.write("bus", "one")
    store.write("rail", "two")
    expect([store.read("bus"), store.read("rail")]).to eq(%w[one two])
  end

  it "deletes a token" do
    store.write("key", "abc123")
    store.delete("key")
    expect(store.read("key")).to be_nil
  end

  it "ignores deleting an unknown key" do
    expect { store.delete("missing") }.not_to raise_error
  end
end

RSpec.describe NJTransit::TokenStores::Memory do
  subject(:store) { described_class.new }

  it_behaves_like "a token store"

  it "clears every token" do
    store.write("key", "abc123")
    store.clear
    expect(store.read("key")).to be_nil
  end
end

RSpec.describe NJTransit::TokenStores::File do
  subject(:store) { described_class.new(path) }

  let(:dir) { Dir.mktmpdir }
  let(:path) { File.join(dir, "nested", "tokens.json") }

  after { FileUtils.remove_entry(dir) }

  it_behaves_like "a token store"

  it "persists tokens across instances (process restarts)" do
    store.write("key", "abc123")
    expect(described_class.new(path).read("key")).to eq("abc123")
  end

  it "creates the file readable only by its owner" do
    store.write("key", "abc123")
    expect(File.stat(path).mode & 0o777).to eq(0o600)
  end

  it "keeps every key when several processes write at once" do
    file = path # resolve the lazy tmpdir before forking
    pids = Array.new(8) do |i|
      fork do
        writer = described_class.new(file)
        20.times { |j| writer.write("p#{i}-#{j}", "t") }
        exit!(0)
      end
    end
    pids.each { |pid| Process.wait(pid) }

    expect(JSON.parse(File.read(file)).size).to eq(160)
  end

  it "survives two instances on the same path writing from many threads" do
    stores = [described_class.new(path), described_class.new(path)]
    threads = Array.new(10) do |i|
      Thread.new { 20.times { |j| stores[i % 2].write("t#{i}-#{j}", "x") } }
    end
    threads.each(&:join)

    expect(JSON.parse(File.read(path)).size).to eq(200)
  end

  it "treats a corrupt file as empty" do
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "not json")
    expect(store.read("key")).to be_nil
  end
end
