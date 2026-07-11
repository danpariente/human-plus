# frozen_string_literal: true

require_relative "assembler"
require_relative "mind"

module HumanPlus
  ##
  # A human is an assemblage of programs.
  #
  # Assembly is literal metaprogramming: each feeling declared in the
  # Human.assemble DSL is installed as a real method on the human's
  # singleton class via +define_method+. A feeling you carry is a method
  # you respond to; a feeling you have surrendered is a method you no
  # longer have (see #surrender, defined in letting_go.rb):
  #
  #   dan = Human.assemble do
  #     program :fear,
  #       level:        100,
  #       triggered_by: ["uncertainty", "the future"],
  #       thoughts:     ["Something bad will happen", "I am not safe"],
  #       respond_with: :flee
  #   end
  #
  #   dan.respond_to?(:fear)        # => true — the program is installed
  #   dan.experience("the future")  # => :flee
  #   dan.surrender(:fear)          # stay with it until it runs out...
  #   dan.respond_to?(:fear)        # => false — the method is gone
  #
  # Most humans never write their own assembly block; they ship with the
  # factory firmware. See NPC.
  class Human
    # The three ordinary mechanisms, mapped to what they do to a Feeling.
    # Conspicuously absent: surrender. It is not a coping style — it is
    # the exit (see #surrender).
    COPING = { suppression: :suppress!, expression: :express!, escape: :escape! }.freeze

    # How this human handles what it feels: +:suppression+ (the default —
    # factory firmware), +:expression+ or +:escape+. All three leave the
    # program installed.
    attr_reader :coping_style

    # The Response most recently produced by #experience — and a Response
    # <em>is</em> a Feeling <em>is</em> a Program. +nil+ if the last
    # stimulus found no hook.
    attr_reader :last_response

    ##
    # Assemble a human from a block of programs and states — the
    # metaprogramming birth canal. The block is evaluated against an
    # Assembler.
    def self.assemble(&block) = new.assemble(&block)

    ##
    # The default configuration. See NPC — the Common Human, running the
    # factory firmware it never chose.
    def self.default = NPC.new

    ##
    # A human starts empty — no programs, no states, and (trivially)
    # emancipated. It is assembly that installs the firmware.
    def initialize
      @feelings = {}
      @surrendered = []
      @coping_style = :suppression
      @last_response = nil
    end

    ##
    # Run (more of) the assembly DSL against this human. Used at birth,
    # and again at #emancipate!.
    def assemble(&block)
      Assembler.new(self).instance_eval(&block)
      self
    end

    ##
    # Install a feeling as a real method on this human's singleton class.
    # After this, +human.fear+ is not a lookup — it is the human running
    # the program.
    def install(feeling)
      @feelings[feeling.name] = feeling
      define_singleton_method(feeling.name) { @feelings[feeling.name] }
      self
    end

    ##
    # Everything currently installed, programs and states alike.
    def feelings = @feelings.values

    ##
    # The installed feelings below Courage (200) — the ones that run you.
    def programs = feelings.select(&:program?)

    ##
    # The installed feelings at Courage (200) and above — the ones you are.
    def states = feelings.select(&:state?)

    ##
    # The names of the programs this human has let go of. Their methods
    # are gone; calling them raises a NoMethodError that says so.
    def surrendered = @surrendered.dup

    ##
    # Choose among the three ordinary mechanisms (COPING). Surrender is
    # deliberately not accepted here — letting go is not a coping style,
    # it is the exit (see #surrender).
    def coping_style=(style)
      unless COPING.key?(style)
        raise ArgumentError, "coping styles are #{COPING.keys.join(', ')} — letting go is not coping, see #surrender"
      end

      @coping_style = style
    end

    ##
    # Feed the human a stimulus and watch the firmware run.
    #
    # The stimulus is matched against every installed program's triggers
    # (substring match); the lowest-calibrating match fires — the
    # strongest pull wins. The human's #coping_style is applied to the
    # feeling (suppression by default, so the pressure ticks +up+ with
    # every experience), the program runs — via +public_send+, so the
    # emotional reaction appears as a real frame in the stack trace — and
    # its reaction is returned.
    #
    #   npc.experience("stuck in traffic behind an obstacle")  # => :attack
    #   npc.experience("a sunset")                             # => nil —
    #     # no program matches; the unprogrammed stimulus passes through
    def experience(stimulus)
      response = programs.select { |p| p.triggered_by?(stimulus) }.min_by(&:level)
      return @last_response = nil unless response

      response.public_send(COPING.fetch(@coping_style))
      @last_response = public_send(response.name)
      response.reaction
    end

    ##
    # Where this human calibrates on the MapOfConsciousness: the
    # pressure-weighted mean of everything installed. Programs weigh in by
    # their stored pressure; states (pressure zero) count with weight one.
    # An NPC sits well below 200. Surrender the sub-Courage programs and
    # the number climbs arithmetically — the weights holding it down are
    # gone.
    def calibration
      return 0 if @feelings.empty?

      weights = feelings.sum { |f| weight_of(f) }
      return (feelings.sum(&:level) / feelings.size.to_f).round if weights.zero?

      (feelings.sum { |f| f.level * weight_of(f) } / weights.to_f).round
    end

    ##
    # This human's Mind — a read-only projection of its feelings into
    # thoughts. Feelings generate thoughts, never the reverse.
    def mind = Mind.of(self)

    def inspect # :nodoc:
      "#<#{self.class.name.split('::').last} calibration=#{calibration}" \
        " programs=#{programs.map(&:name)} states=#{states.map(&:name)}>"
    end

    ##
    # Calling a surrendered feeling raises a NoMethodError that tells you
    # why the method is gone.
    def method_missing(name, *args, &block)
      if @surrendered.include?(name)
        raise NoMethodError,
              "this human no longer runs the `#{name}` program — it was surrendered " \
              "and its stored energy ran out. (See: ri HumanPlus::Human#surrender)"
      end

      super
    end

    def respond_to_missing?(name, include_private = false) = super # :nodoc:

    private

    def weight_of(feeling) = feeling.state? ? 1 : feeling.pressure
  end
end
