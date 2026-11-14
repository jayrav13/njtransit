# frozen_string_literal: true

require "fileutils"
require "json"

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

    # JSON file store: tokens survive process restarts. The file is created
    # with mode 0600 and replaced atomically on every write.
    class File
      attr_reader :path

      def initialize(path)
        @path = path
        @mutex = Mutex.new
      end

      def read(key)
        @mutex.synchronize { load[key] }
      end

      def write(key, token)
        @mutex.synchronize { save(load.merge(key => token)) }
      end

      def delete(key)
        @mutex.synchronize do
          tokens = load
          save(tokens) if tokens.delete(key)
        end
      end

      private

      def load
        return {} unless ::File.exist?(path)

        data = JSON.parse(::File.read(path))
        data.is_a?(Hash) ? data : {}
      rescue JSON::ParserError
        {}
      end

      def save(tokens)
        FileUtils.mkdir_p(::File.dirname(path))
        tmp = "#{path}.#{Process.pid}.tmp"
        ::File.open(tmp, ::File::WRONLY | ::File::CREAT | ::File::TRUNC, 0o600) { |f| f.write(JSON.generate(tokens)) }
        ::File.rename(tmp, path)
      end
    end
  end
end
