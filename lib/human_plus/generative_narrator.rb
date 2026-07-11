# frozen_string_literal: true

require_relative "town"

module HumanPlus
  class Town
    ##
    # A Narrator with a generative Mind — ai-town's half of the bargain.
    #
    # The default Narrator is perception as fixed firmware: a CSV, one
    # sentence per reaction, the same every time. This one asks Claude how
    # the town witnesses each reaction — fresh language under the same law:
    #
    # * Below Courage (200) perception itself is programmed, so the
    #   sentence must contain, verbatim, one of the town's trigger phrases
    #   — the model chooses <em>which</em> program the reaction is mistaken
    #   for, and the cascade takes a different path each run.
    # * At Courage and above the sentence must contain no trigger at all —
    #   a state is witnessed with nothing for a program to hook.
    #
    # The Map constrains the model; #violation checks the law with the same
    # substring rule as Feeling#triggered_by?, and one corrected retry is
    # allowed before the sentence stands as witnessed.
    #
    # Once witnessed, a perception is remembered: the town sees bea's anger
    # forever the way it first saw it. Perception hardens into habit.
    #
    # Same seam as Narrator — <tt>witness(actor, reaction) → String</tt> —
    # so the Town does not change shape:
    #
    #   require "human_plus/generative_narrator"
    #   town = Town.new(narrator: Town::GenerativeNarrator.new)
    #
    # The library itself has zero dependencies; the generative narrator
    # borrows its Mind from the +anthropic+ gem, loaded only when one is
    # constructed (<tt>gem install anthropic</tt>, credentials via
    # +ANTHROPIC_API_KEY+).
    class GenerativeNarrator
      # The borrowed Mind.
      MODEL = "claude-opus-4-8"

      ##
      # The reaction → calibration table of the Common Human town: every
      # firmware program's reaction, plus :give_freely at Love (500) — what
      # emancipation leaves where the programs were.
      def self.firmware_reactions
        NPC.new.programs.to_h { |p| [p.reaction, p.level] }
           .merge(give_freely: MapOfConsciousness.calibrate(:love))
      end

      ##
      # +client+ is anything with <tt>messages.create</tt> (the Anthropic
      # SDK client by default — constructed lazily so the gem is only
      # needed here). +reactions+ maps each reaction to its calibration;
      # +triggers+ is the town's trigger vocabulary. Both default to the
      # Common Human firmware.
      def initialize(client: nil, model: MODEL, reactions: self.class.firmware_reactions,
                     triggers: NPC.new.programs.flat_map(&:triggers).uniq)
        @client = client || borrow_a_mind
        @model = model
        @reactions = reactions
        @triggers = triggers
        @habits = {}
      end

      ##
      # How +actor+'s +reaction+ looks from the outside — generated on
      # first witnessing, remembered thereafter. A reaction not in the
      # table is assumed to be a program: in this town, most things are.
      def witness(actor, reaction)
        @habits[[actor.to_s, reaction.to_sym]] ||= perceive(actor.to_s, reaction.to_sym)
      end

      private

      def perceive(actor, reaction)
        level = @reactions.fetch(reaction, 0)
        sentence = ask(actor, reaction, level)
        broken = violation(sentence, level)
        sentence = ask(actor, reaction, level, previous: sentence, correction: broken) if broken
        sentence
      end

      ##
      # The law, checked with the same substring rule the programs use to
      # match stimuli (see Feeling#triggered_by?).
      def violation(sentence, level)
        hooked = @triggers.any? { |t| sentence.downcase.include?(t.downcase) }
        if MapOfConsciousness.below_courage?(level)
          unless hooked
            "it contains no trigger phrase, so no program in the town can experience it — " \
              "a witnessed program must carry somebody's trigger, verbatim"
          end
        elsif hooked
          "it contains a trigger phrase, but a state is witnessed with no trigger in it — " \
            "nothing for a program to hook"
        end
      end

      def ask(actor, reaction, level, previous: nil, correction: nil)
        kind = MapOfConsciousness.below_courage?(level) ? "a program" : "a state"
        messages = [{ role: "user", content: "actor: #{actor}\nreaction: :#{reaction} (calibrates at #{level} — #{kind})" }]
        if correction
          messages << { role: "assistant", content: previous }
          messages << { role: "user", content: "That sentence broke the law: #{correction}. Rewrite it." }
        end

        response = @client.messages.create(
          model: @model,
          max_tokens: 200,
          output_config: { effort: "low" },
          system_: [{ type: "text", text: system_prompt }],
          messages: messages
        )
        response.content.find { |block| block.type == :text }&.text.to_s.strip
      end

      def system_prompt
        @system_prompt ||= <<~PROMPT
          You narrate how a small town of common humans witnesses each other's
          reactions — after David R. Hawkins ("Letting Go: The Pathway of
          Surrender") and Park et al.'s generative agents. In this town,
          perception below Courage (200) is firmware: the witnessing itself is
          programmed, so what the town sees in a reaction always contains
          somebody's trigger.

          The law:
          - Answer with exactly one sentence, present tense, naming the actor.
          - If the reaction calibrates below 200 (a program), the sentence must
            contain, verbatim, at least one trigger phrase from the list below —
            choose whichever program the reaction would most naturally be
            mistaken for.
          - If it calibrates at 200 or above (a state), the sentence must
            contain no trigger phrase at all — nothing for a program to hook.
          - No quotes, no preamble, no commentary. Just the sentence.

          Trigger phrases:
          #{@triggers.map { |t| "- #{t}" }.join("\n")}
        PROMPT
      end

      def borrow_a_mind
        require "anthropic"
        Anthropic::Client.new
      rescue LoadError
        raise LoadError,
              "the generative narrator borrows its Mind from the `anthropic` gem — " \
              "gem install anthropic (the rest of human+ has no dependencies)"
      end
    end
  end
end
