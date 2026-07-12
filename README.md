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

## The town

After Park et al., *Generative Agents: Interactive Simulacra of Human
Behavior* ([arXiv:2304.03442](https://arxiv.org/abs/2304.03442)), and its
open-source rendering, [ai-town](https://github.com/a16z-infra/ai-town).
The paper builds believable simulated humans from a memory stream,
reflection, and planning; its marquee result is emergence — a party
invitation diffusing through Smallville. `Town` runs the same loop through
Hawkins, and what diffuses here is pressure:

- **One resident's response is the next tick's stimulus.** The `Narrator`
  says how each reaction is witnessed (`data/perception.csv` — perception
  is firmware too), and every witnessed sub-200 reaction contains someone
  else's trigger: a `:hide` reads as *absence of the beloved* (love
  clings), a `:cling` as *an obstacle* (anger attacks), an `:attack` as
  *a threat* (fear flees), a `:grasp` as *look at what others have*
  (desire spreads mimetically). Among NPCs the pressure never leaves the
  town — it moves.
- **Attention follows the strongest pull.** The paper scores memory
  retrieval by recency × importance × relevance; here, of everything in
  the air this tick, the lowest-calibrating hook fires — the same rule as
  `Human#experience`.
- **Reflection is the exit.** The paper's agents synthesize memories into
  higher-level insight. Here reflection is the one thing firmware cannot
  do for itself: noticing that the Mind's thousands of thoughts on a
  subject are variations on a seed — that the feeling is the program, not
  the world. A resident with an `awareness` threshold (thoughts on one
  subject before the noticing) reflects, and reflection opens the only
  exit there is: `surrender`.
- **Programs react; states radiate.** An emancipated resident answers
  everything with `:give_freely`, witnessed as a stimulus containing no
  trigger at all. The cascade dies at their doorstep.

```
$ bin/human+ town

the world incites: "criticism lands on a mistake"

tick 1
  alice    shame(20)  pressure 11  -> :hide         at the world
  ...
tick 2
  alice    love(125)  pressure 11  -> :cling        at bea's :hide
  ...
tick 4
  alice    fear(100)  pressure 11  -> :flee         at bea's :attack
  ...
tick 5
  carol    reflects: 12,000 thoughts, every one a variation on
           "Something bad will happen" — the fear is the program, not the world
           lets go of fear  (waves: 1 1 3 2 2 2 1)  calibration: 94
tick 6
  alice    fear(100)  pressure 13  -> :flee         at bea's :flee
  bea      fear(100)  pressure 13  -> :flee         at alice's :flee
  carol    nothing hooks — the stimulus passes through

After 12 ticks the town is still running. The pressure never left — it moved:
  alice    calibration  95  9 programs installed, most pressurized: fear (19)
  bea      calibration  95  9 programs installed, most pressurized: fear (19)
  carol    calibration  94  8 programs installed, most pressurized: shame (11)
```

The default cast is `data/town.csv`: alice and bea never look; carol
reflects at 12,000 thoughts on one subject. The `Narrator` is the seam
where a generative Mind slots in: anything that answers
`witness(actor, reaction)` with a sentence can narrate the town. ai-town
does this step with an LLM; here the default is a CSV, because the Common
Human's perception is factory firmware too.

### The generative Narrator

The seam is filled: `Town::GenerativeNarrator` borrows a Mind — Claude —
and generates each perception fresh, under the same law. Below Courage
the sentence must contain somebody's trigger, verbatim; the model chooses
*which* program the reaction is mistaken for, so the cascade takes a
different path each run. At Courage and above it must contain none. Once
witnessed, a perception is remembered — the town sees bea's anger forever
the way it first saw it. Perception hardens into habit.

```
$ bin/human+ town --generative "a traffic jam is an obstacle"

tick 2
  in the air (bea's :attack):   "Bea lashes out at the man who cut in line,
                                 mistaking his disrespect for a threat to her standing."
  in the air (alice's :attack): "Alice lashes out because she reads disrespect
                                 where none was meant."
  alice    fear(100)   pressure 11  -> :flee    at bea's :attack
  bea      anger(150)  pressure 12  -> :attack  at alice's :attack
```

Same reaction, two witnessings — bea's attack read as a *threat* (fear
flees), alice's as a *disrespect* (anger attacks back) — and the town
forks in ways the CSV never could. The core library keeps its zero
dependencies: the `anthropic` gem is loaded only when a
`GenerativeNarrator` is constructed (`gem install anthropic`, credentials
via `ANTHROPIC_API_KEY`).

### Conversations

The paper's agents converse; so do residents, at close range. The
mechanics are Hawkins':

- **The words are the Mind, said aloud.** A speaker's line is the next
  thought from the stream their fired program generates — a conversation
  between NPCs is two programs talking to each other.
- **Speaking is expression.** Venting relieves just enough of the
  pressure to let the rest be suppressed, so both parties leave the
  argument carrying more than they brought.
- **The listener responds to the tone, not the words** — the Narrator's
  witnessing of the feeling behind the line, heard through their own
  triggers. Contagion, at conversational range.
- **A state speaks its few words directly** (its Mind is quiet), and its
  tone contains no trigger: talk to an emancipated human and your
  programs find nothing to grip. The conversation ends the only way it
  can — in quiet.

```
$ bin/human+ converse

the world, to alice: "your partner doesn't text back — the absence of the beloved"

  alice    (love(125), pressure 12): "Don't leave me"
            ...heard as: alice holds on too tightly — an obstacle in your way

  bea      (anger(150), pressure 12): "How dare they"
            ...heard as: bea lashes out — a threat and a disrespect

  alice    (fear(100), pressure 12): "Something bad will happen"
            ...heard as: alice bolts — uncertainty, there must be a threat
  ...
  alice    calibration  95  carries 8 more than they brought — venting is not release
  bea      calibration  96  carries 8 more than they brought — venting is not release
```

Talk to carol (`bin/human+ converse alice carol "thinking about the
future"`) and she reflects mid-argument, lets go of the fear, and the
next volley finds nothing to hook — she falls silent while alice keeps
carrying it. `--generative` works here too: the tones are generated, the
words stay the Mind's.

### The memory stream

The paper's agents act *from* memory — a stream of experiences scored by
recency, importance and relevance decides what they do next. Here the
causal arrow is reversed, like the Mind's: a resident's `Memory` files
every experience (who it came from, what was witnessed, which program
fired, how much pressure it added) and never causes a feeling. What the
record buys, in Hawkins' terms:

- **A grudge is attributed pressure** — charge still held, filed under a
  name. It is computed, never stored: a moment counts only while its
  program is still installed. Surrender the program and the grudges
  under it dissolve — the memory stays (nothing is forgotten), the
  charge is gone. You remember what they did; it just doesn't run you.
- **The attribution is the firmware's error.** The feeling was the
  program, not the person — which is exactly what a reflection now names
  on the way out: *"the fear is the program, not the world; it was never
  about alice."*
- **Memory steers one thing: attention.** Among stimuli that pull
  equally, a resident attends to the actor they hold the most against —
  the paper's importance term, rendered as resentment.

```
$ bin/human+ town
...
After 12 ticks the town is still running. The pressure never left — it moved:
  alice    calibration  95  9 programs installed, most pressurized: fear (19)
           holds it against: bea (11)
  bea      calibration  95  9 programs installed, most pressurized: fear (19)
           holds it against: alice (11)

$ bin/human+ converse
...
  alice    calibration  95  carries 8 more than they brought, 3 of it filed
           under bea — venting is not release
```

### Watching the town

`bin/human+ town --chart` also writes the run as a single self-contained
HTML page (no dependencies, no network — inline SVG, light and dark):
each resident's **calibration** over ticks with Courage (200) as the
threshold line and a ring where a reflection happened, their **stored
pressure** (suppression accumulates; surrender empties), and the
**grudge ledger** as bars. The transcript and a table view travel with
the page. One line going quiet while the others climb is the whole book
in one picture.

```
bin/human+ town --chart                    # writes town.html
bin/human+ town --chart=run.html "a traffic jam is an obstacle" 8
bin/human+ town --generative --chart       # works together
```

### The town, alive

ai-town's other half: the engine loop, and the window you watch it
through. `bin/human+ ui` starts both in stdlib Ruby and nothing else — a
background thread ticks the town on a cadence (**the loop**), five
residents run on the same firmware (**the multiple agents**: alice, bea
and dee never look; carol and ed reflect, eventually), and a
hand-rolled `socket` HTTP server serves one self-contained page that
polls `/state` and draws the square:

- residents around **the world** at the center, contagion as animated
  arcs from what was witnessed to who reacted, reaction chips, and the
  rule of the room: **programs flicker; states are still** — an
  emancipated resident's dot stops flickering and simply glows
- the **Map of Consciousness** as a rail: every resident is a dot that
  drifts as its calibration moves; Courage (200) is the threshold line
- **in the air**, the record, and the grudge ledger, live — watch the
  town pick its scapegoat as the attention tie-break feeds on itself
- when the town goes quiet, **the world incites the next stimulus** from
  `data/stimuli.csv` — that is the world's job, and it never runs out

You can pause the loop, step it, or type your own words into the air
(`incite`). `--generative` narrates every perception with Claude while
the loop runs — memoized, so the town warms up and then coasts.

```
bin/human+ ui                # http://127.0.0.1:4200
bin/human+ ui --port=8080 --generative
```

### First person

`bin/human+ live` settles *you* into the town, running the same factory
firmware as everyone else. The difference is one thing only — when a
program of yours fires, you get the question an NPC never gets:

```
tick 1

  at you, from the world: "criticism lands on a mistake"
  it fires: shame (20, shame), pressure 10
  the mind: "I am worthless" · "They saw the real me" ·
            "What if it's true — I am worthless?" ...
  suppress, express, escape — or surrender?  [s/e/a/S]
```

Suppress, express, or escape and your reaction enters the air — the town
witnesses your tone, the tone comes back at you, and the ledger grows.
Surrender and you stay with the feeling wave by wave until it runs out:
nothing enters the air, and the cascade dies at your doorstep. Between
ticks you can `[r]eflect` — sit with any installed program without
waiting for its trigger. Emancipation ends the game the way the book
says it must: love (500) where the programs were, the ledger dissolved,
the mind quiet, `you.npc? # => false`. The town keeps running. It no
longer runs you.

Under the hood this is one small hook: `Town#settle` takes a block, and
a played resident's turn is delegated to it instead of the firmware —
the block handles the feeling and returns what (if anything) enters the
air. `--generative` narrates what reaches you.

## The CLI

```
bin/human+ map                      # print the Map of Consciousness
bin/human+ npc                      # the default human and its firmware
bin/human+ experience "<stimulus>"  # feeling -> thoughts -> response
bin/human+ mind <feeling> [n]       # n thoughts the feeling generates
bin/human+ test [file.csv]          # run the stimuli test cases
bin/human+ surrender <feeling>      # interactive letting-go session
bin/human+ emancipate               # the full pathway
bin/human+ town ["<stimulus>" [n]]  # n ticks of Smallville on the Map
bin/human+ town --generative        # ... with perception generated by Claude
bin/human+ town --chart[=f.html]    # ... also written as a self-contained page
bin/human+ converse [a b ["<stimulus>" [n]]]  # two residents at close range
bin/human+ live ["<stimulus>"]      # first person: the question an NPC never gets
bin/human+ ui [--port=N]            # the town, alive in a browser — loop + 5 agents
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
