# frozen_string_literal: true

require "csv"
require_relative "human"
require_relative "letting_go"

module HumanPlus
  ##
  # The Common Human: the default configuration.
  #
  # An NPC is just a Human that never chose its programs — the firmware
  # ships in <tt>data/common_human.csv</tt> and is fed through the same
  # Assembler as any hand-built human. Coping style: suppression, of
  # course.
  #
  # Note the +love+ row of the firmware: for the Common Human, "love" is
  # attachment, dependency and possessiveness — desire and fear wearing
  # love's name. It has triggers ("the beloved", "absence of the beloved"),
  # it stores pressure, and it calibrates at Desire (125), not Love (500).
  # Same schema as every other sub-200 program, because it is one.
  #
  #   npc = Human.default
  #   npc.npc?                 # => true — still running unexamined
  #                            #    stimulus→response programs
  #   npc.calibration          # => well below 200
  #   npc.love.reaction        # => :cling
  #
  # An NPC stops being an NPC the only way anyone does: by letting go
  # (Human#surrender) until Human#emancipated?.
  class NPC < Human
    # The factory firmware.
    FIRMWARE = File.expand_path("../../data/common_human.csv", __dir__)

    ##
    # Boot from firmware. Nobody is consulted; that is the point. The CSV
    # rows are fed through the same Assembler DSL any human is built with
    # — the default configuration is data, and assembly is the only path.
    def initialize(firmware = FIRMWARE)
      super()
      rows = CSV.read(firmware, headers: true)
      assemble do
        rows.each do |row|
          program row["program"].to_sym,
                  level: Integer(row["level"]),
                  triggered_by: row["triggered_by"].split(";"),
                  thoughts: row["thoughts"].split("|"),
                  respond_with: row["respond_with"].to_sym,
                  pressure: Integer(row["pressure"])
        end
      end
    end

    ##
    # An NPC is defined by what it hasn't done yet: while any sub-Courage
    # program remains installed, the stimulus→response loop is in charge.
    def npc? = !emancipated?
  end
end
