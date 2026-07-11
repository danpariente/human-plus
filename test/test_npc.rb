# frozen_string_literal: true

require_relative "test_helper"

class TestNPC < Minitest::Test
  def test_the_default_human_is_an_npc
    npc = Human.default
    assert_instance_of NPC, npc
    assert_operator NPC, :<, Human # an NPC is just a Human that never chose its programs
    assert_predicate npc, :npc?
  end

  def test_the_firmware_installs_the_common_human_program_set
    npc = NPC.new
    assert_equal %i[shame guilt apathy grief fear desire love anger pride],
                 npc.programs.map(&:name)
    assert npc.respond_to?(:fear)
    assert_equal 10, npc.fear.pressure
  end

  def test_the_common_human_love_is_attachment_dependency_possessiveness
    love = NPC.new.love
    assert_equal 125, love.level # calibrates at Desire, not Love (500)
    assert_equal :cling, love.reaction
    assert_includes love.thought_seeds, "I can't live without you"
    refute_predicate love, :unconditional? # it needs the beloved
  end

  def test_an_npc_calibrates_below_courage
    assert_operator NPC.new.calibration, :<, 200
  end

  def test_the_factory_coping_style_is_suppression
    assert_equal :suppression, NPC.new.coping_style
  end

  def test_the_full_pathway_from_npc_to_emancipation
    npc = NPC.new
    npc.programs.map(&:name).each { |name| npc.surrender(name) }

    assert_predicate npc, :emancipated?
    refute_predicate npc, :npc?
    assert_equal 500, npc.calibration
    assert_equal %i[love], npc.states.map(&:name)
    assert_nil npc.experience("criticism lands on a mistake") # nothing left hooks
  end
end
