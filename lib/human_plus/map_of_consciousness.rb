# frozen_string_literal: true

module HumanPlus
  ##
  # The Map of Consciousness, after David R. Hawkins (<em>Letting Go: The
  # Pathway of Surrender</em>).
  #
  # Every feeling calibrates somewhere on a logarithmic scale from Shame (20)
  # to Enlightenment (700+). The line that matters is Courage (200) — the
  # threshold of integrity and power:
  #
  # * <b>Below 200</b> a feeling is a <em>program</em>. It has triggers, it
  #   stores pressure, and it runs you: stimulus in, response out. This is
  #   the firmware of the Common Human — see NPC.
  # * <b>At 200 and above</b> a feeling is a <em>state</em>. It needs no
  #   trigger and stores no pressure. Nothing runs; you simply are it.
  #
  #   MapOfConsciousness.calibrate(:fear)        # => 100
  #   MapOfConsciousness.below_courage?(100)     # => true — fear runs you
  #   MapOfConsciousness.calibrate(:love)        # => 500 — but see NPC for
  #                                              #    what commonly wears the name
  module MapOfConsciousness
    ##
    # The calibrated levels. Frozen — the map is not the territory, and it
    # doesn't change to suit you.
    LEVELS = {
      shame: 20, guilt: 30, apathy: 50, grief: 75, fear: 100,
      desire: 125, anger: 150, pride: 175,
      courage: 200, # the threshold of integrity and power
      neutrality: 250, willingness: 310, acceptance: 350, reason: 400,
      love: 500, joy: 540, peace: 600, enlightenment: 700
    }.freeze

    ##
    # The threshold. Below it, feelings are programs that run you.
    # At or above it, they are states you inhabit.
    COURAGE = 200

    ##
    # Look up the calibration of a named level.
    #
    #   MapOfConsciousness.calibrate(:anger)  # => 150
    def self.calibrate(name) = LEVELS.fetch(name.to_sym)

    ##
    # Is this calibration still in program territory?
    def self.below_courage?(level) = level < COURAGE

    ##
    # The name of the highest named level at or below +level+ — useful for
    # reading a raw calibration back onto the map.
    #
    #   MapOfConsciousness.name_of(125)  # => :desire
    def self.name_of(level)
      LEVELS.select { |_, v| v <= level }.max_by { |_, v| v }&.first
    end
  end
end
