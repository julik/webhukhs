# frozen_string_literal: true

# Accepts anything and takes the event id from the payload, when there is one
class AcmeHandler < Webhukhs::BaseHandler
  def process(received_webhook)
    Rails.logger.info { "AcmeHandler processed #{received_webhook.body.bytesize} bytes" }
  end

  def extract_event_id_from_request(action_dispatch_request)
    JSON.parse(action_dispatch_request.body.read).fetch("id")
  rescue JSON::ParserError, KeyError, TypeError
    super
  ensure
    action_dispatch_request.body.rewind
  end
end
