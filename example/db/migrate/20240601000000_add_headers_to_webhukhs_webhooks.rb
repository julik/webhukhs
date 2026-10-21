# frozen_string_literal: true

class AddHeadersToWebhukhsWebhooks < ActiveRecord::Migration[7.0]
  def change
    add_column :received_webhooks, :request_headers, :json, null: true
  end
end
