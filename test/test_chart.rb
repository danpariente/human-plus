# frozen_string_literal: true

require_relative "test_helper"
require "json"

class TestChart < Minitest::Test
  def charted_run(stimulus = "thinking about the future", ticks: 4)
    town = Town.new(nil).settle("ann").settle("carol", awareness: 12_000)
    chart = Town::Chart.new(town, stimulus)
    town.run(stimulus, ticks: ticks) { |n, events| chart.record(n, events) }
    chart
  end

  def test_every_tick_is_sampled_from_tick_zero
    chart = charted_run
    data = chart.data
    assert_equal 0, data[:ticks].first # the starting state, before the world speaks
    assert_equal data[:ticks].size, data[:calibration]["ann"].size
    assert_equal data[:ticks].size, data[:pressure]["carol"].size
    assert_equal 94, data[:calibration]["ann"].first # the Common Human baseline
  end

  def test_reflections_and_grudges_make_the_page_data
    data = charted_run.data
    reflection = data[:reflections].first
    assert_equal "carol", reflection[:name]
    assert_equal :fear, reflection[:feeling]
    assert(data[:grudges].any? { |g| g[:holder] == "ann" && g[:against] == "carol" })
    refute_empty data[:transcript].first[:lines]
  end

  def test_the_page_is_self_contained
    html = charted_run.to_html
    assert html.start_with?("<!doctype html>")
    assert_includes html, "const DATA = " # the run travels with the page
    assert_includes html, "prefers-color-scheme: dark" # dark mode is selected, not flipped
    assert_includes html, "table-view" # nothing readable by color alone
    # No network, no dependencies — the w3 namespace URI is an identifier, not a fetch.
    refute_match(/\bsrc=|<link|href=|@import|fetch\(/, html)
  end

  def test_a_stimulus_cannot_escape_the_page
    chart = charted_run(%(</script><script>alert("obstacle")</script>))
    html = chart.to_html
    refute_includes html, "</script><script>alert" # neither in the JSON...
    assert_includes html, "&lt;/script&gt;" # ...nor in the header
  end
end
