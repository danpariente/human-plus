# frozen_string_literal: true

require "json"
require_relative "town"

module HumanPlus
  class Town
    ##
    # The town, ticked — a run rendered as a single self-contained HTML
    # page. No dependencies, no network: inline CSS, inline SVG drawn by
    # inline JS, light and dark both. Open it in a browser.
    #
    # What it plots:
    #
    # * <b>Calibration over ticks</b>, one line per resident, with
    #   Courage (200) as the threshold line and a ring where a reflection
    #   happened — the whole book in one picture when one line climbs
    #   while the others sink.
    # * <b>Stored pressure over ticks</b> — suppression accumulates;
    #   surrender empties.
    # * <b>The grudge ledger</b> — attributed pressure still held, as
    #   bars (see Memory).
    # * The transcript and a table view of every sample, so nothing is
    #   readable by color alone.
    #
    # Usage (the CLI does this for you — <tt>bin/human+ town --chart</tt>):
    #
    #   chart = Town::Chart.new(town, stimulus)
    #   town.run(stimulus) { |tick, events| chart.record(tick, events) }
    #   File.write("town.html", chart.to_html)
    class Chart
      ##
      # A chart watches one town through one run. It snapshots the
      # starting state (tick zero) at construction.
      def initialize(town, stimulus)
        @town = town
        @stimulus = stimulus.to_s
        @ticks = []
        @calibration = Hash.new { |h, k| h[k] = [] }
        @pressure = Hash.new { |h, k| h[k] = [] }
        @reflections = []
        @transcript = []
        sample(0)
      end

      ##
      # Take the tick's sample: every resident's calibration and total
      # stored pressure, plus the events for the transcript and any
      # reflections for the markers. Call once per tick, from the
      # Town#run block.
      def record(tick, events)
        sample(tick)
        events.grep(Reflected).each do |e|
          @reflections << { tick: tick, name: e.actor, feeling: e.feeling }
        end
        @transcript << { tick: tick, lines: events.map { |e| line_for(e) } }
        self
      end

      ##
      # The samples, as data — everything the page is drawn from.
      # Grudges are computed here, at rendering time, because a grudge is
      # computed, never stored (see Memory#grudges).
      def data
        {
          stimulus: @stimulus,
          residents: @town.residents.map { |r| { name: r.name, awareness: r.awareness } },
          ticks: @ticks,
          calibration: @calibration,
          pressure: @pressure,
          reflections: @reflections,
          grudges: @town.residents.flat_map { |r|
            r.memory.grudges.map { |who, charge| { holder: r.name, against: who, charge: charge } }
          },
          transcript: @transcript
        }
      end

      ##
      # The page. Self-contained: hand it to a browser and nothing else.
      def to_html
        page(JSON.generate(data).gsub("</", "<\\/"))
      end

      private

      def sample(tick)
        @ticks << tick
        @town.residents.each do |r|
          @calibration[r.name] << r.human.calibration
          @pressure[r.name] << r.human.programs.sum(&:pressure)
        end
      end

      def line_for(event)
        case event
        when Reacted
          at = event.witnessed.reaction ? "#{event.witnessed.actor}'s :#{event.witnessed.reaction}" : event.witnessed.actor
          "#{event.actor} — #{event.feeling}(#{event.level}), pressure #{event.pressure} -> :#{event.reaction}, at #{at}"
        when Reflected
          "#{event.actor} reflects: #{event.insight} — lets go of #{event.feeling} (waves: #{event.waves.join(' ')}), calibration #{event.calibration}"
        when Radiated
          "#{event.actor} — #{event.state}(#{event.level}) -> :#{event.reaction}; unconditional, nothing below Courage to run"
        when Unmoved
          "#{event.actor} — nothing hooks; the stimulus passes through"
        else
          event.to_s
        end
      end

      def escape(text)
        text.gsub(/[&<>"]/, "&" => "&amp;", "<" => "&lt;", ">" => "&gt;", '"' => "&quot;")
      end

      def page(json)
        <<~HTML
          <!doctype html>
          <html lang="en">
          <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>human+ town</title>
          <style>
            body {
              --page: #f9f9f7; --surface-1: #fcfcfb; --text-primary: #0b0b0b;
              --text-secondary: #52514e; --muted: #898781; --grid: #e1e0d9;
              --baseline: #c3c2b7; --border: rgba(11,11,11,0.10);
              --series-0: #2a78d6; --series-1: #1baf7a; --series-2: #eda100;
              --series-3: #008300; --series-4: #4a3aa7; --series-5: #e34948;
              --series-6: #e87ba4; --series-7: #eb6834;
            }
            @media (prefers-color-scheme: dark) {
              body {
                --page: #0d0d0d; --surface-1: #1a1a19; --text-primary: #ffffff;
                --text-secondary: #c3c2b7; --muted: #898781; --grid: #2c2c2a;
                --baseline: #383835; --border: rgba(255,255,255,0.10);
                --series-0: #3987e5; --series-1: #199e70; --series-2: #c98500;
                --series-3: #008300; --series-4: #9085e9; --series-5: #e66767;
                --series-6: #d55181; --series-7: #d95926;
              }
            }
            body { margin: 0; background: var(--page); color: var(--text-primary);
                   font: 15px/1.5 system-ui, -apple-system, "Segoe UI", sans-serif; }
            main { max-width: 780px; margin: 0 auto; padding: 28px 20px 64px; }
            h1 { font-size: 21px; margin: 0 0 4px; }
            h2 { font-size: 15px; margin: 0 0 2px; }
            h3 { font-size: 13px; margin: 12px 0 4px; color: var(--text-secondary); }
            .sub { color: var(--text-secondary); font-size: 13.5px; margin: 0; }
            .note { color: var(--muted); font-size: 13px; margin: 0 0 10px; }
            .card { background: var(--surface-1); border: 1px solid var(--border);
                    border-radius: 10px; padding: 18px 20px; margin: 16px 0; }
            .legend { margin-bottom: 8px; }
            .chip { margin-right: 14px; font-size: 12.5px; color: var(--text-secondary); }
            .key { display: inline-block; width: 10px; height: 10px; border-radius: 3px;
                   margin-right: 5px; vertical-align: -1px; }
            .plot { position: relative; }
            svg { width: 100%; height: auto; display: block; }
            svg text { font-family: inherit; }
            .grid { stroke: var(--grid); stroke-width: 1; }
            .threshold { stroke: var(--muted); stroke-width: 1; stroke-dasharray: 4 3; }
            .hair { stroke: var(--baseline); stroke-width: 1; }
            .tick { fill: var(--muted); font-size: 11px; font-variant-numeric: tabular-nums; }
            .endlabel, .label { fill: var(--text-secondary); font-size: 12px; }
            .value { fill: var(--text-primary); font-size: 12px; font-variant-numeric: tabular-nums; }
            .tip { position: absolute; background: var(--surface-1); border: 1px solid var(--border);
                   border-radius: 6px; padding: 6px 9px; font-size: 12px; pointer-events: none;
                   box-shadow: 0 2px 8px rgba(0,0,0,0.12); white-space: nowrap; }
            .tip div { color: var(--text-secondary); }
            .tip b { font-variant-numeric: tabular-nums; }
            table { border-collapse: collapse; font-variant-numeric: tabular-nums;
                    font-size: 13px; width: 100%; }
            td, th { padding: 4px 10px; border-bottom: 1px solid var(--grid); text-align: right; }
            th { color: var(--text-secondary); font-weight: 600; }
            th:first-child, td:first-child { text-align: left; }
            details summary { cursor: pointer; font-size: 15px; font-weight: 600; }
            details[open] summary { margin-bottom: 8px; }
            .transcript ul { margin: 2px 0 10px; padding-left: 20px; }
            .transcript li { font-size: 13px; color: var(--text-secondary); }
          </style>
          </head>
          <body>
          <main>
            <header>
              <h1>The town, ticked</h1>
              <p class="sub">the world incited: &ldquo;#{escape(@stimulus)}&rdquo;</p>
            </header>

            <section class="card">
              <h2>Calibration</h2>
              <p class="note">where each resident sits on the Map of Consciousness — Courage (200) is the threshold; a ring marks a reflection</p>
              <div class="legend" data-legend></div>
              <div class="plot" id="calibration"></div>
            </section>

            <section class="card">
              <h2>Stored pressure</h2>
              <p class="note">total pressure across installed programs — suppression accumulates; surrender empties</p>
              <div class="legend" data-legend></div>
              <div class="plot" id="pressure"></div>
            </section>

            <section class="card">
              <h2>The grudge ledger</h2>
              <p class="note">attributed pressure still held — a grudge dissolves with its program</p>
              <div id="grudges"></div>
            </section>

            <details class="card">
              <summary>Table view</summary>
              <div id="table-view"></div>
            </details>

            <details class="card transcript">
              <summary>Transcript</summary>
              <div id="transcript"></div>
            </details>
          </main>
          <script>
          const DATA = #{json};

          const mk = (tag, attrs, text) => {
            const e = document.createElementNS('http://www.w3.org/2000/svg', tag);
            for (const k in attrs) e.setAttribute(k, attrs[k]);
            if (text != null) e.textContent = text;
            return e;
          };
          const css = name => getComputedStyle(document.body).getPropertyValue(name).trim();
          // Fixed slots in fixed order, never cycled; past 8, the tail folds to muted.
          const seriesColor = i => i < 8 ? css('--series-' + i) : css('--muted');
          const esc = s => String(s).replace(/[&<>]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]));
          const names = DATA.residents.map(r => r.name);

          function niceTicks(lo, hi, n) {
            const raw = (hi - lo) / n, pow = Math.pow(10, Math.floor(Math.log10(raw)));
            const step = [1, 2, 5, 10].map(m => m * pow).find(s => (hi - lo) / s <= n) || pow * 10;
            const out = [];
            for (let v = Math.ceil(lo / step) * step; v <= hi; v += step) out.push(Math.round(v));
            return out;
          }

          function lineChart(el, series, opts) {
            el.innerHTML = '';
            const W = 720, H = 240, L = 46, R = 84, T = 14, B = 26;
            const xs = DATA.ticks, span = Math.max(1, xs[xs.length - 1] - xs[0]);
            const all = names.flatMap(n => series[n]);
            const lo = 0, hi = Math.max(...all, opts.atLeast || 0) * 1.08 || 1;
            const x = t => L + (W - L - R) * (t - xs[0]) / span;
            const y = v => T + (H - T - B) * (1 - (v - lo) / (hi - lo));

            const svg = mk('svg', { viewBox: '0 0 ' + W + ' ' + H, role: 'img', 'aria-label': opts.label });
            niceTicks(lo, hi, 4).forEach(v => {
              svg.append(mk('line', { x1: L, x2: W - R, y1: y(v), y2: y(v), class: 'grid' }));
              svg.append(mk('text', { x: L - 6, y: y(v) + 3, 'text-anchor': 'end', class: 'tick' }, v));
            });
            const xstep = Math.max(1, Math.ceil(span / 12));
            xs.forEach(t => {
              if (t % xstep) return;
              svg.append(mk('text', { x: x(t), y: H - 8, 'text-anchor': 'middle', class: 'tick' }, t));
            });
            if (opts.threshold != null && opts.threshold < hi) {
              svg.append(mk('line', { x1: L, x2: W - R, y1: y(opts.threshold), y2: y(opts.threshold), class: 'threshold' }));
              svg.append(mk('text', { x: L + 4, y: y(opts.threshold) - 5, class: 'tick' }, opts.thresholdLabel));
            }

            names.forEach((n, i) => {
              const pts = series[n].map((v, j) => [x(xs[j]), y(v)]);
              svg.append(mk('path', { d: 'M' + pts.map(p => p[0].toFixed(1) + ' ' + p[1].toFixed(1)).join(' L'),
                fill: 'none', stroke: seriesColor(i), 'stroke-width': 2,
                'stroke-linejoin': 'round', 'stroke-linecap': 'round' }));
              const end = pts[pts.length - 1];
              svg.append(mk('circle', { cx: end[0], cy: end[1], r: 4.5, fill: seriesColor(i),
                stroke: css('--surface-1'), 'stroke-width': 2 }));
            });

            // Direct end labels — only when they don't collide; the legend always carries identity.
            const ends = names.map((n, i) => ({ n, y: y(series[n][series[n].length - 1]) }))
                              .sort((a, b) => a.y - b.y);
            if (ends.every((e, k) => k === 0 || e.y - ends[k - 1].y >= 12))
              ends.forEach(e => svg.append(mk('text', { x: W - R + 10, y: e.y + 3, class: 'endlabel' }, e.n)));

            (opts.marks || []).forEach(m => {
              const j = xs.indexOf(m.tick), i = names.indexOf(m.name);
              if (j < 0 || i < 0) return;
              svg.append(mk('circle', { cx: x(m.tick), cy: y(series[m.name][j]), r: 6.5, fill: 'none',
                stroke: seriesColor(i), 'stroke-width': 2 }));
            });

            const hair = mk('line', { y1: T, y2: H - B, class: 'hair', visibility: 'hidden' });
            svg.append(hair);
            const tip = document.createElement('div');
            tip.className = 'tip'; tip.hidden = true; el.append(tip);
            svg.addEventListener('mousemove', ev => {
              const rect = svg.getBoundingClientRect();
              const px = (ev.clientX - rect.left) * (W / rect.width);
              let best = 0, bd = Infinity;
              xs.forEach((t, j) => { const d = Math.abs(x(t) - px); if (d < bd) { bd = d; best = j; } });
              const t = xs[best];
              hair.setAttribute('x1', x(t)); hair.setAttribute('x2', x(t)); hair.removeAttribute('visibility');
              tip.hidden = false;
              tip.innerHTML = '<b>tick ' + t + '</b>' + names.map((n, i) =>
                '<div><span class="key" style="background:' + seriesColor(i) + '"></span>' +
                esc(n) + ' &nbsp;<b>' + series[n][best] + '</b></div>').join('');
              tip.style.left = Math.min(x(t) / W * rect.width + 12, rect.width - tip.offsetWidth - 4) + 'px';
              tip.style.top = '8px';
            });
            svg.addEventListener('mouseleave', () => { hair.setAttribute('visibility', 'hidden'); tip.hidden = true; });
            el.append(svg);
          }

          function roundedRight(x, y, w, h, r) {
            r = Math.min(r, w);
            return 'M' + x + ' ' + y + ' h' + (w - r) + ' a' + r + ' ' + r + ' 0 0 1 ' + r + ' ' + r +
                   ' v' + (h - 2 * r) + ' a' + r + ' ' + r + ' 0 0 1 ' + (-r) + ' ' + r +
                   ' h' + (r - w) + ' Z';
          }

          function grudgeChart(el) {
            el.innerHTML = '';
            const g = DATA.grudges;
            if (!g.length) {
              el.innerHTML = '<p class="note">no grudges held — nothing below Courage is filing.</p>';
              return;
            }
            const max = Math.max(...g.map(d => d.charge));
            const W = 720, rowH = 32, L = 170, R = 44, barH = 18;
            const svg = mk('svg', { viewBox: '0 0 ' + W + ' ' + (g.length * rowH + 6), role: 'img',
              'aria-label': 'grudge ledger' });
            g.forEach((d, k) => {
              const yy = k * rowH + 6;
              const w = Math.max(2, (W - L - R) * d.charge / max);
              svg.append(mk('text', { x: L - 8, y: yy + barH / 2 + 4, 'text-anchor': 'end', class: 'label' },
                d.holder + ' \\u2192 ' + d.against));
              svg.append(mk('path', { d: roundedRight(L, yy, w, barH, 4), fill: css('--series-0') }));
              svg.append(mk('text', { x: L + w + 6, y: yy + barH / 2 + 4, class: 'value' }, d.charge));
            });
            el.append(svg);
          }

          function legends() {
            document.querySelectorAll('[data-legend]').forEach(el => {
              el.innerHTML = DATA.residents.map((r, i) =>
                '<span class="chip"><span class="key" style="background:' + seriesColor(i) + '"></span>' +
                esc(r.name) + (r.awareness ? ' (reflects at ' + r.awareness.toLocaleString() + ' thoughts)' : '') +
                '</span>').join('');
            });
          }

          function tableView() {
            let h = '<table><thead><tr><th>tick</th>' + names.map(n =>
              '<th>' + esc(n) + ' calibration</th><th>' + esc(n) + ' pressure</th>').join('') +
              '</tr></thead><tbody>';
            DATA.ticks.forEach((t, j) => {
              h += '<tr><td>' + t + '</td>' + names.map(n =>
                '<td>' + DATA.calibration[n][j] + '</td><td>' + DATA.pressure[n][j] + '</td>').join('') + '</tr>';
            });
            document.getElementById('table-view').innerHTML = h + '</tbody></table>';
          }

          function transcript() {
            document.getElementById('transcript').innerHTML = DATA.transcript.map(t =>
              '<h3>tick ' + t.tick + '</h3><ul>' +
              t.lines.map(l => '<li>' + esc(l) + '</li>').join('') + '</ul>').join('');
          }

          function render() {
            legends();
            lineChart(document.getElementById('calibration'), DATA.calibration,
              { label: 'calibration over ticks', threshold: 200, thresholdLabel: 'Courage 200',
                atLeast: 220, marks: DATA.reflections });
            lineChart(document.getElementById('pressure'), DATA.pressure,
              { label: 'stored pressure over ticks' });
            grudgeChart(document.getElementById('grudges'));
          }

          render();
          tableView();
          transcript();
          matchMedia('(prefers-color-scheme: dark)').addEventListener('change', render);
          </script>
          </body>
          </html>
        HTML
      end
    end
  end
end
