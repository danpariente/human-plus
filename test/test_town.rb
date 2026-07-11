# frozen_string_literal: true

require_relative "test_helper"

class TestTown < Minitest::Test
  # A narrator that witnesses every reaction as something with no trigger
  # in it — the duck that documents the seam.
  class SunsetNarrator
    def witness(_actor, _reaction) = "a sunset"
  end

  def two_npcs
    Town.new(nil).settle("ann").settle("bob")
  end

  def test_the_census_settles_the_default_cast
    town = Town.new
    assert_equal %w[alice bea carol], town.residents.map(&:name)
    assert town.residents.all? { |r| r.human.npc? } # everyone ships with the firmware
    refute_predicate town.residents.first, :aware?
    assert_equal 12_000, town.residents.last.awareness # carol notices, eventually
  end

  def test_every_firmware_reaction_can_be_witnessed
    narrator = Town::Narrator.new
    NPC.new.programs.each do |p|
      refute_nil narrator.witness("alice", p.reaction), "no perception row for :#{p.reaction}"
    end
    assert_match(/\Aalice lashes out/, narrator.witness("alice", :attack))
  end

  def test_a_reaction_becomes_the_next_ticks_stimulus
    town = two_npcs
    town.incite("criticism lands on a mistake")

    first = town.tick
    assert first.all? { |e| Town::Reacted === e && e.reaction == :hide } # shame, both

    second = town.tick # each hide is witnessed as absence of the beloved
    assert_equal %i[cling cling], second.grep(Town::Reacted).map(&:reaction)
    assert_equal "bob", second.first.witnessed.actor # ann reacts to bob's hide, never her own
  end

  def test_attention_follows_the_strongest_pull
    town = Town.new(nil)
    town.settle("watcher")
    town.settle("a", human: Human.assemble { program :anger, level: 150, triggered_by: ["x"], respond_with: :attack })
    town.settle("b", human: Human.assemble { program :pride, level: 175, triggered_by: ["x"], respond_with: :inflate })
    town.incite("x")
    town.tick

    # In the air: a's :attack (a threat — fear, 100) and b's :inflate (a
    # comparison — pride, 175). The lower calibration is the stronger pull.
    reacted = town.tick.grep(Town::Reacted).find { |e| e.actor == "watcher" }
    assert_equal :fear, reacted.feeling
    assert_equal :flee, reacted.reaction
    assert_equal "a", reacted.witnessed.actor
  end

  # The Narrator is the seam where a generative Mind slots in: anything
  # answering witness(actor, reaction) -> String narrates the town.
  def test_the_narrator_is_the_seam
    town = Town.new(nil, narrator: SunsetNarrator.new).settle("ann").settle("bob")
    town.incite("a traffic jam is an obstacle")
    town.tick # both attack

    assert town.tick.all? { |e| Town::Unmoved === e } # attacks witnessed as sunsets hook nothing
    assert_predicate town, :quiet?
  end

  def test_a_reflective_resident_surrenders_what_it_notices
    town = Town.new(nil).settle("ann").settle("carol", awareness: 12_000)
    town.incite("thinking about the future") # fear fires for both: pressure 11
    town.tick

    events = town.tick # each flee is witnessed as a threat: pressure 12 — carol's threshold
    reflection = events.grep(Town::Reflected).first
    assert_equal "carol", reflection.actor
    assert_equal :fear, reflection.feeling
    assert_match(/12,000 thoughts/, reflection.insight)
    refute reflection.waves.empty?

    refute town.residents.last.human.respond_to?(:fear) # the program is gone
    assert_operator town.residents.first.human.fear.pressure, :>=, 12 # ann keeps running it
  end

  def test_a_state_radiates_and_the_cascade_dies
    saint = NPC.new
    saint.programs.map(&:name).each { |name| saint.surrender(name) }
    town = Town.new(nil).settle("ann").settle("saint", human: saint)
    town.incite("a sunset")

    first = town.tick
    assert(first.any? { |e| Town::Radiated === e && e.reaction == :give_freely })
    assert(first.any? { |e| Town::Unmoved === e && e.actor == "ann" })

    second = town.tick # ann witnesses warmth given freely, needing nothing
    assert_equal [Town::Unmoved.new("ann")], second # no trigger in it
    assert_predicate town, :quiet? # the cascade dies at the saint's doorstep
  end

  def test_among_npcs_the_pressure_never_leaves_the_town
    town = two_npcs
    total = ->(t) { t.residents.sum { |r| r.human.programs.sum(&:pressure) } }
    before = total.(town)

    town.run("a traffic jam is an obstacle", ticks: 6)

    refute_predicate town, :quiet? # every reaction is somebody's trigger
    assert_operator total.(town), :>, before # coping accumulates; nothing releases
  end
end
