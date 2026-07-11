# frozen_string_literal: true

require "csv"
require_relative "npc"
require_relative "memory"

module HumanPlus
  ##
  # The Town — generative agents on the Map of Consciousness.
  #
  # After Park et al., <em>Generative Agents: Interactive Simulacra of
  # Human Behavior</em> (arXiv:2304.03442), and its open-source rendering,
  # ai-town. The paper builds believable simulated humans from a memory
  # stream, reflection and planning, and its marquee result is emergence:
  # a party invitation diffusing through Smallville. This town runs the
  # same loop through Hawkins — what diffuses here is pressure:
  #
  # * Their agents observe one another; here, one resident's Response is
  #   the next tick's stimulus. The Narrator says how each reaction is
  #   witnessed, and every witnessed sub-200 reaction contains someone
  #   else's trigger — a +:hide+ reads as absence of the beloved (love
  #   clings), a +:cling+ as an obstacle (anger attacks), an +:attack+ as
  #   a threat (fear flees). Among NPCs the pressure never leaves the
  #   town; it moves.
  # * Their retrieval scores memories by recency, importance and
  #   relevance; here attention follows the strongest pull — of everything
  #   in the air this tick, the lowest-calibrating hook fires (the same
  #   rule as Human#experience).
  # * Their reflection synthesizes memories into higher-level insight.
  #   Here reflection is the one thing firmware cannot do for itself:
  #   noticing that the Mind's thousands of thoughts on a subject are
  #   variations on a seed — that the feeling is the program, not the
  #   world. A resident whose +awareness+ threshold is crossed reflects,
  #   and reflection opens the only exit there is: Human#surrender.
  # * Their agents plan. Programs don't plan — a program <em>reacts</em>,
  #   and a state <em>radiates</em>: unconditional, it answers everything,
  #   and is witnessed as a stimulus containing no trigger at all. The
  #   cascade dies at that resident's doorstep.
  #
  #   town = Town.new                              # the census, data/town.csv
  #   town.run("criticism lands on a mistake") do |tick, events|
  #     # Reacted, Reflected, Radiated, Unmoved
  #   end
  class Town
    # The default cast. Like all firmware here, the census is data.
    CENSUS = File.expand_path("../../data/town.csv", __dir__)

    ##
    # How the town witnesses a reaction — perception as firmware.
    #
    # The default narrator reads <tt>data/perception.csv</tt>: one row per
    # reaction, one sentence for how it looks from the outside. The
    # sentences are not neutral — each sub-200 reaction is witnessed as
    # somebody's trigger, which is how pressure propagates.
    #
    # This is deliberately a seam. ai-town narrates this step with an LLM;
    # anything that answers <tt>witness(actor, reaction) → String</tt>
    # (or +nil+ for the unwitnessable) can replace the CSV — a generative
    # Mind slots in here without the Town changing shape. One is provided:
    # see GenerativeNarrator (<tt>require "human_plus/generative_narrator"</tt>).
    class Narrator
      # The perception firmware of the Common Human town.
      PERCEPTION = File.expand_path("../../data/perception.csv", __dir__)

      ##
      # Load the perception table. Each +witnessed_as+ template receives
      # the actor's name.
      def initialize(perception = PERCEPTION)
        @witnessed_as = CSV.read(perception, headers: true)
                           .to_h { |row| [row["reaction"].to_sym, row["witnessed_as"]] }
      end

      ##
      # How +actor+'s +reaction+ looks from the outside, as a stimulus the
      # rest of the town will experience. +nil+ if the reaction has no
      # perception row — some things go unwitnessed.
      def witness(actor, reaction)
        template = @witnessed_as[reaction.to_sym]
        template && format(template, actor)
      end
    end

    ##
    # A resident is a Human with a name, a Memory (the town files every
    # experience: who, what, which program fired — see Memory) and,
    # rarely, enough awareness to notice its own programs running.
    # +awareness+ is a count of thoughts: how many the Mind must generate
    # on one subject before this human notices the subject is the
    # feeling. +nil+ — the Common Human default — means the noticing
    # never comes.
    Resident = Struct.new(:name, :human, :awareness, :memory) do
      def aware? = !awareness.nil?
    end

    ##
    # Something in the air this tick: a stimulus, who put it there, and
    # (for a resident's doing) the reaction it was witnessed from. The
    # world's incitements carry no reaction.
    Witnessed = Struct.new(:actor, :text, :reaction)

    ##
    # A program ran: +actor+ experienced +witnessed+, the +feeling+ fired
    # (at +level+, pressure now +pressure+ — coping accumulates), and the
    # +reaction+ went into the air for the next tick.
    Reacted = Struct.new(:actor, :witnessed, :feeling, :level, :pressure, :reaction)

    ##
    # The paper's reflection, Hawkins' noticing: +actor+ saw that the
    # thousands of thoughts on +feeling+ were variations on a seed, and
    # let it go — +waves+ of stored energy, then the program was gone.
    Reflected = Struct.new(:actor, :feeling, :insight, :waves, :calibration)

    ##
    # A state answered where no program could: unconditional, needing no
    # trigger. What it puts in the air contains no trigger either.
    Radiated = Struct.new(:actor, :state, :level, :reaction)

    ##
    # Nothing hooked: every stimulus in the air passed through +actor+.
    Unmoved = Struct.new(:actor)

    # The narrator in use — see Narrator for the seam.
    attr_reader :narrator

    ##
    # Settle a town from a census CSV (+resident+, +awareness+ columns).
    # Pass +nil+ to start empty and #settle by hand.
    def initialize(census = CENSUS, narrator: Narrator.new)
      @residents = []
      @narrator = narrator
      @air = []
      CSV.read(census, headers: true).each do |row|
        settle row["resident"], awareness: row["awareness"]&.then { Integer(_1) }
      end if census
    end

    ##
    # Add a resident. The default human is the default human: an NPC
    # running the factory firmware, with no awareness threshold at all.
    def settle(name, human: NPC.new, awareness: nil)
      @residents << Resident.new(name.to_s, human, awareness, Memory.of(human))
      self
    end

    ##
    # The cast, as Resident records.
    def residents = @residents.dup

    ##
    # The world puts a stimulus in the air. Everything after this is
    # residents witnessing residents.
    def incite(stimulus)
      @air = [Witnessed.new("the world", stimulus.to_s, nil)]
      self
    end

    ##
    # Nothing in the air: the last tick put no reaction back. Among NPCs
    # this rarely happens — every reaction is witnessed as somebody's
    # trigger, so the cascade feeds itself.
    def quiet? = @air.empty?

    ##
    # One turn of the loop. Every resident witnesses everything in the air
    # except their own doing; attention follows the strongest pull; the
    # reactions produced become the air of the next tick. Returns the
    # tick's events (Reacted, Reflected, Radiated, Unmoved).
    def tick
      events = []
      breeze = []
      @residents.each do |resident|
        heard = @air.reject { |w| w.actor == resident.name }
        next if heard.empty?

        witnessed, program = strongest_pull(resident, heard)
        if program
          feeling = experience_and_remember(resident, witnessed, program)
          events << Reacted.new(resident.name, witnessed, feeling.name, feeling.level, feeling.pressure, feeling.reaction)
          breeze << exhale(resident, feeling.reaction)
          events.concat(reflect(resident))
        elsif (state = resident.human.states.max_by(&:level))
          events << Radiated.new(resident.name, state.name, state.level, state.reaction)
          breeze << exhale(resident, state.reaction)
        else
          events << Unmoved.new(resident.name)
        end
      end
      @air = breeze.compact
      events
    end

    ##
    # Incite, then tick up to +ticks+ times, yielding <tt>(tick_number,
    # events)</tt> — stopping early if the town goes #quiet?.
    def run(stimulus, ticks: 12)
      incite(stimulus)
      1.upto(ticks) do |n|
        events = tick
        yield(n, events) if block_given?
        break if quiet?
      end
      self
    end

    private

    ##
    # The paper scores retrieval by recency x importance x relevance. The
    # firmware is simpler: of everything heard, whatever hooks the
    # lowest-calibrating program wins — the same strongest-pull rule as
    # Human#experience, applied across stimuli — and among equal pulls,
    # attention goes to the actor the resident holds the most against
    # (the paper's importance term, rendered as resentment — see Memory).
    # The rest of the tick goes unregistered; attention has one channel.
    def strongest_pull(resident, heard)
      heard.filter_map { |witnessed|
        program = resident.human.programs.select { |p| p.triggered_by?(witnessed.text) }.min_by(&:level)
        [witnessed, program] if program
      }.min_by { |witnessed, program| [program.level, -resident.memory.against(witnessed.actor)] } || [nil, nil]
    end

    ##
    # The resident experiences the stimulus, and the town files the
    # moment: who it came from, what was witnessed, which program fired,
    # how much pressure it added. Memory records; it never causes.
    def experience_and_remember(resident, witnessed, program)
      before = program.pressure
      resident.human.experience(witnessed.text)
      felt = resident.human.last_response
      resident.memory.file(witnessed.actor, witnessed.text, felt.name, felt.pressure - before)
      felt
    end

    ##
    # Put a reaction into the air, as the town will witness it.
    def exhale(resident, reaction)
      text = @narrator.witness(resident.name, reaction)
      Witnessed.new(resident.name, text, reaction) if text
    end

    ##
    # The noticing, for residents capable of it: if any program's supply
    # of thoughts has reached the resident's awareness threshold, the
    # insight lands — and with it, the only exit. Surrender, waves and
    # all, happens here.
    def reflect(resident)
      return [] unless resident.aware?

      noticed = resident.human.programs
                        .select { |p| supply(p) >= resident.awareness }
                        .max_by(&:pressure)
      return [] unless noticed

      insight = "#{commas(supply(noticed))} thoughts, every one a variation on " \
                "#{noticed.thought_seeds.first.inspect} — the #{noticed.name} is the program, not the world"
      scapegoat = resident.memory.scapegoat(noticed.name)
      insight += "; it was never about #{scapegoat}" if scapegoat
      waves = []
      resident.human.surrender(noticed.name) { |wave, _| waves << wave }
      [Reflected.new(resident.name, noticed.name, insight, waves, resident.human.calibration)]
    end

    def supply(program) = program.pressure * Mind::THOUGHTS_PER_UNIT_OF_PRESSURE

    def commas(number) = number.to_s.gsub(/(\d)(?=(\d{3})+\z)/, '\1,')
  end
end
