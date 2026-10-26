# frozen_string_literal: true

# Refuses anything without the right signature header, and ends up in `failed_validation`
class SignedHandler < Webhukhs::BaseHandler
  SECRET = "example-secret"

  def valid?(action_dispatch_request)
    action_dispatch_request.headers["X-Signature"] == SECRET
  end
end
