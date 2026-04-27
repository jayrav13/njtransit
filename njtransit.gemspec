# frozen_string_literal: true

require_relative "lib/njtransit/version"

Gem::Specification.new do |spec|
  spec.name = "njtransit"
  spec.version = NJTransit::VERSION
  spec.authors = ["Jay Ravaliya"]
  spec.email = ["jayrav13@gmail.com"]

  spec.summary = "Ruby client for the NJTransit API"
  spec.description = "A developer-friendly Ruby gem for interacting with NJTransit's API. " \
                     "Provides access to stations, routes, schedules, real-time arrivals, and more."
  spec.homepage = "https://github.com/jayrav13/njtransit"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/jayrav13/njtransit"
  spec.metadata["changelog_uri"] = "https://github.com/jayrav13/njtransit/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Dependencies
  spec.add_dependency "csv", "~> 3.0"
  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-multipart", "~> 1.0"
  spec.add_dependency "faraday-typhoeus", ">= 1", "< 3"
  spec.add_dependency "sequel", "~> 5.0"
  spec.add_dependency "sqlite3", "~> 2.0"
  spec.add_dependency "typhoeus", "~> 1.4"
end
