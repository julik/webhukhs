# frozen_string_literal: true

# What `bin/rails g webhukhs:install` generates, with UUID ids as most apps would use them
ActiveRecord::Schema.define(version: 1) do
  create_table "received_webhooks", id: :string, force: :cascade do |t|
    t.string "handler_event_id", null: false
    t.string "handler_module_name", null: false
    t.string "status", default: "received", null: false
    t.binary "body", null: false
    t.json "request_headers"
    t.timestamps
    t.index ["handler_module_name", "handler_event_id"], name: "webhook_dedup_idx", unique: true
    t.index ["status"]
  end
end
