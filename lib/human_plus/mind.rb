# frozen_string_literal: true

require_relative "feeling"

module HumanPlus
  ##
  # The Mind is downstream of feeling.
  #
  # Hawkins: thoughts do not cause feelings — feelings generate thoughts,
  # and a single suppressed feeling can spawn thousands of them. This class
  # enforces that direction with its API surface: a Mind is a <b>read-only
  # projection</b> of a human's feelings. It has exactly two methods,
  # #thoughts and #chatter, and no method that creates, installs or
  # intensifies a feeling. (The test suite asserts this. Keep it true.)
  #
  #   mind = Mind.of(npc)
  #   mind.thoughts(:fear).first(3)
  #   # => ["Something bad will happen",
  #   #     "I am not safe",
  #   #     "What if it's true — Something bad will happen?"]
  #
  # The supply of thoughts a feeling can generate is proportional to its
  # stored pressure (1,000 thoughts per unit). Surrender the feeling and the
  # stream runs dry; when the program is gone, the mind on that subject is
  # simply quiet.
  class Mind
    # "One suppressed feeling spawns thousands of thoughts."
    THOUGHTS_PER_UNIT_OF_PRESSURE = 1_000

    # Mutation templates the seeds cycle through — the mind rarely says a
    # thing once, or the same way twice.
    TEMPLATES = [
      "%s",
      "What if it's true — %s?",
      "%s. Again.",
      "I keep thinking: %s",
      "3am: %s",
      "It always comes back to this: %s"
    ].freeze

    ##
    # A mind is always <em>of</em> someone. It observes; it does not cause.
    def self.of(human) = new(human)

    ##
    # Prefer Mind.of — a mind doesn't exist apart from its human.
    def initialize(human)
      @human = human
    end

    ##
    # The stream of thoughts a feeling generates — a lazy Enumerator of
    # +pressure * 1_000+ thoughts expanded from the feeling's seed phrases.
    # Empty if the feeling has run out, was surrendered, or (as with a
    # state like unconditional Love) carries no pressure at all: the mind
    # is quiet.
    def thoughts(feeling_name)
      Enumerator.new do |yielder|
        feeling = look_up(feeling_name)
        next if feeling.nil? || feeling.thought_seeds.empty?

        seeds = feeling.thought_seeds
        supply = feeling.pressure * THOUGHTS_PER_UNIT_OF_PRESSURE
        supply.times do |i|
          yielder << format(TEMPLATES[(i / seeds.size) % TEMPLATES.size], seeds[i % seeds.size])
        end
      end
    end

    ##
    # The interleaved stream across every pressurized program the human
    # carries — the background noise of the untrained mind.
    def chatter
      Enumerator.new do |yielder|
        streams = @human.programs.map { |p| thoughts(p.name) }
        until streams.empty?
          streams = streams.select do |stream|
            yielder << stream.next
            true
          rescue StopIteration
            false
          end
        end
      end
    end

    private

    def look_up(name)
      @human.respond_to?(name) ? @human.public_send(name) : nil
    end
  end
end
