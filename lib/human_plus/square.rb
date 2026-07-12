# frozen_string_literal: true

require "socket"
require "json"
require "uri"
require "csv"
require_relative "town"

module HumanPlus
  class Town
    ##
    # The town square, served — ai-town's other half: the engine loop and
    # the window you watch it through.
    #
    # ai-town runs a server-side game loop over multiple agents and
    # renders them live in a browser. So does this, in stdlib Ruby and
    # nothing else: a background thread ticks the Town on an interval
    # (the loop), every resident is an agent on the same firmware (the
    # multiple agents), and a tiny HTTP server — +socket+, by hand —
    # serves one self-contained page that polls <tt>/state</tt> and
    # draws the square.
    #
    # The world keeps the loop alive: whenever the town goes quiet, the
    # next stimulus from the rotation (data/stimuli.csv) is incited.
    # That is the world's job, and it never runs out.
    #
    #   square = Town::Square.new(town)
    #   port = square.serve(4200)   # the window
    #   square.run_loop             # the loop
    #
    # Controls, over HTTP: <tt>POST /control</tt> (+action+ =
    # pause | resume | step) and <tt>POST /incite</tt> (+stimulus+ = your
    # own words into the air). The server binds 127.0.0.1 only.
    class Square
      # The engine cadence, in seconds.
      TICK_EVERY = 1.6

      # Where the world's rotation of stimuli comes from.
      STIMULI = File.expand_path("../../data/stimuli.csv", __dir__)

      ##
      # +stimuli+ is an Enumerator the world draws from when the town is
      # quiet; it defaults to cycling data/stimuli.csv.
      def initialize(town, every: TICK_EVERY, stimuli: nil)
        @town = town
        @every = every
        @stimuli = stimuli || CSV.read(STIMULI, headers: true).map { |row| row["stimulus"] }.cycle
        @mutex = Mutex.new
        @tick = 0
        @running = true
        @stimulus = nil
        @last = {}
        @reflections = []
        @feed = []
      end

      ##
      # One turn of the engine: incite when quiet (the world's job),
      # tick when not. Everything the page needs is captured here.
      def step
        @mutex.synchronize do
          @last = {}
          @reflections = []
          if @town.quiet?
            @stimulus = @stimuli.next.to_s
            @town.incite(@stimulus)
            file %(the world incites: "#{@stimulus}")
          else
            @tick += 1
            file "tick #{@tick}"
            @town.tick.each do |event|
              file "  #{Town.describe(event)}"
              remember(event)
            end
          end
        end
        self
      end

      ##
      # Everything the window shows, as one snapshot.
      def state
        @mutex.synchronize do
          {
            tick: @tick,
            running: @running,
            stimulus: @stimulus,
            residents: @town.residents.map { |r|
              {
                name: r.name,
                calibration: r.human.calibration,
                pressure: r.human.programs.sum(&:pressure),
                programs: r.human.programs.size,
                aware: r.aware?,
                emancipated: r.human.emancipated?,
                grudges: r.memory.grudges,
                last: @last[r.name]
              }
            },
            air: @town.air.map { |w| { actor: w.actor, reaction: w.reaction, text: w.text } },
            reflections: @reflections,
            feed: @feed.last(80).reverse
          }
        end
      end

      ##
      # pause | resume | step — the three things a watcher may do to the
      # loop.
      def control(action)
        case action.to_s
        when "pause" then @running = false
        when "resume" then @running = true
        when "step" then step
        end
      end

      ##
      # Your own words into the air. The world defers to you.
      def incite(stimulus)
        return if stimulus.to_s.strip.empty?

        @mutex.synchronize do
          @stimulus = stimulus.to_s
          @town.incite(@stimulus)
          file %(you incite: "#{@stimulus}")
        end
      end

      ##
      # The window: serve the page and the state on 127.0.0.1. Returns
      # the bound port (pass 0 to let the OS pick).
      def serve(port = 0)
        @server = TCPServer.new("127.0.0.1", port)
        @acceptor = Thread.new do
          loop do
            client = begin
              @server.accept
            rescue IOError, Errno::EBADF
              break
            end
            Thread.new(client) { |c| handle(c) }
          end
        end
        @server.addr[1]
      end

      ##
      # The loop: tick on the cadence until #stop.
      def run_loop
        @ticker = Thread.new do
          loop do
            sleep @every
            step if @running
          end
        end
        self
      end

      def stop
        @server&.close
        @ticker&.kill
        @acceptor&.kill
        self
      end

      private

      def file(line) = @feed << line

      def remember(event)
        case event
        when Reacted
          @last[event.actor] = { kind: "reacted", feeling: event.feeling, level: event.level,
                                 pressure: event.pressure, reaction: event.reaction,
                                 at: event.witnessed.actor, at_reaction: event.witnessed.reaction }
        when Reflected
          @reflections << { name: event.actor, feeling: event.feeling }
        when Radiated
          @last[event.actor] = { kind: "radiated", feeling: event.state, level: event.level,
                                 reaction: event.reaction }
        when Unmoved
          @last[event.actor] = { kind: "unmoved" }
        end
      end

      def handle(client)
        request = client.gets or return client.close
        method, raw_path, = request.split
        headers = {}
        while (line = client.gets) && line != "\r\n"
          key, value = line.split(": ", 2)
          headers[key.to_s.downcase] = value.to_s.strip
        end
        length = headers["content-length"].to_i
        body = length.positive? ? client.read(length) : ""
        params = URI.decode_www_form(body).to_h

        case [method, raw_path.to_s.split("?").first]
        when ["GET", "/"] then respond(client, 200, "text/html; charset=utf-8", PAGE)
        when ["GET", "/state"] then respond(client, 200, "application/json", JSON.generate(state))
        when ["POST", "/control"]
          control(params["action"])
          respond(client, 200, "application/json", %({"ok":true}))
        when ["POST", "/incite"]
          incite(params["stimulus"])
          respond(client, 200, "application/json", %({"ok":true}))
        else
          respond(client, 404, "text/plain", "nothing here hooks")
        end
      rescue IOError, Errno::EPIPE, Errno::ECONNRESET
        nil
      ensure
        client.close rescue nil
      end

      def respond(client, code, type, content)
        reason = { 200 => "OK", 404 => "Not Found" }.fetch(code, "OK")
        client.write "HTTP/1.1 #{code} #{reason}\r\n" \
                     "Content-Type: #{type}\r\n" \
                     "Content-Length: #{content.bytesize}\r\n" \
                     "Connection: close\r\n\r\n"
        client.write content
      end

      # The window itself. One page, no dependencies, no interpolation —
      # everything arrives by polling /state. The night is deliberate:
      # programs flicker; states are still.
      PAGE = <<~'PAGE'
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>the town, alive</title>
        <style>
          :root {
            --night: #131110; --panel: #1b1815; --panel-2: #221e1a;
            --ink: #ece7dd; --dim: #8f877a; --faint: #575046;
            --line: #2b2723; --courage: #e8dfc9; --ember: #c98500;
            --serif: "Iowan Old Style", Palatino, "Book Antiqua", Georgia, serif;
            --mono: ui-monospace, "SF Mono", Menlo, Consolas, monospace;
          }
          * { box-sizing: border-box; }
          body {
            margin: 0; background: var(--night); color: var(--ink);
            font: 15px/1.5 var(--serif);
            background-image: radial-gradient(ellipse 90% 60% at 50% -10%, #1e1a15 0%, var(--night) 70%);
            min-height: 100vh;
          }
          main { max-width: 1060px; margin: 0 auto; padding: 26px 22px 60px; }
          header { display: flex; align-items: baseline; gap: 18px; flex-wrap: wrap; margin-bottom: 18px; }
          h1 { font-size: 26px; font-weight: 500; font-style: italic; margin: 0; letter-spacing: .01em; }
          h1 .plus { color: var(--ember); font-style: normal; }
          .pulse { display: inline-block; width: 9px; height: 9px; border-radius: 50%;
                   background: var(--ember); vertical-align: baseline; margin-right: 10px;
                   animation: breathe 3.2s ease-in-out infinite; }
          @keyframes breathe { 0%,100% { opacity: .35; } 50% { opacity: 1; } }
          .tickno { font-family: var(--mono); font-size: 12px; color: var(--dim); }
          .controls { margin-left: auto; display: flex; gap: 8px; }
          input[type=text] {
            background: var(--panel); color: var(--ink); border: 1px solid var(--line);
            border-radius: 6px; padding: 7px 11px; font: 13px var(--serif); font-style: italic;
            width: 300px; outline: none;
          }
          input[type=text]:focus { border-color: var(--ember); }
          button {
            background: var(--panel-2); color: var(--ink); border: 1px solid var(--line);
            border-radius: 6px; padding: 7px 14px; font: 12px var(--mono); cursor: pointer;
          }
          button:hover { border-color: var(--ember); color: var(--ember); }
          .stage { display: grid; grid-template-columns: 1fr 200px; gap: 16px; }
          .panel { background: var(--panel); border: 1px solid var(--line); border-radius: 12px; }
          .panel h2 {
            font: italic 500 13px var(--serif); color: var(--dim); margin: 0;
            padding: 12px 16px 0;
          }
          #square svg, #map svg { width: 100%; height: auto; display: block; }
          .lower { display: grid; grid-template-columns: 1fr 280px; gap: 16px; margin-top: 16px; }
          #feed { font: 12px/1.75 var(--mono); color: var(--dim); padding: 10px 16px 14px;
                  max-height: 300px; overflow-y: auto; white-space: pre-wrap; }
          #feed .now { color: var(--ink); }
          #air { padding: 4px 16px 12px; font-style: italic; color: var(--dim); font-size: 13px; }
          #air div { margin-top: 4px; }
          #air b { color: var(--ember); font-style: normal; font-family: var(--mono); font-weight: 400; font-size: 11px; }
          #ledger { padding: 10px 16px 16px; }
          .grudge { display: flex; align-items: center; gap: 8px; margin-top: 7px;
                    font: 12px var(--mono); color: var(--dim); }
          .grudge .bar { height: 6px; border-radius: 3px; background: var(--ember); opacity: .75; }
          svg text { font-family: var(--mono); }
          .name { fill: var(--ink); font-family: var(--serif); font-style: italic; font-size: 14px; }
          .cal { fill: var(--dim); font-size: 10.5px; }
          .chip { fill: var(--ember); font-size: 11px; }
          .chipbg { fill: var(--panel-2); stroke: var(--line); }
          .quiet-note { fill: var(--faint); font-size: 11px; }
          .maplabel { fill: var(--faint); font-size: 9.5px; }
          .courage-line { stroke: var(--courage); stroke-width: 1; stroke-dasharray: 5 4; opacity: .5; }
          .courage-word { fill: var(--courage); font-size: 10px; font-style: italic; font-family: var(--serif); }
          .arc { fill: none; stroke: var(--ember); stroke-width: 1.4; opacity: .8;
                 stroke-dasharray: 6 5; animation: travel 1.2s linear infinite; }
          @keyframes travel { to { stroke-dashoffset: -22; } }
          .dot { transition: opacity .5s; }
          .dot.program { animation: flicker 2.6s ease-in-out infinite; }
          @keyframes flicker { 0%,100% { opacity: .95; } 38% { opacity: .68; } 55% { opacity: .9; } 70% { opacity: .74; } }
          .dot.still { animation: none; filter: drop-shadow(0 0 16px rgba(236,231,221,.5)); }
          .ring { fill: none; stroke: var(--courage); stroke-width: 2;
                  animation: letgo 1.8s ease-out infinite; }
          @keyframes letgo { from { opacity: .9; r: 26; } to { opacity: 0; r: 56; } }
          .mapdot { transition: transform 1s cubic-bezier(.4,0,.2,1); }
          #map { position: sticky; top: 16px; }
          ::selection { background: var(--ember); color: var(--night); }
        </style>
        </head>
        <body>
        <main>
          <header>
            <h1><span class="pulse"></span>the town, alive <span class="plus">·</span> human+</h1>
            <span class="tickno" id="tick">tick 0</span>
            <form class="controls" id="incite-form">
              <input type="text" id="stimulus" placeholder="put something in the air&hellip;">
              <button type="submit">incite</button>
              <button type="button" id="pause">pause</button>
            </form>
          </header>

          <div class="stage">
            <section class="panel" id="square"><h2>the square — programs flicker; states are still</h2></section>
            <section class="panel" id="map"><h2>the Map</h2></section>
          </div>

          <section class="panel" style="margin-top:16px">
            <h2>in the air</h2>
            <div id="air"></div>
          </section>

          <div class="lower">
            <section class="panel"><h2>the record</h2><div id="feed"></div></section>
            <section class="panel"><h2>the grudge ledger</h2><div id="ledger"></div></section>
          </div>
        </main>
        <script>
        const SERIES = ['#3987e5', '#199e70', '#c98500', '#9085e9', '#e66767', '#d55181', '#d95926', '#008300'];
        const LEVELS = { shame: 20, guilt: 30, apathy: 50, grief: 75, fear: 100, desire: 125, anger: 150,
                         pride: 175, courage: 200, neutrality: 250, willingness: 310, acceptance: 350,
                         reason: 400, love: 500, joy: 540, peace: 600, enlightenment: 700 };
        const color = i => SERIES[i % SERIES.length];
        const esc = s => String(s).replace(/[&<>]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]));
        const svgEl = (tag, attrs, text) => {
          const e = document.createElementNS('http://www.w3.org/2000/svg', tag);
          for (const k in attrs) e.setAttribute(k, attrs[k]);
          if (text != null) e.textContent = text;
          return e;
        };

        let paused = false;

        function drawSquare(s) {
          const host = document.getElementById('square');
          host.querySelector('svg')?.remove();
          const W = 780, H = 520, CX = W / 2, CY = H / 2 + 8;
          const svg = svgEl('svg', { viewBox: `0 0 ${W} ${H}` });
          const n = s.residents.length;
          const pos = { 'the world': [CX, CY] };
          s.residents.forEach((r, i) => {
            const a = (i / n) * 2 * Math.PI - Math.PI / 2;
            pos[r.name] = [CX + 265 * Math.cos(a), CY + 185 * Math.sin(a)];
          });

          // the world, at the center — where stimuli come from
          svg.append(svgEl('circle', { cx: CX, cy: CY, r: 5, fill: 'var(--faint)' }));
          svg.append(svgEl('text', { x: CX, y: CY + 20, 'text-anchor': 'middle', class: 'quiet-note' }, 'the world'));

          // contagion arcs: from what was witnessed to who reacted
          s.residents.forEach(r => {
            if (!r.last || r.last.kind !== 'reacted' || !pos[r.last.at]) return;
            const [x1, y1] = pos[r.last.at], [x2, y2] = pos[r.name];
            const mx = (x1 + x2) / 2 + (CY - (y1 + y2) / 2) * 0.25;
            const my = (y1 + y2) / 2 + ((x1 + x2) / 2 - CX) * 0.25;
            svg.append(svgEl('path', { d: `M${x1} ${y1} Q${mx} ${my} ${x2} ${y2}`, class: 'arc' }));
          });

          s.residents.forEach((r, i) => {
            const [x, y] = pos[r.name];
            const g = svgEl('g', {});
            if (s.reflections.some(f => f.name === r.name))
              g.append(svgEl('circle', { cx: x, cy: y, r: 26, class: 'ring' }));
            g.append(svgEl('circle', {
              cx: x, cy: y, r: 22 + Math.min(10, r.pressure / 14),
              fill: r.emancipated ? 'var(--ink)' : color(i),
              class: 'dot ' + (r.emancipated ? 'still' : 'program'),
              style: `animation-delay:${(i * 0.45).toFixed(2)}s`
            }));
            g.append(svgEl('text', { x, y: y + 48, 'text-anchor': 'middle', class: 'name' }, r.name));
            g.append(svgEl('text', { x, y: y + 63, 'text-anchor': 'middle', class: 'cal' },
              `${r.calibration} · pressure ${r.pressure}`));
            if (r.last && r.last.kind === 'reacted') {
              const label = `:${r.last.reaction} — ${r.last.feeling} ${r.last.level}`;
              const w = label.length * 6.6 + 16;
              g.append(svgEl('rect', { x: x - w / 2, y: y - 52, width: w, height: 20, rx: 10, class: 'chipbg' }));
              g.append(svgEl('text', { x, y: y - 38, 'text-anchor': 'middle', class: 'chip' }, label));
            } else if (r.last && r.last.kind === 'radiated') {
              const label = `:${r.last.reaction} — unconditional`;
              const w = label.length * 6.6 + 16;
              g.append(svgEl('rect', { x: x - w / 2, y: y - 52, width: w, height: 20, rx: 10, class: 'chipbg' }));
              g.append(svgEl('text', { x, y: y - 38, 'text-anchor': 'middle', class: 'chip' }, label));
            } else if (r.last && r.last.kind === 'unmoved') {
              g.append(svgEl('text', { x, y: y - 40, 'text-anchor': 'middle', class: 'quiet-note' }, 'nothing hooks'));
            }
            svg.append(g);
          });
          host.append(svg);
        }

        function drawMap(s) {
          const host = document.getElementById('map');
          host.querySelector('svg')?.remove();
          const W = 200, H = 520, T = 26, B = 20;
          const y = v => T + (H - T - B) * (1 - Math.sqrt(v / 700));
          const svg = svgEl('svg', { viewBox: `0 0 ${W} ${H}` });
          for (const [name, level] of Object.entries(LEVELS)) {
            svg.append(svgEl('text', { x: 12, y: y(level) + 3, class: 'maplabel' }, `${level} ${name}`));
          }
          svg.append(svgEl('line', { x1: 8, x2: W - 12, y1: y(200), y2: y(200), class: 'courage-line' }));
          svg.append(svgEl('text', { x: W - 14, y: y(200) - 6, 'text-anchor': 'end', class: 'courage-word' }, 'the threshold'));
          s.residents.forEach((r, i) => {
            const g = svgEl('g', { class: 'mapdot', style: `transform: translateY(${y(r.calibration).toFixed(1)}px)` });
            g.append(svgEl('circle', { cx: 128 + (i % 3) * 18, cy: 0, r: 6,
              fill: r.emancipated ? 'var(--ink)' : color(i),
              stroke: 'var(--night)', 'stroke-width': 2 }));
            svg.append(g);
          });
          host.append(svg);
        }

        function drawAir(s) {
          document.getElementById('air').innerHTML = s.air.length
            ? s.air.map(w => `<div><b>${esc(w.actor)}${w.reaction ? ' :' + esc(w.reaction) : ''}</b> &ldquo;${esc(w.text)}&rdquo;</div>`).join('')
            : '<div>still air. the world is about to speak.</div>';
        }

        function drawFeed(s) {
          document.getElementById('feed').innerHTML =
            s.feed.map((l, i) => `<div${i < 8 ? ' class="now"' : ''}>${esc(l)}</div>`).join('');
        }

        function drawLedger(s) {
          const rows = [];
          s.residents.forEach(r => {
            for (const [who, charge] of Object.entries(r.grudges)) rows.push([r.name, who, charge]);
          });
          const max = Math.max(1, ...rows.map(r => r[2]));
          document.getElementById('ledger').innerHTML = rows.length
            ? rows.map(([holder, who, charge]) =>
                `<div class="grudge"><span>${esc(holder)} &rarr; ${esc(who)}</span>` +
                `<span class="bar" style="width:${(90 * charge / max).toFixed(0)}px"></span>` +
                `<span>${charge}</span></div>`).join('')
            : '<div class="grudge">empty — nothing below Courage is filing.</div>';
        }

        async function poll() {
          try {
            const s = await (await fetch('/state')).json();
            document.getElementById('tick').textContent =
              `tick ${s.tick}` + (s.running ? '' : ' · paused');
            paused = !s.running;
            document.getElementById('pause').textContent = paused ? 'resume' : 'pause';
            drawSquare(s); drawMap(s); drawAir(s); drawFeed(s); drawLedger(s);
          } catch (e) { /* the town will come back */ }
          setTimeout(poll, 800);
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
