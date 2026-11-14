# frozen_string_literal: true

require "fileutils"
require "json"
require "securerandom"

module NJTransit
  # Where clients keep NJ Transit auth tokens. NJ Transit caps token creation
  # (as low as 5-10 a day on some endpoints), so a long-running process that
  # restarts should reuse its token instead of authenticating on every boot.
  #
  # A token store is any object that responds to:
  #
  #   read(key)          -> token String or nil
  #   write(key, token)
  #   delete(key)
  #
  # That is the ActiveSupport::Cache::Store interface, so `Rails.cache`
  # works as-is (it persists only if its backend does).
  module TokenStores
    INTERFACE = %i[read write delete].freeze

    def self.validate!(store)
      missing = INTERFACE.reject { |m| store.respond_to?(m) }
      return store if missing.empty?

      raise ArgumentError, "token_store must respond to #{INTERFACE.join(", ")} " \
                           "(missing #{missing.join(", ")}): got #{store.inspect}"
    end

    # Process-local store: tokens are lost when the process exits.
    # Clients share one of these unless configured otherwise.
    class Memory
      def initialize
        @tokens = {}
        @mutex = Mutex.new
      end

      def read(key)
        @mutex.synchronize { @tokens[key] }
      end

      def write(key, token)
        @mutex.synchronize { @tokens[key] = token }
      end

      def delete(key)
        @mutex.synchronize { @tokens.delete(key) }
      end

      def clear
        @mutex.synchronize { @tokens.clear }
      end

      # The live hash behind the store; only for the deprecated Client.token_cache.
      def to_h
        @tokens
      end
    end

    # JSON file store: tokens survive process restarts. Writes take an
    # exclusive flock on "<path>.lock" (so concurrent processes and instances
    # don't lose each other's keys) and replace the file atomically, mode 0600.
    class File
      attr_reader :path

      def initialize(path)
        @path = path
        @mutex = Mutex.new
      end

      def read(key)
        load[key]
      end

      def write(key, token)
        update { |tokens| tokens.merge(key => token) }
      end

      def delete(key)
        update { |tokens| tokens.key?(key) ? tokens.except(key) : nil }
      end

      private

      # Read-modify-write under the lock; the block returns the new hash, or nil for no change.
      def update
        @mutex.synchronize do
          FileUtils.mkdir_p(::File.dirname(path))
          ::File.open("#{path}.lock", ::File::RDWR | ::File::CREAT, 0o600) do |lock|
            lock.flock(::File::LOCK_EX)
            tokens = yield(load)
            save(tokens) if tokens
          end
        end
      end

      def load
        return {} unless ::File.exist?(path)

        data = JSON.parse(::File.read(path))
        data.is_a?(Hash) ? data : {}
      rescue JSON::ParserError
        {}
      end

      def save(tokens)
        tmp = "#{path}.#{Process.pid}.#{SecureRandom.hex(6)}.tmp"
        ::File.open(tmp, ::File::WRONLY | ::File::CREAT | ::File::EXCL, 0o600) { |f| f.write(JSON.generate(tokens)) }
        ::File.rename(tmp, path)
      end
    end
  end
end
