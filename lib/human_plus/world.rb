# frozen_string_literal: true

require_relative "square"
require_relative "conversation"

module HumanPlus
  class Town
    ##
    # The world, walking — a Ruby ai-town.
    #
    # ai-town proper (a16z-infra/ai-town) is agents on a tile map:
    # they wander, they meet, and when they meet they converse; a server
    # game loop drives it and a browser window shows it. This is that,
    # in stdlib Ruby, run through Hawkins:
    #
    # * Residents wander the map. Movement carries calibration: programs
    #   walk nervously; an emancipated resident strolls, slower and
    #   still. And nobody chooses their route freely — a resident steers
    #   <em>away</em> from whoever they hold a grudge against, so the
    #   square polarizes as the ledger grows.
    # * Proximity starts a Conversation — the real Town#converse: the
    #   words are the Mind aloud, the listener responds to the tone,
    #   speaking is expression. The transcript plays back line by line
    #   over the walkers' heads while they stand facing each other.
    # * The opener comes from the world's rotation (or from you, via
    #   +incite+ — you hand the town something to talk about).
    # * Reflections happen mid-encounter; a resident can fall silent;
    #   an emancipated one answers everything and hooks nothing.
    #
    # A World is a Square with geometry: same loop, same window
    # mechanics (<tt>serve</tt>, <tt>run_loop</tt>, <tt>/state</tt>,
    # <tt>/control</tt>), different physics and page.
    class World < Square
      # The map, in tiles.
      SIZE = { w: 34, h: 22 }.freeze

      # The town's fixtures — walls to walk around, places to meet by.
      OBSTACLES = [
        { x: 14, y: 8, w: 6, h: 4, name: "the well" },
        { x: 4, y: 3, w: 6, h: 4, name: "the chapel" },
        { x: 24, y: 15, w: 6, h: 4, name: "the inn" }
      ].freeze

      # Decor with a trunk to bump into.
      TREES = [
        { x: 8, y: 16 }, { x: 27, y: 4 }, { x: 17, y: 19 }, { x: 30, y: 9 }, { x: 3, y: 11 }
      ].freeze

      # World-steps between spoken lines during an encounter.
      LINE_BEAT = 4

      # World-steps a pair keeps its distance after parting.
      COOLDOWN = 110

      # How close is close enough to fall into conversation.
      EARSHOT = 2.3

      def initialize(town, every: 0.35, stimuli: nil)
        super(town, every: every, stimuli: stimuli)
        @walkers = {}
        @pairs = []
        @cooldowns = Hash.new(0)
        @bubbles = {}
        @glow = {}
        @openers = []
        town.residents.each { |r| take_place(r.name) }
      end

      ##
      # Put a resident somewhere on purpose — the director's hand (and
      # the tests').
      def place(name, x, y)
        @mutex.synchronize do
          walker = @walkers.fetch(name.to_s)
          walker[:x] = walker[:tx] = x.to_f
          walker[:y] = walker[:ty] = y.to_f
        end
        self
      end

      ##
      # You hand the town something to talk about: the next encounter
      # opens with your words instead of the rotation's.
      def incite(stimulus)
        return if stimulus.to_s.strip.empty?

        @mutex.synchronize do
          @openers << stimulus.to_s
          file %(you hand the town something to talk about: "#{stimulus}")
        end
      end

      ##
      # One turn of the engine: cooldowns tick down, wanderers walk,
      # near-enough wanderers fall into conversation, and every running
      # conversation plays its next line on the beat.
      def step
        @mutex.synchronize do
          @tick += 1
          @cooldowns.transform_values! { |t| t - 1 }
          @bubbles.each_value { |b| b[:ttl] -= 1 }
          @bubbles.reject! { |_, b| b[:ttl] <= 0 }
          @glow.transform_values! { |t| t - 1 }
          @glow.reject! { |_, t| t <= 0 }

          wander
          meet
          play
        end
        self
      end

      ##
      # Everything the window shows.
      def state
        @mutex.synchronize do
          {
            tick: @tick,
            running: @running,
            map: { w: SIZE[:w], h: SIZE[:h], obstacles: OBSTACLES, trees: TREES },
            residents: @town.residents.map { |r|
              walker = @walkers[r.name]
              {
                name: r.name, x: walker[:x].round(2), y: walker[:y].round(2),
                facing: walker[:facing], state: walker[:state],
                bubble: @bubbles[r.name]&.slice(:text, :meta, :silence),
                reflecting: @glow.key?(r.name),
                calibration: r.human.calibration,
                pressure: r.human.programs.sum(&:pressure),
                emancipated: r.human.emancipated?,
                grudges: r.memory.grudges
              }
            },
            encounters: @pairs.map { |p| [p[:a], p[:b]] },
            feed: @feed.last(60).reverse
          }
        end
      end

      private

      def take_place(name)
        x, y = 8.times.map { [rand * SIZE[:w], rand * SIZE[:h]] }.find { |px, py| !blocked?(px, py) } || [1.0, 1.0]
        @walkers[name] = { x: x, y: y, tx: x, ty: y, facing: 1, state: :wandering }
      end

      def blocked?(x, y)
        return true if x < 0.8 || y < 0.8 || x > SIZE[:w] - 0.8 || y > SIZE[:h] - 0.8

        OBSTACLES.any? { |o| x > o[:x] - 0.6 && x < o[:x] + o[:w] + 0.6 && y > o[:y] - 0.6 && y < o[:y] + o[:h] + 0.6 } ||
          TREES.any? { |t| (x - t[:x])**2 + (y - t[:y])**2 < 1.2 }
      end

      def wander
        @town.residents.each do |r|
          walker = @walkers[r.name]
          next unless walker[:state] == :wandering

          speed = r.human.emancipated? ? 0.12 : 0.22
          dx = walker[:tx] - walker[:x]
          dy = walker[:ty] - walker[:y]
          distance = Math.sqrt(dx * dx + dy * dy)
          if distance < 0.3
            walker[:tx], walker[:ty] = next_destination(r)
          else
            nx = walker[:x] + dx / distance * speed
            ny = walker[:y] + dy / distance * speed
            if blocked?(nx, ny)
              walker[:tx], walker[:ty] = next_destination(r)
            else
              walker[:facing] = dx.negative? ? -1 : 1
              walker[:x] = nx
              walker[:y] = ny
            end
          end
        end
      end

      ##
      # Nobody picks a destination freely: candidates are scored by
      # distance from everyone this resident holds a grudge against —
      # you walk away from what you carry, and the square polarizes.
      def next_destination(resident)
        grudges = resident.memory.grudges
        candidates = 8.times.map { [1 + rand * (SIZE[:w] - 2), 1 + rand * (SIZE[:h] - 2)] }
                            .reject { |x, y| blocked?(x, y) }
        return [@walkers[resident.name][:x], @walkers[resident.name][:y]] if candidates.empty?
        return candidates.first if grudges.empty?

        candidates.max_by do |x, y|
          grudges.sum do |who, charge|
            other = @walkers[who] or next 0
            Math.sqrt((x - other[:x])**2 + (y - other[:y])**2) * charge
          end
        end
      end

      def meet
        wandering = @town.residents.map(&:name).select { |n| @walkers[n][:state] == :wandering }
        wandering.combination(2) do |a, b|
          next if @cooldowns[[a, b].sort] > 0

          wa, wb = @walkers[a], @walkers[b]
          next if (wa[:x] - wb[:x])**2 + (wa[:y] - wb[:y])**2 > EARSHOT**2

          opener = @openers.shift || @stimuli.next.to_s
          transcript = @town.converse(a, b, opener, turns: 6)
          [wa, wb].each { |w| w[:state] = :conversing }
          wa[:facing] = wb[:x] < wa[:x] ? -1 : 1
          wb[:facing] = -wa[:facing]
          @pairs << { a: a, b: b, queue: transcript, beat: 0 }
          file %(#{a} and #{b} meet. the world offers: "#{opener}")
          break # one new conversation per step keeps the square legible
        end
      end

      def play
        @pairs.each do |pair|
          pair[:beat] += 1
          next unless (pair[:beat] % LINE_BEAT).zero?

          case (event = pair[:queue].shift)
          when Spoke
            @bubbles[event.speaker] = { text: event.line, ttl: LINE_BEAT + 2,
                                        meta: "#{event.feeling} #{event.level}" }
            file "  #{event.speaker} (#{event.feeling} #{event.level}): #{event.line.inspect}"
          when Reflected
            @glow[event.actor] = 10
            file "  #{Town.describe(event)}"
          when FellSilent
            @bubbles[event.name] = { text: "…", ttl: LINE_BEAT + 2, silence: true }
            file "  #{event.name} — nothing hooks; silence."
          when nil
            part(pair)
          end
        end
        @pairs.reject! { |pair| pair[:done] }
      end

      def part(pair)
        pair[:done] = true
        @cooldowns[[pair[:a], pair[:b]].sort] = COOLDOWN
        [pair[:a], pair[:b]].each do |name|
          @walkers[name][:state] = :wandering
          resident = @town.residents.find { |r| r.name == name }
          @walkers[name][:tx], @walkers[name][:ty] = next_destination(resident)
        end
        file "#{pair[:a]} and #{pair[:b]} part, carrying it with them."
      end

      def page = PAGE_WORLD

      # The window: fixed-stage map, HTML bubbles over SVG walkers.
      # Night, still — programs hurry; states stroll.
      PAGE_WORLD = <<~'PAGE'
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>the world, walking</title>
        <style>
          :root {
            --night: #121310; --ground: #171a14; --panel: #1b1815;
            --ink: #ece7dd; --dim: #8f877a; --faint: #57524a; --line: #2b2823;
            --ember: #c98500; --lamp: #e8c87a;
            --serif: "Iowan Old Style", Palatino, "Book Antiqua", Georgia, serif;
            --mono: ui-monospace, "SF Mono", Menlo, Consolas, monospace;
          }
          * { box-sizing: border-box; }
          body { margin: 0; background: var(--night); color: var(--ink); font: 15px/1.5 var(--serif); }
          main { max-width: 940px; margin: 0 auto; padding: 24px 20px 60px; }
          header { display: flex; align-items: baseline; gap: 16px; flex-wrap: wrap; margin-bottom: 14px; }
          h1 { font-size: 24px; font-weight: 500; font-style: italic; margin: 0; }
          h1 .plus { color: var(--ember); font-style: normal; }
          .tickno { font-family: var(--mono); font-size: 12px; color: var(--dim); }
          .controls { margin-left: auto; display: flex; gap: 8px; }
          input[type=text] { background: var(--panel); color: var(--ink); border: 1px solid var(--line);
            border-radius: 6px; padding: 7px 11px; font: 13px var(--serif); font-style: italic; width: 280px; }
          input[type=text]:focus { outline: none; border-color: var(--ember); }
          button { background: var(--panel); color: var(--ink); border: 1px solid var(--line);
            border-radius: 6px; padding: 7px 13px; font: 12px var(--mono); cursor: pointer; }
          button:hover { border-color: var(--ember); color: var(--ember); }
          #stagewrap { overflow-x: auto; border: 1px solid var(--line); border-radius: 12px; background: var(--ground); }
          #stage { position: relative; width: 884px; height: 572px; margin: 0 auto; }
          #stage svg { position: absolute; inset: 0; }
          .walker { transition: transform .42s linear; }
          .hurry { animation: hurry 1.1s ease-in-out infinite; }
          @keyframes hurry { 0%,100% { opacity: .95; } 50% { opacity: .78; } }
          .stroll { filter: drop-shadow(0 0 10px rgba(236,231,221,.45)); }
          .ring { fill: none; stroke: #e8dfc9; stroke-width: 2; animation: letgo 1.6s ease-out infinite; }
          @keyframes letgo { from { opacity: .9; r: 14; } to { opacity: 0; r: 34; } }
          .bubble { position: absolute; transform: translate(-50%, -100%); max-width: 190px;
            background: var(--panel); border: 1px solid var(--line); border-radius: 10px;
            padding: 6px 10px; font: italic 12.5px/1.4 var(--serif); color: var(--ink);
            pointer-events: none; box-shadow: 0 3px 14px rgba(0,0,0,.5); }
          .bubble .meta { display: block; font: 10px var(--mono); font-style: normal; color: var(--ember); margin-top: 3px; }
          .bubble.silence { color: var(--faint); font-size: 16px; }
          .wname { fill: var(--ink); font: italic 12px var(--serif); }
          .wcal { fill: var(--dim); font: 9.5px var(--mono); }
          .fixture { fill: var(--panel); stroke: var(--line); }
          .fixture-name { fill: var(--faint); font: italic 11px var(--serif); }
          .lamp { fill: var(--lamp); opacity: .8; }
          .tree { fill: #22301f; stroke: #2c3a28; }
          .talkline { stroke: var(--ember); stroke-width: 1; stroke-dasharray: 3 4; opacity: .5; }
          .lower { display: grid; grid-template-columns: 1fr 260px; gap: 14px; margin-top: 14px; }
          .panel { background: var(--panel); border: 1px solid var(--line); border-radius: 12px; }
          .panel h2 { font: italic 500 13px var(--serif); color: var(--dim); margin: 0; padding: 11px 15px 0; }
          #feed { font: 12px/1.7 var(--mono); color: var(--dim); padding: 8px 15px 13px;
            max-height: 260px; overflow-y: auto; white-space: pre-wrap; }
          #feed .now { color: var(--ink); }
          #ledger { padding: 8px 15px 14px; font: 12px var(--mono); color: var(--dim); }
          #ledger div { margin-top: 6px; }
          #ledger b { color: var(--ember); font-weight: 400; }
          ::selection { background: var(--ember); color: var(--night); }
        </style>
        </head>
        <body>
        <main>
          <header>
            <h1>the world, walking <span class="plus">&middot;</span> human+</h1>
            <span class="tickno" id="tick">tick 0</span>
            <form class="controls" id="incite-form">
              <input type="text" id="stimulus" placeholder="hand them something to talk about&hellip;">
              <button type="submit">incite</button>
              <button type="button" id="pause">pause</button>
            </form>
          </header>
          <div id="stagewrap"><div id="stage">
            <svg id="ground" viewBox="0 0 884 572" width="884" height="572"></svg>
            <svg id="actors" viewBox="0 0 884 572" width="884" height="572"></svg>
            <div id="bubbles"></div>
          </div></div>
          <div class="lower">
            <section class="panel"><h2>the record</h2><div id="feed"></div></section>
            <section class="panel"><h2>the grudge ledger</h2><div id="ledger"></div></section>
          </div>
        </main>
        <script>
        const SERIES = ['#3987e5', '#199e70', '#c98500', '#9085e9', '#e66767', '#d55181', '#d95926', '#008300'];
        const T = 26; // px per tile
        const color = i => SERIES[i % SERIES.length];
        const esc = s => String(s).replace(/[&<>]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]));
        const svgEl = (tag, attrs, text) => {
          const e = document.createElementNS('http://www.w3.org/2000/svg', tag);
          for (const k in attrs) e.setAttribute(k, attrs[k]);
          if (text != null) e.textContent = text;
          return e;
        };
        let paused = false, groundDrawn = false;
        const walkers = {};

        function drawGround(map) {
          const svg = document.getElementById('ground');
          for (let gx = 1; gx < map.w; gx++)
            svg.append(svgEl('line', { x1: gx * T, x2: gx * T, y1: 0, y2: map.h * T, stroke: '#1d211a', 'stroke-width': 1 }));
          for (let gy = 1; gy < map.h; gy++)
            svg.append(svgEl('line', { x1: 0, x2: map.w * T, y1: gy * T, y2: gy * T, stroke: '#1d211a', 'stroke-width': 1 }));
          map.trees.forEach(t => {
            svg.append(svgEl('circle', { cx: t.x * T, cy: t.y * T, r: 14, class: 'tree' }));
            svg.append(svgEl('circle', { cx: t.x * T - 5, cy: t.y * T - 6, r: 9, class: 'tree' }));
          });
          map.obstacles.forEach(o => {
            svg.append(svgEl('rect', { x: o.x * T, y: o.y * T, width: o.w * T, height: o.h * T, rx: 8, class: 'fixture' }));
            svg.append(svgEl('circle', { cx: o.x * T + 12, cy: o.y * T + 12, r: 3, class: 'lamp' }));
            svg.append(svgEl('text', { x: o.x * T + o.w * T / 2, y: o.y * T + o.h * T / 2 + 4,
              'text-anchor': 'middle', class: 'fixture-name' }, o.name));
          });
          groundDrawn = true;
        }

        function drawActors(s) {
          const svg = document.getElementById('actors');
          svg.querySelectorAll('.talkline, .ringwrap').forEach(e => e.remove());
          s.encounters.forEach(([a, b]) => {
            const wa = s.residents.find(r => r.name === a), wb = s.residents.find(r => r.name === b);
            if (wa && wb) svg.append(svgEl('line', { x1: wa.x * T, y1: wa.y * T, x2: wb.x * T, y2: wb.y * T, class: 'talkline' }));
          });
          s.residents.forEach((r, i) => {
            let g = walkers[r.name];
            if (!g) {
              g = svgEl('g', { class: 'walker' });
              const inner = svgEl('g', { class: 'pose' });
              inner.append(svgEl('ellipse', { cx: 0, cy: 13, rx: 9, ry: 3, fill: 'rgba(0,0,0,.45)' }));
              inner.append(svgEl('rect', { x: -6, y: -4, width: 12, height: 16, rx: 6, fill: color(i), class: 'body' }));
              inner.append(svgEl('circle', { cx: 0, cy: -10, r: 6, fill: color(i), class: 'head' }));
              g.append(inner);
              g.append(svgEl('text', { x: 0, y: 28, 'text-anchor': 'middle', class: 'wname' }, r.name));
              g.append(svgEl('text', { x: 0, y: 40, 'text-anchor': 'middle', class: 'wcal' }, ''));
              svg.append(g);
              walkers[r.name] = g;
            }
            g.style.transform = `translate(${(r.x * T).toFixed(1)}px, ${(r.y * T).toFixed(1)}px)`;
            const pose = g.querySelector('.pose');
            pose.setAttribute('transform', `scale(${r.facing},1)`);
            pose.classList.toggle('hurry', !r.emancipated);
            pose.classList.toggle('stroll', r.emancipated);
            if (r.emancipated) {
              pose.querySelector('.body').setAttribute('fill', 'var(--ink)');
              pose.querySelector('.head').setAttribute('fill', 'var(--ink)');
            }
            g.querySelector('.wcal').textContent = `${r.calibration} · ${r.pressure}`;
            if (r.reflecting) {
              const wrap = svgEl('g', { class: 'ringwrap', transform: `translate(${(r.x * T).toFixed(1)}, ${(r.y * T).toFixed(1)})` });
              wrap.append(svgEl('circle', { cx: 0, cy: 0, r: 14, class: 'ring' }));
              svg.append(wrap);
            }
          });
        }

        function drawBubbles(s) {
          const host = document.getElementById('bubbles');
          host.innerHTML = '';
          s.residents.forEach(r => {
            if (!r.bubble) return;
            const b = document.createElement('div');
            b.className = 'bubble' + (r.bubble.silence ? ' silence' : '');
            b.style.left = (r.x * T) + 'px';
            b.style.top = (r.y * T - 24) + 'px';
            b.innerHTML = esc(r.bubble.text) + (r.bubble.meta ? `<span class="meta">${esc(r.bubble.meta)}</span>` : '');
            host.append(b);
          });
        }

        function drawFeed(s) {
          document.getElementById('feed').innerHTML =
            s.feed.map((l, i) => `<div${i < 6 ? ' class="now"' : ''}>${esc(l)}</div>`).join('');
        }

        function drawLedger(s) {
          const rows = [];
          s.residents.forEach(r => { for (const [who, c] of Object.entries(r.grudges)) rows.push([r.name, who, c]); });
          document.getElementById('ledger').innerHTML = rows.length
            ? rows.map(([h, w, c]) => `<div>${esc(h)} &rarr; ${esc(w)} <b>${c}</b></div>`).join('')
            : '<div>empty — nothing below Courage is filing.</div>';
        }

        async function poll() {
          try {
            const s = await (await fetch('/state')).json();
            if (!groundDrawn) drawGround(s.map);
            document.getElementById('tick').textContent = `tick ${s.tick}` + (s.running ? '' : ' · paused');
            paused = !s.running;
            document.getElementById('pause').textContent = paused ? 'resume' : 'pause';
            drawActors(s); drawBubbles(s); drawFeed(s); drawLedger(s);
          } catch (e) { /* the world will come back */ }
          setTimeout(poll, 400);
        }
        document.getElementById('pause').addEventListener('click', () => {
          fetch('/control', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: 'action=' + (paused ? 'resume' : 'pause') });
        });
        document.getElementById('incite-form').addEventListener('submit', ev => {
          ev.preventDefault();
          const input = document.getElementById('stimulus');
          fetch('/incite', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: 'stimulus=' + encodeURIComponent(input.value) });
          input.value = '';
        });
        poll();
        </script>
        </body>
        </html>
      PAGE
    end
  end
end
