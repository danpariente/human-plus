# frozen_string_literal: true

require_relative "test_helper"

class TestConversation < Minitest::Test
  ABSENCE = "your partner doesn't text back — the absence of the beloved"

  def town
    Town.new(nil).settle("ann").settle("bob")
  end

  def test_a_conversation_is_two_programs_talking_to_each_other
    spoke = town.converse("ann", "bob", ABSENCE, turns: 4).grep(Town::Spoke)

    assert_equal %w[ann bob ann bob], spoke.map(&:speaker)
    assert_equal :love, spoke[0].feeling
    assert_equal "Don't leave me", spoke[0].line # the Mind, said aloud
    assert_equal :anger, spoke[1].feeling # bob responds to the tone (an obstacle), not the words
    assert_equal "How dare they", spoke[1].line
    assert_equal :fear, spoke[2].feeling # an attack is a threat; the argument runs downhill
  end

  def test_the_listener_hears_the_tone_not_the_words
    spoke = town.converse("ann", "bob", ABSENCE, turns: 2).grep(Town::Spoke)
    assert_match(/holds on too tightly/, spoke[0].heard_as)
    refute_includes spoke[0].heard_as, spoke[0].line # the words don't travel; the feeling does
  end

  def test_speaking_is_expression_and_the_pressure_rises
    t = town
    before = t.residents.sum { |r| r.human.programs.sum(&:pressure) }
    t.converse("ann", "bob", ABSENCE, turns: 6)

    # experience suppresses, speaking expresses — both accumulate. Venting
    # relieves just enough of the pressure to let the rest be suppressed.
    assert_operator t.residents.sum { |r| r.human.programs.sum(&:pressure) }, :>, before
  end

  def test_successive_lines_advance_the_minds_stream
    fear_lines = town.converse("ann", "bob", "thinking about the future", turns: 5)
                     .grep(Town::Spoke).select { |s| s.speaker == "ann" && s.feeling == :fear }
                     .map(&:line)
    assert_equal ["Something bad will happen", "I am not safe", "What if it's true — Something bad will happen?"],
                 fear_lines # the mind rarely says a thing once, or the same way twice
  end

  def test_an_aware_resident_reflects_mid_argument_and_falls_silent
    t = Town.new(nil).settle("ann").settle("carol", awareness: 12_000)
    events = t.converse("ann", "carol", "thinking about the future", turns: 8)

    reflection = events.grep(Town::Reflected).first
    assert_equal "carol", reflection.actor
    assert_equal :fear, reflection.feeling
    assert_equal Town::FellSilent.new("carol"), events.last # the next tone finds no hook
    assert_operator t.residents.first.human.fear.pressure, :>, 12 # ann is still carrying it
  end

  def test_talk_to_the_emancipated_and_the_argument_finds_no_grip
    saint = NPC.new
    saint.programs.map(&:name).each { |name| saint.surrender(name) }
    t = Town.new(nil).settle("ann").settle("saint", human: saint)

    events = t.converse("ann", "saint", ABSENCE, turns: 8)
    spoke = events.grep(Town::Spoke)

    assert_equal 2, spoke.size # one cling, one answer, then quiet
    assert_equal [:love, :love], spoke.map(&:feeling) # the same name, 375 levels apart
    assert_equal 500, spoke[1].level
    assert_equal "Nothing needs to happen", spoke[1].line # a state speaks its few words directly
    assert_equal 0, spoke[1].pressure # and nothing accumulates
    assert_equal Town::FellSilent.new("ann"), events.last # nothing left to grip
  end

  def test_turns_bound_the_argument
    assert_operator town.converse("ann", "bob", ABSENCE, turns: 3).grep(Town::Spoke).size, :<=, 3
  end

  def test_you_cannot_converse_with_the_unsettled
    assert_raises(ArgumentError) { town.converse("ann", "nobody", ABSENCE) }
  end
end
