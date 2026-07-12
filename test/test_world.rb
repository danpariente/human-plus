# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "net/http"

class TestWorld < Minitest::Test
  def world
    town = Town.new(nil).settle("ann").settle("bob")
    Town::World.new(town, stimuli: ["thinking about the future"].cycle)
  end

  def test_residents_take_their_places
    state = world.state
    state[:residents].each do |r|
      assert_operator r[:x], :>=, 0
      assert_operator r[:x], :<=, Town::World::SIZE[:w]
      assert_equal :wandering, r[:state]
    end
    assert_equal Town::World::SIZE[:w], state[:map][:w]
  end

  def test_the_town_walks
    w = world
    w.place("ann", 2, 2).place("bob", 30, 18) # far apart: nobody meets yet
    before = w.state[:residents].map { |r| [r[:x], r[:y]] }
    6.times { w.step }
    after = w.state[:residents].map { |r| [r[:x], r[:y]] }
    refute_equal before, after
  end

  def test_a_meeting_becomes_a_conversation_and_plays_out
    w = world
    w.place("ann", 10, 10).place("bob", 11, 10)
    w.step

    state = w.state
    assert_equal [%w[ann bob]], state[:encounters]
    assert(state[:residents].all? { |r| r[:state] == :conversing })
    assert(state[:feed].any? { |line| line.include?("ann and bob meet") })

    60.times { w.step } # six turns of dialogue at four steps a line, then parting
    state = w.state
    assert_empty state[:encounters]
    assert(state[:residents].all? { |r| r[:state] == :wandering })
    assert(state[:feed].any? { |line| line.include?("Something bad will happen") }) # the Mind, aloud
    assert(state[:feed].any? { |line| line.include?("part, carrying it with them") })

    # the conversation was real: expression accumulated and got filed
    ann = w.state[:residents].find { |r| r[:name] == "ann" }
    assert_operator ann[:pressure], :>, 90
    assert_operator ann[:grudges].fetch("bob", 0), :>, 0
  end

  def test_you_can_hand_them_the_opener
    w = world
    w.incite("a traffic jam is an obstacle")
    w.place("ann", 10, 10).place("bob", 11, 10)
    w.step
    assert(w.state[:feed].any? { |line| line.include?(%(the world offers: "a traffic jam is an obstacle")) })
  end

  def test_the_window_serves_the_walking_world
    w = world
    port = w.serve(0)
    page = Net::HTTP.get_response(URI("http://127.0.0.1:#{port}/"))
    assert_includes page.body, "the world, walking"
    state = JSON.parse(Net::HTTP.get_response(URI("http://127.0.0.1:#{port}/state")).body)
    assert_equal 2, state["residents"].size
    assert state["residents"].first.key?("x")
  ensure
    w.stop
  end
end
