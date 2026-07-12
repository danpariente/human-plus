# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "net/http"

class TestSquare < Minitest::Test
  def square
    town = Town.new(nil).settle("ann").settle("bob").settle("carol", awareness: 12_000)
    Town::Square.new(town, stimuli: ["thinking about the future"].cycle)
  end

  def test_the_world_incites_when_quiet_and_the_loop_ticks_when_not
    sq = square
    sq.step # quiet: the world speaks
    state = sq.state
    assert_equal 0, state[:tick]
    assert_equal "thinking about the future", state[:stimulus]
    assert_equal [{ actor: "the world", reaction: nil, text: "thinking about the future" }], state[:air]

    sq.step # now there is something to react to
    state = sq.state
    assert_equal 1, state[:tick]
    ann = state[:residents].first
    assert_equal "reacted", ann[:last][:kind]
    assert_equal :fear, ann[:last][:feeling]
    assert_equal "the world", ann[:last][:at]
  end

  def test_the_state_carries_the_whole_town
    sq = square
    3.times { sq.step } # incite, tick, tick — carol reflects on the second tick
    state = sq.state

    assert_equal({ name: "carol" }, { name: state[:reflections].first[:name] })
    carol = state[:residents].last
    assert_equal 8, carol[:programs] # fear is gone
    assert carol[:aware]
    refute carol[:emancipated]
    assert_operator state[:residents].first[:grudges].values.sum, :>, 0
    assert(state[:feed].any? { |line| line.include?("reflects") })
  end

  def test_a_watcher_can_pause_and_incite
    sq = square
    sq.control("pause")
    refute sq.state[:running]
    sq.control("resume")
    assert sq.state[:running]

    sq.incite("a traffic jam is an obstacle")
    assert_equal "a traffic jam is an obstacle", sq.state[:stimulus]
    sq.incite("")
    assert_equal "a traffic jam is an obstacle", sq.state[:stimulus] # empty words change nothing
  end

  def test_the_window_serves_the_page_and_the_state
    sq = square
    port = sq.serve(0)
    base = "http://127.0.0.1:#{port}"

    page = Net::HTTP.get_response(URI("#{base}/"))
    assert_equal "200", page.code
    assert_includes page.body, "the town, alive"
    assert_includes page.body, "programs flicker; states are still"

    Net::HTTP.post_form(URI("#{base}/incite"), "stimulus" => "criticism lands on a mistake")
    state = JSON.parse(Net::HTTP.get_response(URI("#{base}/state")).body)
    assert_equal "criticism lands on a mistake", state["stimulus"]
    assert_equal "the world", state["air"].first["actor"]

    Net::HTTP.post_form(URI("#{base}/control"), "action" => "step")
    state = JSON.parse(Net::HTTP.get_response(URI("#{base}/state")).body)
    assert_equal 1, state["tick"]
    assert_equal "hide", state["residents"].first["last"]["reaction"]

    lost = Net::HTTP.get_response(URI("#{base}/nowhere"))
    assert_equal "404", lost.code
  ensure
    sq.stop
  end
end
