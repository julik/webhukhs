# frozen_string_literal: true

Rails.application.routes.draw do
  mount Webhukhs::Engine, at: "/webhooks", as: "webhooks"
  # In a real app this goes behind authentication - see the README
  mount Webhukhs::Admin::Engine, at: "/admin/webhukhs"
  root to: redirect("/admin/webhukhs")
end
