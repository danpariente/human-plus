# frozen_string_literal: true

require_relative "test_helper"

class TestMind < Minitest::Test
  def human(pressure: 10)
    Human.assemble do
      program :fear, level: 100,
              triggered_by: ["the future"],
              thoughts: ["Something bad will happen", "I am not safe"],
              respond_with: :flee, pressure: pressure
      program :anger, level: 150,
              triggered_by: ["obstacle"],
              thoughts: ["How dare they"],
              respond_with: :attack, pressure: pressure
    end
  end

  def test_thoughts_derive_from_the_feeling_seeds
    first = human.mind.thoughts(:fear).first(2)
    assert_equal ["Something bad will happen", "I am not safe"], first
  end

  def test_one_suppressed_feeling_spawns_thousands_of_thoughts
    assert_equal 10 * 1_000, human.mind.thoughts(:fear).count
    assert_equal 3 * 1_000, human(pressure: 3).mind.thoughts(:fear).count
  end

  def test_the_stream_runs_dry_when_the_feeling_runs_out
    h = human
    h.fear.surrender! until h.fear.run_out?
    assert_empty h.mind.thoughts(:fear).first(5)
  end

  def test_a_surrendered_program_leaves_the_mind_quiet
    h = human
    h.surrender(:fear)
    assert_empty h.mind.thoughts(:fear).first(5)
  end

  def test_chatter_interleaves_across_pressurized_programs
    noise = human.mind.chatter.first(4)
    assert_includes noise, "Something bad will happen"
    assert_includes noise, "How dare they"
  end

  # The direction of causation, as a test: feelings generate thoughts and
  # never the reverse. The Mind's entire public surface is two read-only
  # projections.
  def test_the_mind_cannot_cause_feelings
    assert_equal %i[chatter thoughts], Mind.instance_methods(false).sort
  end
end
