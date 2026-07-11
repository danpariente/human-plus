# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/human_plus/generative_narrator"

# The GenerativeNarrator is tested against a scripted client — no gem, no
# network, no API key. The `anthropic` gem is only loaded when a narrator
# is constructed without one; these tests never are.
class TestGenerativeNarrator < Minitest::Test
  Block = Struct.new(:type, :text)
  Response = Struct.new(:content)

  # The duck the narrator quacks at: anything with messages.create.
  class ScriptedClient
    class Messages
      attr_reader :requests

      def initialize(script)
        @script = script
        @requests = []
      end

      def create(**request)
        @requests << request
        Response.new([Block.new(:thinking, ""), Block.new(:text, @script.call(request))])
      end
    end

    attr_reader :messages

    def initialize(&script)
      @messages = Messages.new(script)
    end

    def requests = @messages.requests
  end

  def narrator(&script)
    client = ScriptedClient.new(&script)
    [Town::GenerativeNarrator.new(client: client), client]
  end

  def test_the_witnessed_sentence_comes_from_the_borrowed_mind
    town_narrator, client = narrator { "bea lashes out — a threat hangs in the square" }

    assert_equal "bea lashes out — a threat hangs in the square", town_narrator.witness("bea", :attack)

    request = client.requests.first
    assert_equal Town::GenerativeNarrator::MODEL, request[:model]
    assert_includes request[:system_].first[:text], "- threat" # the law ships the trigger vocabulary
    assert_includes request[:messages].first[:content], "actor: bea"
    assert_includes request[:messages].first[:content], ":attack (calibrates at 150 — a program)"
  end

  def test_a_state_is_presented_as_a_state
    town_narrator, client = narrator { "carol gives warmth, wanting nothing at all" }
    town_narrator.witness("carol", :give_freely)

    assert_includes client.requests.first[:messages].first[:content],
                    ":give_freely (calibrates at 500 — a state)"
  end

  def test_perception_hardens_into_habit
    calls = 0
    town_narrator, = narrator { calls += 1; "ann bolts — uncertainty everywhere" }

    3.times { town_narrator.witness("ann", :flee) }
    assert_equal 1, calls # witnessed once, remembered thereafter

    town_narrator.witness("bea", :flee)
    assert_equal 2, calls # a different actor is witnessed anew
  end

  def test_a_witnessed_program_must_carry_a_trigger
    sentences = ["ann does something vague", "ann bolts — there must be a threat"]
    town_narrator, client = narrator { sentences.shift }

    assert_equal "ann bolts — there must be a threat", town_narrator.witness("ann", :flee)

    assert_equal 2, client.requests.size # the first sentence broke the law
    retry_request = client.requests.last
    assert_equal "ann does something vague", retry_request[:messages][1][:content]
    assert_match(/broke the law/, retry_request[:messages].last[:content])
  end

  def test_a_witnessed_state_must_carry_none
    sentences = ["carol radiates — a threat of kindness", "carol gives warmth, wanting nothing"]
    town_narrator, client = narrator { sentences.shift }

    assert_equal "carol gives warmth, wanting nothing", town_narrator.witness("carol", :give_freely)
    assert_equal 2, client.requests.size
  end

  def test_it_slots_into_the_town_without_the_town_changing_shape
    town_narrator, = narrator { "somebody bolts — uncertainty, there must be a threat" }
    town = Town.new(nil, narrator: town_narrator).settle("ann").settle("bob")
    town.incite("thinking about the future")
    town.tick

    reacted = town.tick.grep(Town::Reacted).first
    assert_equal :fear, reacted.feeling # the generated sentence carries the trigger
    assert_equal :flee, reacted.reaction
  end
end
