# frozen_string_literal: true

require_relative "test_helper"

class TestLettingGo < Minitest::Test
  def dan
    Human.assemble do
      program :fear, level: 100,
              triggered_by: ["the future"],
              thoughts: ["Something bad will happen"],
              respond_with: :flee
      program :love, level: 125, # attachment, dependency, possessiveness
              triggered_by: ["the beloved"],
              thoughts: ["Don't leave me"],
              respond_with: :cling
    end
  end

  def test_surrender_empties_the_pressure_and_removes_the_method
    h = dan
    waves = []
    h.surrender(:fear) { |wave, remaining| waves << [wave, remaining] }

    assert_equal 10, waves.sum(&:first)
    assert_equal 0, waves.last.last
    refute h.respond_to?(:fear)
    assert_nil h.experience("the future") # the stimulus no longer finds a hook
  end

  def test_a_surrendered_program_raises_a_didactic_error
    h = dan
    h.surrender(:fear)
    error = assert_raises(NoMethodError) { h.fear }
    assert_match(/no longer runs the `fear` program/, error.message)
    assert_match(/ri HumanPlus::Human#surrender/, error.message)
  end

  def test_resisting_mid_session_resets_the_session
    h = dan
    resisted = false
    waves = []
    h.surrender(:fear) do |wave, _remaining|
      waves << wave
      unless resisted
        h.fear.suppress! # you cannot let go while resisting
        resisted = true
      end
    end

    assert resisted
    assert_operator waves.sum, :>, 10 # the reset cost real progress
    refute h.respond_to?(:fear) # but the pathway still ends in release
  end

  def test_you_cannot_surrender_what_you_do_not_carry
    error = assert_raises(ArgumentError) { dan.surrender(:jealousy) }
    assert_match(/not installed/, error.message)
  end

  def test_you_cannot_surrender_twice
    h = dan
    h.surrender(:fear)
    error = assert_raises(ArgumentError) { h.surrender(:fear) }
    assert_match(/already surrendered/, error.message)
  end

  def test_emancipation_flips_only_when_the_last_program_goes
    h = dan
    refute_predicate h, :emancipated?
    h.surrender(:fear)
    refute_predicate h, :emancipated?
    h.surrender(:love)
    assert_predicate h, :emancipated?
  end

  def test_emancipation_redefines_love
    h = dan
    assert_equal 125, h.love.level
    assert_equal :cling, h.love.reaction
    refute_predicate h.love, :unconditional?

    h.surrender(:fear)
    h.surrender(:love)

    assert h.respond_to?(:love) # reinstalled — but as something else entirely
    assert_equal 500, h.love.level
    assert_equal :give_freely, h.love.reaction
    assert_predicate h.love, :unconditional?
    assert_predicate h.love, :state?
  end

  def test_a_state_cannot_be_surrendered
    h = dan
    h.surrender(:fear)
    h.surrender(:love)
    error = assert_raises(ArgumentError) { h.surrender(:love) }
    assert_match(/state/, error.message)
    assert h.respond_to?(:love) # still there — nothing to empty
  end

  def test_emancipation_cannot_be_shortcut
    error = assert_raises(ArgumentError) { dan.emancipate! }
    assert_match(/through, not around/, error.message)
  end

  def test_calibration_climbs_past_courage_on_emancipation
    h = dan
    assert_operator h.calibration, :<, 200
    h.surrender(:fear)
    h.surrender(:love)
    assert_equal 500, h.calibration
  end
end
