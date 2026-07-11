# frozen_string_literal: true

module HumanPlus
  class Town
    ##
    # The memory stream — after the paper's, with the causal arrow
    # reversed.
    #
    # Park et al.'s agents act <em>from</em> memory: a stream of
    # experiences, scored by recency, importance and relevance, decides
    # what they do next. Here memory is like the Mind: downstream. A
    # Memory files what happened — who it came from, what was witnessed,
    # which program fired, how much pressure the moment added — and never
    # causes a feeling. The pressure does that, and it already happened.
    #
    # What the record buys, in Hawkins' terms:
    #
    # * A <b>grudge</b> is attributed pressure: charge still held, filed
    #   under a name. It is computed, never stored — a moment counts only
    #   while its program is still installed. Surrender the program and
    #   the grudges filed under it dissolve: the memory stays (nothing is
    #   forgotten), the charge is gone. You remember what they did; it
    #   just doesn't run you anymore.
    # * The attribution is the firmware's error. The feeling was the
    #   program, not the person — the #scapegoat is what a reflection
    #   names on the way out.
    # * The one thing memory steers is attention: among stimuli that pull
    #   equally, a resident attends to the one from the actor they hold
    #   the most against — the paper's importance term, rendered as
    #   resentment. (See Town#strongest_pull.)
    class Memory
      ##
      # One filed experience: who it came from, what was witnessed, which
      # program fired, and how much pressure the moment added (zero, for
      # an escaper — avoidance stores nothing new, and blames no one).
      Moment = Struct.new(:actor, :stimulus, :feeling, :charge)

      ##
      # A memory is always <em>of</em> someone (compare Mind.of). It
      # records; it does not cause.
      def self.of(human) = new(human)

      def initialize(human)
        @human = human
        @moments = []
      end

      ##
      # File a moment. The Town does this at experience time — the human
      # alone never could: only the town knows who did what.
      def file(actor, stimulus, feeling, charge)
        @moments << Moment.new(actor.to_s, stimulus.to_s, feeling.to_sym, Integer(charge))
        self
      end

      ##
      # The complete record, charged or not. Nothing is forgotten.
      def moments = @moments.dup

      ##
      # The ledger: actor => charge still held against them, largest
      # first. Computed against what is currently installed — surrendered
      # programs hold nothing — and the world doesn't make the ledger:
      # a grudge is against someone.
      def grudges
        @moments.select { |m| @human.respond_to?(m.feeling) && m.actor != "the world" }
                .group_by(&:actor)
                .transform_values { |moments| moments.sum(&:charge) }
                .reject { |_, charge| charge.zero? }
                .sort_by { |_, charge| -charge }.to_h
      end

      ##
      # The charge still held against one actor.
      def against(actor) = grudges.fetch(actor.to_s, 0)

      ##
      # Who a feeling got filed under most — the firmware's error, named.
      # (The world qualifies here; blame lands wherever it can.) +nil+ if
      # the feeling never charged a moment.
      def scapegoat(feeling)
        feeling = feeling.to_sym
        blamed, charge = @moments.select { |m| m.feeling == feeling }
                                 .group_by(&:actor)
                                 .transform_values { |moments| moments.sum(&:charge) }
                                 .max_by { |_, held| held }
        blamed if charge&.positive?
      end
    end
  end
end
