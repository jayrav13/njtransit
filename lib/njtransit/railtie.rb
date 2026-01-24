# frozen_string_literal: true

module NJTransit
  class Railtie < Rails::Railtie
    rake_tasks do
      load "njtransit/tasks.rb"
    end
  end
end
