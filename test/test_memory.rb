# frozen_string_literal: true

require_relative "test_helper"

class TestMemory < Minitest::Test
  ABSENCE = "your partner doesn't text back — the absence of the beloved"

  def test_experiences_are_filed_under_their_apparent_source
    town = Town.new(nil).settle("ann").settle("bob")
    town.incite("criticism lands on a mistake")
    town.tick # the world: shame, both
    town.tick # each other's hide: love clings

    ann = town.residents.first.memory
    assert(ann.moments.any? { |m| m.actor == "the world" && m.feeling == :shame })
    assert_equal 1, ann.against("bob") # tick 2 got filed under bob
    assert_equal 0, ann.against("ann") # never under oneself
    assert_equal({ "bob" => 1 }, ann.grudges) # the world doesn't make the ledger
  end

  def test_a_grudge_is_attributed_pressure_and_dissolves_with_the_program
    town = Town.new(nil).settle("ann").settle("bob")
    town.converse("ann", "bob", ABSENCE, turns: 6)
    ann = town.residents.first

    held = ann.memory.against("bob")
    assert_operator held, :>, 0 # the argument was filed under bob

    ann.human.surrender(:fear) # what bob's tones kept firing
    assert_equal 0, ann.memory.against("bob") # the charge dissolves with the program...
    refute_empty ann.memory.moments # ...but nothing is forgotten
  end

  def test_attention_goes_to_the_one_you_hold_the_most_against
    grudged, indifferent = [true, false].map do |holds_grudge|
      town = Town.new(nil).settle("watcher").settle("bob").settle("cal")
      town.residents.first.memory.file("cal", "an old wound", :fear, 5) if holds_grudge
      town.incite("thinking about the future")
      town.tick # everyone flees — filed under the world

      # tick 2: watcher hears two identical :flee tones, bob's and cal's.
      town.tick.grep(Town::Reacted).find { |e| e.actor == "watcher" }.witnessed.actor
    end

    assert_equal "cal", grudged      # equal pulls — resentment steers attention
    assert_equal "bob", indifferent  # without the grudge, first heard wins
  end

  def test_reflection_names_the_scapegoat
    town = Town.new(nil).settle("ann").settle("carol", awareness: 12_000)
    events = town.converse("ann", "carol", "thinking about the future", turns: 8)

    insight = events.grep(Town::Reflected).first.insight
    assert_match(/the fear is the program, not the world; it was never about ann/, insight)
  end

  def test_an_escaper_stores_nothing_and_blames_no_one
    escaper = NPC.new
    escaper.coping_style = :escape
    town = Town.new(nil).settle("ann", human: escaper).settle("bob")
    town.run("thinking about the future", ticks: 4)

    ann = town.residents.first.memory
    refute_empty ann.moments # the moments are filed...
    assert_equal 0, ann.against("bob") # ...but avoidance charges nothing
    assert_nil ann.scapegoat(:fear)
  end
end
