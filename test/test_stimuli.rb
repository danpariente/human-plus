# frozen_string_literal: true

require "csv"
require_relative "test_helper"

##
# CSV-driven: each row of data/stimuli.csv becomes a test method —
# define_method'd, of course; the tests are assembled the way humans are.
class TestStimuli < Minitest::Test
  STIMULI = File.expand_path("../data/stimuli.csv", __dir__)

  CSV.read(STIMULI, headers: true).each_with_index do |row, i|
    stimulus = row["stimulus"]
    expected_feeling = row["expected_feeling"]
    expected_thought = row["expected_thought"]
    expected_response = row["expected_response"]

    if expected_feeling.nil?
      define_method("test_stimulus_#{i}_passes_through_unprogrammed") do
        assert_nil NPC.new.experience(stimulus)
      end
    else
      define_method("test_stimulus_#{i}_runs_the_#{expected_feeling}_program") do
        npc = NPC.new
        reaction = npc.experience(stimulus)

        assert_equal expected_response.to_sym, reaction
        assert_equal expected_feeling.to_sym, npc.last_response.name

        feeling = npc.public_send(expected_feeling)
        assert_equal 11, feeling.pressure # suppression ticked it up

        assert_includes npc.mind.thoughts(expected_feeling.to_sym).first(50), expected_thought
      end
    end
  end
end
