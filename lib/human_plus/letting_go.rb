# frozen_string_literal: true

require_relative "human"

module HumanPlus
  ##
  # The pathway of surrender — Human, reopened.
  #
  # Everything in human.rb is about what gets installed and how it runs.
  # Everything here is about the only way out: letting go.
  class Human
    ##
    # Let go of a feeling: stay with it, drop the resistance, and let its
    # stored energy run out in waves. Yields <tt>(wave, remaining)</tt>
    # after each release, if a block is given.
    #
    # This is the alternative to the three coping mechanisms (see
    # Feeling#suppress!, Feeling#express!, Feeling#escape! — all of which
    # leave the program installed). Surrender is different in kind: when
    # the pressure reaches zero, the program is <b>uninstalled</b> —
    # literally, via +remove_method+ on your singleton class:
    #
    #   dan.surrender(:fear) { |wave, left| puts "released #{wave}, #{left} left" }
    #   dan.respond_to?(:fear)        # => false
    #   dan.experience("the future")  # => nil — the stimulus no longer
    #                                 #    finds a hook
    #
    # Two refusals, both faithful to the book:
    # * You cannot surrender a state — there is no pressure to empty.
    # * You cannot let go while resisting. If the feeling is suppressed,
    #   expressed or escaped mid-session, the session resets: the pressure
    #   is restored to where it started.
    #
    # Completing a surrender checks for #emancipated? and, on the
    # transition, calls #emancipate!.
    def surrender(name)
      name = name.to_sym
      feeling = @feelings.fetch(name) do
        if @surrendered.include?(name)
          raise ArgumentError, "`#{name}` was already surrendered — there is nothing left to let go of"
        end

        raise ArgumentError, "`#{name}` is not installed — you cannot surrender what you do not carry"
      end
      if feeling.state?
        raise ArgumentError,
              "`#{name}` is a state (level #{feeling.level}), not a program — " \
              "it holds no pressure and there is nothing to surrender"
      end

      starting_pressure = feeling.pressure
      resistance = feeling.resistance_count
      until feeling.run_out?
        wave = feeling.surrender!
        yield(wave, feeling.pressure) if block_given?
        if feeling.resistance_count != resistance
          feeling.repressurize(starting_pressure) # you cannot let go while resisting
          resistance = feeling.resistance_count
        end
      end

      release(feeling)
      feeling
    end

    ##
    # Emotional emancipation: no installed program calibrates below
    # Courage (200). Nothing left runs you on unexamined stimulus→response
    # loops — you are no longer an NPC.
    def emancipated? = programs.empty?

    ##
    # The transition, reached only through surrender — checked after every
    # completed release, and refused as a shortcut:
    #
    # The Common Human's "love" (attachment, dependency, possessiveness —
    # calibrating at Desire, 125) was surrendered like any other program.
    # What replaces it is not a program at all. It is a state: Love (500),
    # with no triggers — unconditional, needing nothing from the other —
    # and no pressure — nothing stored, nothing to run out, nothing to
    # surrender.
    def emancipate!
      unless emancipated?
        raise ArgumentError,
              "still running #{programs.map(&:name).join(', ')} — " \
              "the pathway is through, not around: surrender what is below Courage first"
      end
      return self if @feelings[:love]&.state?

      assemble do
        state :love,
              level: 500,
              triggered_by: [], # unconditional — it needs nothing from the other
              thoughts: ["Nothing needs to happen", "You are free", "So am I"],
              respond_with: :give_freely,
              pressure: 0 # no stored energy; nothing to run out
      end
    end

    private

    ##
    # The program has run out; uninstall it. +remove_method+ (not
    # +undef_method+) so +respond_to?+ flips cleanly to false.
    def release(feeling)
      singleton_class.send(:remove_method, feeling.name)
      @feelings.delete(feeling.name)
      @surrendered << feeling.name
      emancipate! if emancipated?
      feeling
    end
  end
end
