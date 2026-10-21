# frozen_string_literal: true

require "assiette"
require_relative "../webhukhs"
require_relative "admin/engine"
require_relative "admin/view_helper"
require_relative "admin/received_webhook_presenter"
require_relative "admin/application_controller"
require_relative "admin/received_webhooks_controller"

module Webhukhs
  # Optional, read-only admin UI for received webhooks. It is not loaded by `require "webhukhs"` -
  # require "webhukhs/admin" and mount {Webhukhs::Admin::Engine} yourself, behind your own authentication.
  module Admin
  end
end
