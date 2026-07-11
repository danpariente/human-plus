# frozen_string_literal: true

require_relative "test_helper"

class TestHumanAssembly < Minitest::Test
  def dan
    Human.assemble do
      program :fear, level: 100,
              triggered_by: ["uncertainty", "the future"],
              thoughts: ["Something bad will happen"],
              respond_with: :flee
      program :anger, level: 150,
              triggered_by: ["obstacle", "injustice", "the future"],
              thoughts: ["How dare they"],
              respond_with: :attack
    end
  end

  def test_assembly_installs_programs_as_real_methods
    h = dan
    assert h.respond_to?(:fear)
    assert h.respond_to?(:anger)
    assert_instance_of Feeling, h.fear
    assert_equal :fear, h.fear.name
  end

  def test_levels_can_be_named_after_the_map
    h = Human.assemble do
      program :dread, level: :fear, triggered_by: ["x"], respond_with: :freeze_up
    end
    assert_equal 100, h.dread.level
  end

  def test_experience_fires_the_matching_program
    assert_equal :attack, dan.experience("an obstacle in the road")
  end

  def test_experience_returns_the_reaction_and_records_the_response
    h = dan
    assert_equal :flee, h.experience("uncertainty ahead")
    assert_equal :fear, h.last_response.name
    assert Response === h.last_response # a Response IS a Feeling
  end

  def test_the_lowest_level_wins_the_tie_the_strongest_pull
    # "the future" triggers both fear (100) and anger (150)
    assert_equal :flee, dan.experience("the future")
  end

  def test_experience_applies_the_coping_style
    h = dan
    h.experience("the future")
    assert_equal 11, h.fear.pressure # suppression is the factory default

    h.coping_style = :escape
    h.experience("the future")
    assert_equal 11, h.fear.pressure # avoidance changes nothing
  end

  def test_unprogrammed_stimuli_pass_through
    h = dan
    assert_nil h.experience("a sunset")
    assert_nil h.last_response
  end

  def test_surrender_is_not_a_coping_style
    assert_raises(ArgumentError) { dan.coping_style = :surrender }
  end

  def test_a_program_may_not_calibrate_at_courage_or_above
    assert_raises(ArgumentError) do
      Human.assemble { program :bravado, level: 200, respond_with: :posture }
    end
  end

  def test_a_state_may_not_calibrate_below_courage
    assert_raises(ArgumentError) do
      Human.assemble { state :worry, level: 100, respond_with: :fret }
    end
  end

  def test_a_state_cannot_have_triggers_or_pressure
    assert_raises(ArgumentError) do
      Human.assemble { state :love, level: 500, triggered_by: ["the beloved"], respond_with: :give_freely }
    end
    assert_raises(ArgumentError) do
      Human.assemble { state :love, level: 500, pressure: 10, respond_with: :give_freely }
    end
  end

  def test_calibration_is_the_pressure_weighted_mean
    # fear 100 and anger 150, equal pressure => 125
    assert_equal 125, dan.calibration
  end
end
