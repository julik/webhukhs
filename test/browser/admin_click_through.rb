# frozen_string_literal: true

require "test_helper"
require "lightpanda"
require "puma"
require "puma/server"

# Clicks through the admin in Lightpanda, so that what the request tests cannot see - the JS, assets
# resolving under the mount point - is exercised too. Lightpanda runs the JS against a real DOM, but does
# no layout, applies no CSS and does not enforce the CSP. Not part of `rake test`, run it with `rake test:browser`.
class AdminClickThrough < ActiveSupport::TestCase
  # The app answers from Puma threads with connections of their own, which would not see rows
  # created inside a test transaction
  self.use_transactional_tests = false

  PAGE_SIZE = Webhukhs::Admin::ReceivedWebhooksController::PAGE_SIZE

  def self.server
    @server ||= Puma::Server.new(WebhukhsTestApp, nil, min_threads: 0, max_threads: 4, log_writer: Puma::LogWriter.null).tap do |server|
      server.add_tcp_listener("127.0.0.1", 0)
      server.run
      Minitest.after_run { server.stop(true) }
    end
  end

  setup do
    @base_url = "http://127.0.0.1:#{self.class.server.connected_ports.first}/admin"
    @console_errors = []
    @failed_requests = []
    # Lightpanda listens on 9222 unless told otherwise
    port = TCPServer.open("127.0.0.1", 0) { |socket| socket.addr[1] }
    @browser = Lightpanda::Browser.new(port: port, timeout: 10)
    @browser.on("Runtime.consoleAPICalled") { |params| @console_errors << params["args"].map { |arg| arg["value"] }.join(" ") if params["type"] == "error" }
    @browser.on("Runtime.exceptionThrown") { |params| @console_errors << params.dig("exceptionDetails", "exception", "description").to_s }
    @browser.on("Network.responseReceived") do |params|
      status = params.dig("response", "status")
      @failed_requests << "#{status} #{params.dig("response", "url")}" if status >= 400
    end
    @browser.page_command("Runtime.enable")
    @browser.page_command("Network.enable")
  end

  teardown do
    @browser.quit
    Webhukhs::ReceivedWebhook.delete_all

    assert_empty @failed_requests, "Requests failed"
    assert_empty @console_errors, "The browser logged errors"
  end

  def create_webhook(**attributes)
    Webhukhs::ReceivedWebhook.create!(
      handler_module_name: "WebhookTestHandler",
      handler_event_id: SecureRandom.uuid,
      status: "processed",
      body: '{"event":"thing.happened"}',
      **attributes
    )
  end

  def visit(path)
    @browser.go_to(@base_url + path)
  end

  def wait_for(what, timeout: 5)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    until (result = yield)
      flunk "Timed out waiting for #{what}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      sleep 0.05
    end
    result
  end

  def js(expression)
    @browser.evaluate(expression)
  end

  def text(selector)
    js("document.querySelector(#{selector.to_json}).textContent")
  end

  def texts(selector)
    js("Array.from(document.querySelectorAll(#{selector.to_json}), (node) => node.textContent.trim())")
  end

  def count(selector)
    js("document.querySelectorAll(#{selector.to_json}).length")
  end

  def click(selector)
    js("document.querySelector(#{selector.to_json}).click()")
  end

  def click_and_wait_for_page(selector)
    url = @browser.current_url
    loaded = Concurrent::Event.new
    on_load = proc { loaded.set }
    @browser.on("Page.loadEventFired", &on_load)
    click(selector)
    flunk "Timed out waiting for #{selector} to leave #{url}" unless loaded.wait(5)
    refute_equal url, @browser.current_url
  ensure
    @browser.off("Page.loadEventFired", on_load)
  end

  test "lists, sorts, filters and pages through webhooks" do
    PAGE_SIZE.times { |i| create_webhook(handler_event_id: "evt-#{i}", created_at: i.minutes.ago) }
    create_webhook(handler_event_id: "the-failed-one", status: "error", created_at: 2.days.ago)

    visit "/received"
    assert_equal "Received webhooks", text("h1")
    # Lightpanda neither loads stylesheets nor computes styles, so we can only check that ours resolves
    stylesheet = js(<<~JS)
      fetch(document.querySelector("link[rel=stylesheet]").href).then((response) => [response.status, response.headers.get("content-type")])
    JS
    assert_equal [200, "text/css"], stylesheet
    assert_equal PAGE_SIZE, count("tbody tr")
    assert_equal "evt-0", texts("tbody tr td:nth-child(5)").first

    click_and_wait_for_page("th a[href*='sort=created_at']")
    assert_includes @browser.current_url, "direction=asc"
    assert_equal "the-failed-one", texts("tbody tr td:nth-child(5)").first

    js(<<~JS)
      const select = document.querySelector("select[name=status]")
      select.value = "error"
      select.dispatchEvent(new Event("change", {bubbles: true}))
    JS
    assert_equal "error", js("document.querySelector('select[name=status]').value")
    click_and_wait_for_page("form.filters input[type=submit]")
    assert_equal ["the-failed-one"], texts("tbody tr td:nth-child(5)")
    # The sort survives filtering
    assert_includes @browser.current_url, "direction=asc"

    click_and_wait_for_page("form.filters a")
    assert_equal "Any status", js("document.querySelector('select[name=status]').selectedOptions[0].text")

    click_and_wait_for_page("a[rel=next]")
    assert_equal 1, count("tbody tr")
    click_and_wait_for_page("a[rel=prev]")
    assert_equal PAGE_SIZE, count("tbody tr")
  end

  test "opens a webhook from its row" do
    webhook = create_webhook(handler_event_id: "evt-clicked")

    visit "/received"
    # Lightpanda does no layout, so it cannot tell whether the stretched link really covers the row
    click_and_wait_for_page("tbody tr .row-link")

    assert @browser.current_url.end_with?("/received/#{webhook.id}"), @browser.current_url
    assert_includes text("h1"), "WebhookTestHandler"
  end

  test "switches between the pretty and the as-sent body" do
    webhook = create_webhook(body: '{"event":"thing.happened","data":{"id":1}}')

    visit "/received/#{webhook.id}"
    pretty = -> { js("document.getElementById('body-pretty').hidden") == false }
    raw = -> { js("document.getElementById('body-raw').hidden") == false }
    assert pretty.call
    refute raw.call

    click("#body-tab-raw")
    wait_for("the as-sent tab") { raw.call }
    refute pretty.call
    assert_equal "true", js("document.getElementById('body-tab-raw').getAttribute('aria-selected')")
    assert_equal '{"event":"thing.happened","data":{"id":1}}', text("#body-raw code")

    js(<<~JS)
      const tab = document.getElementById("body-tab-raw")
      tab.focus()
      tab.dispatchEvent(new KeyboardEvent("keydown", {key: "ArrowLeft", bubbles: true}))
    JS
    wait_for("the arrow key to go back to the pretty tab") { pretty.call }
    assert_equal "body-tab-pretty", js("document.activeElement.id")
  end

  test "copies to the clipboard" do
    webhook = create_webhook(handler_event_id: "evt-to-copy")

    visit "/received/#{webhook.id}"
    # Lightpanda has no clipboard, so we only check that the right text gets handed to one
    js(<<~JS)
      Object.defineProperty(navigator, "clipboard", {value: {writeText: (text) => { window.copied = text; return Promise.resolve() }}})
    JS

    click("button.btn-copy[data-copy='evt-to-copy']")
    wait_for("the copy button to flash") { count("button.btn-copy.copied[data-copy='evt-to-copy']") == 1 }
    assert_equal "evt-to-copy", js("window.copied")

    click("button.btn-copy-panel")
    wait_for("the body to be copied") { js("window.copied") != "evt-to-copy" }
    assert_equal JSON.pretty_generate({"event" => "thing.happened"}), js("window.copied")
  end

  test "shows bodies that are not JSON, or too large to display" do
    form = create_webhook(body: "event=paid&amount=12.50")
    large = create_webhook(body: "x" * (Webhukhs::Admin::ReceivedWebhookPresenter::DISPLAY_LIMIT + 1))

    visit "/received/#{form.id}"
    assert_equal "This body is not valid JSON, so it is shown as it was sent", text(".flash.alert")
    assert_equal "event=paid&amount=12.50", text("pre.body-raw code")
    assert_equal 0, count("[role=tab]")

    visit "/received/#{large.id}"
    assert_equal "The body was 256 KB, display is truncated", text(".flash.alert")
  end

  test "picks up new webhooks while auto-refresh is on, and remembers the switch" do
    create_webhook(handler_event_id: "evt-before")

    visit "/received"
    switch = -> { js("document.getElementById('auto-refresh').checked") }
    refute switch.call
    click("#auto-refresh")
    wait_for("the switch to turn on") { switch.call }

    create_webhook(handler_event_id: "evt-arrived")
    # One poll interval, with some slack
    wait_for("the new webhook to show up", timeout: 8) { texts("tbody tr td:nth-child(5)").include?("evt-arrived") }
    assert_equal ["evt-arrived", "evt-before"], texts("tbody tr td:nth-child(5)")

    visit "/received"
    assert switch.call, "The switch should stay on after a reload"
    # After a page load only the timer refetches, so this one has to come in through a poll
    create_webhook(handler_event_id: "evt-polled")
    wait_for("the polled webhook to show up", timeout: 8) { texts("tbody tr td:nth-child(5)").include?("evt-polled") }
    click("#auto-refresh")
    wait_for("the switch to turn off") { !switch.call }
  end
end
