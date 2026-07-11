# frozen_string_literal: true

require_relative "map_of_consciousness"

module HumanPlus
  ##
  # FEELINGS = PROGRAMS = RESPONSES.
  #
  # That is not a metaphor here; it is Ruby. +Program+ and +Response+ are
  # constant aliases of this one class:
  #
  #   Program.equal?(Feeling)   # => true
  #   Response.equal?(Feeling)  # => true
  #
  # A feeling below Courage (200) is a program: it has +triggers+ (the
  # stimuli that fire it), +thought_seeds+ (the Mind expands these into
  # thousands of thoughts), a +reaction+ (what it makes you do), and
  # +pressure+ — the accumulated energy of every time it was pushed down
  # instead of released.
  #
  # The book names exactly four ways a human can handle a feeling, and they
  # are the four verbs of this class:
  #
  # * #suppress! — push it down. The pressure accumulates.
  # * #express!  — vent it. This "relieves just enough of the pressure to
  #   let the rest be suppressed" — a net gain in pressure, still.
  # * #escape!   — avoid it (the drink, the scroll, the busyness).
  #   Nothing changes. Nothing releases.
  # * #surrender! — stay with it and drop the resistance. The stored energy
  #   runs out in waves, and when the pressure reaches zero the program has
  #   nothing left to run on (#run_out?).
  #
  # At Courage and above a feeling is a #state?, not a #program?: it carries
  # zero pressure and no triggers. A state with no triggers is
  # #unconditional? — it needs nothing to fire. That is the signature of
  # true Love (500), as opposed to what the Common Human calls love (see NPC).
  class Feeling
    # The feeling's name, e.g. +:fear+.
    attr_reader :name

    # Where it calibrates on the MapOfConsciousness.
    attr_reader :level

    # The stimuli that fire this program. Empty for states — a state is
    # unconditional.
    attr_reader :triggers

    # Seed phrases the Mind expands into thousands of thoughts.
    attr_reader :thought_seeds

    # What running this program makes you do, e.g. +:flee+, +:cling+.
    attr_reader :reaction

    # The stored energy behind the feeling — a lifetime of suppression.
    # When it reaches zero, the program has #run_out?.
    attr_reader :pressure

    # How many times this feeling has been resisted (suppressed, expressed
    # or escaped). A surrender session watches this: you cannot let go
    # while resisting.
    attr_reader :resistance_count

    ##
    # Feelings are rarely built by hand — they are declared in the
    # Human.assemble DSL (see Assembler#program and Assembler#state) or
    # loaded from firmware (see NPC). +pressure+ defaults to 10: a
    # lifetime of accumulation.
    def initialize(name:, level:, respond_with:, triggered_by: [], thoughts: [], pressure: 10)
      @name = name.to_sym
      @level = Integer(level)
      @triggers = Array(triggered_by).map(&:to_s).freeze
      @thought_seeds = Array(thoughts).map(&:to_s).freeze
      @reaction = respond_with.to_sym
      @pressure = Integer(pressure)
      @resistance_count = 0
    end

    ##
    # Push the feeling down. The energy doesn't go anywhere — it
    # accumulates, and the Mind will spend it as thoughts.
    def suppress! = resist { @pressure += 1 }

    ##
    # Vent the feeling at someone or something. Hawkins: expression
    # "relieves just enough of the pressure to allow the rest to be
    # suppressed" — the program stays installed and the pressure still
    # rises.
    def express! = resist { @pressure += 1 }

    ##
    # Avoid the feeling — the drink, the scroll, the busyness. Nothing
    # changes and nothing releases; the pressure merely waits.
    def escape! = resist { @pressure }

    ##
    # One pass of letting go: stay with the feeling, drop the resistance,
    # and let a wave of its stored energy run out. Returns the size of the
    # wave (1–3, capped at what remains). Letting go is not linear.
    #
    # When the pressure empties (#run_out?), the program has nothing left
    # to run on — and Human#surrender will uninstall it, literally.
    def surrender!
      return 0 if run_out?

      release = [@pressure, 1 + rand(3)].min
      @pressure -= release
      release
    end

    ##
    # Has the stored energy behind this feeling fully run out?
    def run_out? = @pressure.zero?

    ##
    # Below Courage (200) a feeling is a program — it runs you.
    def program? = MapOfConsciousness.below_courage?(@level)

    ##
    # At Courage (200) and above a feeling is a state — you inhabit it;
    # nothing runs.
    def state? = !program?

    ##
    # A feeling that needs no trigger to fire. True Love (500) is
    # unconditional: it needs nothing from the other.
    def unconditional? = @triggers.empty?

    ##
    # Does this stimulus contain one of the program's triggers?
    def triggered_by?(stimulus)
      text = stimulus.to_s.downcase
      @triggers.any? { |t| text.include?(t.downcase) }
    end

    ##
    # Resistance undoes a surrender session: restore the pressure to what
    # it was. Used internally by Human#surrender — you cannot let go while
    # holding on.
    def repressurize(to) = @pressure = Integer(to)

    def inspect # :nodoc:
      "#<Feeling=Program=Response :#{@name} level=#{@level} pressure=#{@pressure} -> #{@reaction}>"
    end
    alias to_s inspect # :nodoc:

    private

    def resist
      @resistance_count += 1
      yield
    end
  end
end
