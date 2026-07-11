# frozen_string_literal: true

require_relative "town"

module HumanPlus
  ##
  # Conversations — Town, reopened.
  #
  # Everything in town.rb is witnessing at a distance. This is close
  # range: two residents talking. The paper's agents converse in natural
  # language; here the mechanics are Hawkins':
  #
  # * The words are the Mind, said aloud. A speaker's line is the next
  #   thought from the stream their fired program generates (see Mind) —
  #   a conversation between NPCs is two programs talking to each other.
  # * Speaking from a program is expression (Feeling#express!): venting
  #   relieves just enough of the pressure to let the rest be suppressed,
  #   so both parties leave the argument carrying more than they brought.
  # * The listener does not respond to the words. They respond to the
  #   <em>tone</em> — the Narrator's witnessing of the feeling behind the
  #   line — heard through their own triggers. Contagion, at
  #   conversational range.
  # * A state speaks its few words directly — its Mind is quiet, there is
  #   no pressure to spend — and its tone contains no trigger. Talk to an
  #   emancipated human and your programs find nothing to grip; the
  #   conversation ends the only way it can: in quiet.
  # * An aware resident can notice mid-argument (Reflected) — the exit
  #   stays open even at close range.
  class Town
    ##
    # One line of dialogue. +line+ is the Mind aloud; +heard_as+ is the
    # tone — what the other will actually respond to. +pressure+ is what
    # the speaker carries after venting (a state carries none).
    Spoke = Struct.new(:speaker, :feeling, :level, :line, :pressure, :heard_as)

    ##
    # Nothing in +name+ hooked what was just heard — no program fired,
    # no state to answer from, or the mind ran dry on the subject.
    FellSilent = Struct.new(:name)

    ##
    # A conversation between two residents, opened by a stimulus from the
    # world. Each turn the speaker's fired feeling supplies the line, the
    # listener hears the tone, and the roles swap — for at most +turns+
    # lines, or until someone falls silent. Returns the transcript as
    # events (Spoke, Reflected, FellSilent).
    def converse(a_name, b_name, stimulus, turns: 8)
      speaker = resident(a_name)
      listener = resident(b_name)
      streams = {}
      events = []
      heard = Witnessed.new("the world", stimulus.to_s, nil)

      turns.times do
        feeling = fire(speaker, heard)
        line = feeling && say(streams, speaker, feeling)
        unless line
          events << FellSilent.new(speaker.name)
          break
        end

        tone = @narrator.witness(speaker.name, feeling.reaction)
        events << Spoke.new(speaker.name, feeling.name, feeling.level, line, feeling.pressure, tone)
        events.concat(reflect(speaker))

        heard = Witnessed.new(speaker.name, tone, feeling.reaction)
        speaker, listener = listener, speaker
      end
      events
    end

    private

    def resident(name)
      @residents.find { |r| r.name == name.to_s } or
        raise ArgumentError, "no resident named `#{name}` — settle them first"
    end

    ##
    # What fires in +resident+ on hearing +witnessed+: the
    # strongest-pulled program (experienced, so coping applies and the
    # pressure ticks up), the highest state if no program hooks, or +nil+
    # — silence.
    def fire(resident, witnessed)
      _, program = strongest_pull(resident, [witnessed])
      if program
        experience_and_remember(resident, witnessed, program)
      else
        resident.human.states.max_by(&:level)
      end
    end

    ##
    # The next line. A program speaks its Mind — the thought stream its
    # pressure supplies — and speaking is expression. A state has no
    # stream (the mind on that subject is quiet); it speaks its few words
    # directly, around and around, and nothing accumulates.
    def say(streams, resident, feeling)
      stream = streams[[resident.name, feeling.name]] ||=
        if feeling.state?
          feeling.thought_seeds.cycle
        else
          resident.human.mind.thoughts(feeling.name)
        end
      feeling.express! if feeling.program? # venting lets the rest be suppressed
      stream.next
    rescue StopIteration
      nil
    end
  end
end
