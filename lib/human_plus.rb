# frozen_string_literal: true

##
# human+ — the mind as a programmable system.
#
# A Ruby rendering of David R. Hawkins' <em>Letting Go: The Pathway of
# Surrender</em>, in which the book's mechanics are the language's
# mechanics: feelings are installed as methods (metaprogramming as
# assembly), letting go removes them (+remove_method+ as surrender), and
# FEELINGS = PROGRAMS = RESPONSES is a statement about constants.
#
# Start here:
#
#   ri HumanPlus::Human            # assembly and experience
#   ri HumanPlus::Human#surrender  # the pathway out
#   ri HumanPlus::Feeling          # = Program = Response
#   ri HumanPlus::NPC              # the default configuration
#   ri HumanPlus::Mind             # feelings -> thoughts, never the reverse
#   ri HumanPlus::Town             # generative agents on the Map
module HumanPlus
end

require_relative "human_plus/version"
require_relative "human_plus/map_of_consciousness"
require_relative "human_plus/feeling"
require_relative "human_plus/mind"
require_relative "human_plus/assembler"
require_relative "human_plus/human"
require_relative "human_plus/letting_go"
require_relative "human_plus/npc"
require_relative "human_plus/town"
require_relative "human_plus/conversation"
require_relative "human_plus/chart"
require_relative "human_plus/square"
require_relative "human_plus/world"

# Deliberate namespace pollution in service of the art: the cast, hoisted
# to the top level. FEELINGS = PROGRAMS = RESPONSES is not a slogan here —
# it is three names for one class, and +equal?+ agrees.

Human = HumanPlus::Human
Feeling = HumanPlus::Feeling
Program = HumanPlus::Feeling # FEELINGS = PROGRAMS
Response = HumanPlus::Feeling # ... = RESPONSES
NPC = HumanPlus::NPC
Mind = HumanPlus::Mind
Town = HumanPlus::Town
MapOfConsciousness = HumanPlus::MapOfConsciousness
