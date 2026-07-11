# frozen_string_literal: true

require_relative "feeling"

module HumanPlus
  ##
  # The DSL context for Human.assemble. Two verbs, split exactly at
  # Courage (200) on the MapOfConsciousness:
  #
  # * #program — a feeling below 200. It has triggers and pressure; it runs
  #   the human.
  # * #state — a feeling at 200 or above. No triggers (unconditional), no
  #   pressure (nothing to run out), nothing to surrender.
  #
  # Every feeling declared here is installed as a <b>real method</b> on the
  # human being assembled (see Human#install) — assembly is metaprogramming,
  # and so is its undoing.
  class Assembler
    ##
    # An assembler works on one human at a time.
    def initialize(human)
      @human = human
    end

    ##
    # Install a program — a feeling below Courage (200) that runs the human.
    # +level+ may be a number or a MapOfConsciousness name (+:fear+).
    #
    #   program :anger,
    #     level:        150,
    #     triggered_by: ["obstacle", "injustice"],
    #     thoughts:     ["How dare they", "I'll show them"],
    #     respond_with: :attack,
    #     pressure:     10
    def program(name, level:, respond_with:, triggered_by: [], thoughts: [], pressure: 10)
      level = resolve(level)
      unless MapOfConsciousness.below_courage?(level)
        raise ArgumentError,
              "#{name} calibrates at #{level} — at Courage (200) and above nothing runs you; declare a state instead"
      end

      @human.install Feeling.new(name:, level:, triggered_by:, thoughts:, respond_with:, pressure:)
    end

    ##
    # Install a state — a feeling at Courage (200) or above. States are
    # unconditional (no triggers) and store no pressure; Human#surrender
    # refuses to remove them because there is nothing behind them to empty.
    #
    #   state :love,
    #     level:        500,
    #     thoughts:     ["Nothing needs to happen", "You are free"],
    #     respond_with: :give_freely
    def state(name, level:, respond_with:, thoughts: [], triggered_by: [], pressure: 0)
      level = resolve(level)
      if MapOfConsciousness.below_courage?(level)
        raise ArgumentError,
              "#{name} calibrates at #{level} — below Courage (200) it is a program that runs you, not a state"
      end
      unless Array(triggered_by).empty?
        raise ArgumentError, "a state is unconditional — it cannot have triggers"
      end
      unless Integer(pressure).zero?
        raise ArgumentError, "a state stores no pressure — there is nothing behind it to run out"
      end

      @human.install Feeling.new(name:, level:, triggered_by: [], thoughts:, respond_with:, pressure: 0)
    end

    private

    def resolve(level)
      level.is_a?(Symbol) ? MapOfConsciousness.calibrate(level) : Integer(level)
    end
  end
end
