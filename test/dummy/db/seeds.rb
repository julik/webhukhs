# frozen_string_literal: true

# A spread of webhooks to look at: every status, JSON and not, and enough rows to paginate.
# insert_all, so that the status callbacks do not enqueue (and process) anything

def headers_for(service_id, content_type)
  {
    "CONTENT_TYPE" => content_type,
    "HTTP_HOST" => "localhost:3000",
    "HTTP_USER_AGENT" => "#{service_id.capitalize}-Webhooks/2.1",
    "HTTP_X_REQUEST_ID" => SecureRandom.uuid,
    "REMOTE_ADDR" => "203.0.113.7",
    "REQUEST_METHOD" => "POST",
    "action_dispatch.request.path_parameters" => {"service_id" => service_id}
  }
end

handlers = {"acme" => "AcmeHandler", "signed" => "SignedHandler", "flaky" => "FlakyHandler"}
statuses = %w[processed processed processed processed received processing skipped error failed_validation]
events = %w[invoice.paid invoice.created customer.updated payout.failed charge.refunded]

rows = 130.times.map do |i|
  service_id = handlers.keys[i % handlers.length]
  event_id = "evt_#{SecureRandom.alphanumeric(24)}"
  received_at = (i * 37).minutes.ago
  body = {
    id: event_id,
    type: events[i % events.length],
    created: received_at.to_i,
    livemode: false,
    data: {
      object: {
        id: "in_#{SecureRandom.alphanumeric(14)}",
        amount_due: rand(100..90_000),
        currency: "eur",
        customer: {id: "cus_#{SecureRandom.alphanumeric(14)}", email: "customer#{i}@example.com"},
        lines: Array.new(i % 3 + 1) { |line| {description: "Seat #{line + 1}", quantity: 1, unit_amount: 1_200} }
      }
    }
  }.to_json

  {
    id: SecureRandom.uuid,
    handler_module_name: handlers.fetch(service_id),
    handler_event_id: event_id,
    status: statuses[i % statuses.length],
    body: body,
    request_headers: headers_for(service_id, "application/json"),
    created_at: received_at,
    updated_at: received_at + rand(1..90).seconds
  }
end

# The bodies that are not JSON at all
odd_bodies = {
  "form-encoded" => ["application/x-www-form-urlencoded", "event=invoice.paid&id=42&amount=12.50&currency=EUR"],
  "xml" => ["application/xml", %(<?xml version="1.0"?>\n<notification><event>payment</event><id>42</id></notification>)],
  "not-utf8" => ["application/octet-stream", "caf\xE9 au lait - latin-1, not UTF-8".b],
  "truncated-json" => ["application/json", '{"id": "evt_cut_short", "type": "invoice.paid", "data": {"obj']
}
odd_bodies.each_with_index do |(name, (content_type, body)), i|
  rows << {
    id: SecureRandom.uuid,
    handler_module_name: "AcmeHandler",
    handler_event_id: "odd-#{name}",
    status: "failed_validation",
    body: body,
    request_headers: headers_for("acme", content_type),
    created_at: (i + 1).minutes.ago,
    updated_at: (i + 1).minutes.ago
  }
end

Webhukhs::ReceivedWebhook.insert_all(rows)
puts "Seeded #{rows.length} webhooks"
