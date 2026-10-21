# frozen_string_literal: true

require_relative "boot"

require "rails"
require "active_record/railtie"
require "active_job/railtie"
require "action_controller/railtie"
require "action_view/railtie"

require "webhukhs"
require "webhukhs/admin"

# A minimal app for trying out Webhukhs and its admin by hand - see bin/dev
module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.root = File.expand_path("..", __dir__)
    config.eager_load = false
    config.consider_all_requests_local = true
    config.secret_key_base = "dummy-app-not-a-secret"
    config.hosts.clear
    config.logger = ActiveSupport::Logger.new($stdout)
    # Processes webhooks in a thread right after they arrive. Not :inline - ProcessingJob re-raises
    # what the handler raised, and would turn the sender's response into a 500
    config.active_job.queue_adapter = :async
  end
end
