# frozen_string_literal: true

# Fails to process every webhook, and ends up in `error`
class FlakyHandler < Webhukhs::BaseHandler
  def process(received_webhook)
    raise "Upstream said no to #{received_webhook.handler_event_id}"
  end
end
