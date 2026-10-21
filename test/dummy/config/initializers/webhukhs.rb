# frozen_string_literal: true

Webhukhs.configure do |config|
  config.active_handlers = {
    "acme" => "AcmeHandler",
    "signed" => "SignedHandler",
    "flaky" => "FlakyHandler"
  }
end
