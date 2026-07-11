# human+

The mind as a programmable system — a Ruby rendering of David R. Hawkins'
*Letting Go: The Pathway of Surrender*, in which the book's mechanics are
the language's mechanics.

```
FEELINGS = PROGRAMS = RESPONSES
```

That line is valid Ruby, and it is how this library is built: `Program` and
`Response` are constant aliases of the one `Feeling` class
(`Program.equal?(Feeling) # => true`). A feeling below Courage (200) is a
program — it has triggers, it stores pressure, and it runs you. Assembly is
metaprogramming: every program is installed as a **real method** on the
human's singleton class. Letting go is metaprogramming too: when a
surrendered feeling's stored energy runs out, the method is
**removed** — `respond_to?(:fear)` flips to `false`, and the stimulus no
longer finds a hook.

## The Map

```
enlightenment  700  state
peace          600  state
joy            540  state
love           500  state
reason         400  state
acceptance     350  state
willingness    310  state
neutrality     250  state
courage        200  state
--------------------------- Courage: the threshold
pride          175  program
anger          150  program
desire         125  program      <- the Common Human's "love" calibrates here
fear           100  program
grief           75  program
apathy          50  program
guilt           30  program
shame           20  program
```

Below 200 a feeling is a program that runs you. At 200 and above it is a
state: no triggers (unconditional), no pressure (nothing to run out),
nothing to surrender.

## The default configuration

Most humans never write their own assembly block; they ship with the
factory firmware (`data/common_human.csv`), fed through the same DSL:

```ruby
require "human_plus"

npc = Human.default           # the Common Human
npc.npc?                      # => true — running unexamined stimulus→response programs
npc.calibration               # => 94, well below Courage

npc.experience("thinking about the future")   # => :flee
npc.fear.pressure                             # => 11 — suppression accumulates
Mind.of(npc).thoughts(:fear).count            # => 11_000 — one suppressed feeling
                                              #    spawns thousands of thoughts
```

Note the firmware's `love` row: for the Common Human, "love" is
**attachment, dependency, and possessiveness** — desire and fear wearing
love's name. It has triggers (`the beloved`, `absence of the beloved`), it
stores pressure, it responds with `:cling`, and it calibrates at Desire
(125), not Love (500). Same schema as every other sub-200 program, because
it is one.

## Assembling a human by hand

```ruby
dan = Human.assemble do
  program :fear,
    level:        100,
    triggered_by: ["uncertainty", "the future"],
    thoughts:     ["Something bad will happen", "I am not safe"],
    respond_with: :flee,
    pressure:     10
end

dan.respond_to?(:fear)   # => true — the program is installed, literally
```

## The pathway out

There are exactly four things a human can do with a feeling. Three of them
leave the program installed:

```ruby
dan.fear.suppress!   # pressure +1 — pushed down, accumulates
dan.fear.express!    # pressure +1 — vents just enough to suppress the rest
dan.fear.escape!     # no change — avoidance changes nothing
```

The fourth is different in kind:

```ruby
dan.surrender(:fear) { |wave, left| puts "released #{wave}, #{left} left" }
dan.respond_to?(:fear)        # => false — the method is gone
dan.experience("the future")  # => nil — the stimulus no longer finds a hook
dan.fear                      # NoMethodError: this human no longer runs the
                              # `fear` program — it was surrendered and its
                              # stored energy ran out.
```

You cannot let go while resisting: suppressing, expressing, or escaping a
feeling mid-session resets the session.

**Emotional emancipation** is when nothing installed calibrates below
Courage. On that transition, what replaces the surrendered "love" is not a
program at all — a state at 500, with no triggers (unconditional: it needs
nothing from the other), no pressure, and nothing to surrender:

```
$ bin/human+ emancipate

Before: #<NPC calibration=94 programs=[:shame, :guilt, :apathy, :grief, :fear,
                                       :desire, :love, :anger, :pride] states=[]>
  "love", per the firmware: level 125 (desire), responds with :cling —
  Don't leave me / I can't live without you

Surrendering everything below Courage (200):

  let go of shame:   waves: 1 2 1 1 2 2 1    calibration: 104
  let go of guilt:   waves: 3 1 3 1 2        calibration: 114
  ...
  let go of pride:   waves: 1 2 1 1 2 3      calibration: 500

After: #<NPC calibration=500 programs=[] states=[:love]>
  emancipated? true   npc? false

  What remains where `love` was:
    level:          500 (love)
    unconditional?  true — it needs nothing from the other
    responds with:  :give_freely
    the mind:       [] — quiet.
```

## The CLI

```
bin/human+ map                      # print the Map of Consciousness
bin/human+ npc                      # the default human and its firmware
bin/human+ experience "<stimulus>"  # feeling -> thoughts -> response
bin/human+ mind <feeling> [n]       # n thoughts the feeling generates
bin/human+ test [file.csv]          # run the stimuli test cases
bin/human+ surrender <feeling>      # interactive letting-go session
bin/human+ emancipate               # the full pathway
```

## The documentation is read with `ri`

The docs are the teaching medium — each page explains the concept the code
embodies:

```
rake ri
ri -d .ri HumanPlus::Human#surrender
ri -d .ri HumanPlus::NPC
ri -d .ri Program        # resolves to the Feeling page — the aliases
                         # complete the pun
```

Or: `rake 'teach[HumanPlus::Human#surrender]'`.

## Tests

```
bundle install
rake
```

`test/test_stimuli.rb` is CSV-driven — each row of `data/stimuli.csv`
becomes a test method via `define_method`. The tests are assembled the way
humans are. Feelings/emotions can be tested against the Mind with your own
CSV: `bin/human+ test my_stimuli.csv`.

---

*This is didactic art, not therapy, and certainly not enterprise software.
The book is: David R. Hawkins, «Letting Go: The Pathway of Surrender»
(Hay House, 2012).*
