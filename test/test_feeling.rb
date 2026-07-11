# frozen_string_literal: true

require_relative "test_helper"

class TestFeeling < Minitest::Test
  def fear(pressure: 10)
    Feeling.new(
      name: :fear, level: 100,
      triggered_by: ["uncertainty", "the future"],
      thoughts: ["Something bad will happen", "I am not safe"],
      respond_with: :flee, pressure: pressure
    )
  end

  # The identity is a spec, not a slogan.
  def test_feelings_are_programs_are_responses
    assert Program.equal?(Feeling)
    assert Response.equal?(Feeling)
  end

  def test_suppression_accumulates_pressure
    f = fear
    f.suppress!
    assert_equal 11, f.pressure
  end

  def test_expression_is_net_suppression
    f = fear
    f.express!
    assert_equal 11, f.pressure
  end

  def test_escape_changes_nothing
    f = fear
    f.escape!
    assert_equal 10, f.pressure
  end

  def test_all_three_coping_mechanisms_count_as_resistance
    f = fear
    f.suppress!
    f.express!
    f.escape!
    assert_equal 3, f.resistance_count
  end

  def test_surrender_releases_in_waves_until_run_out
    f = fear
    released = 0
    released += f.surrender! until f.run_out?
    assert_equal 10, released
    assert_predicate f, :run_out?
    assert_equal 0, f.surrender! # nothing left to release
  end

  def test_waves_are_one_to_three
    f = fear(pressure: 151) # more than fifty maximal waves can drain
    50.times do
      wave = f.surrender!
      assert_includes 1..3, wave
    end
  end

  def test_the_program_state_split_is_at_courage
    assert_predicate fear, :program?
    love = Feeling.new(name: :love, level: 500, respond_with: :give_freely, pressure: 0)
    assert_predicate love, :state?
    refute_predicate love, :program?
  end

  def test_unconditional_means_no_triggers
    love = Feeling.new(name: :love, level: 500, respond_with: :give_freely, pressure: 0)
    assert_predicate love, :unconditional?
    refute_predicate fear, :unconditional?
  end

  def test_triggering_is_substring_match
    assert fear.triggered_by?("thinking about the future")
    refute fear.triggered_by?("a sunset")
  end
end
