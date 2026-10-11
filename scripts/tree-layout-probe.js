/*
  Measures dagre layout alternatives against a rendered tech-tree viewer. The instrument behind
  realistic-fusion-refreshed's docs/research/tree-layout-levers.md and the rank-split sweep in it
  (realistic-fusion-refreshed#182). The probe came here from that repository with the viewer, at
  c48fadf (grado-factorio-tools#101); the note stayed there.

  A PROBE, NOT A CHECK. It asserts nothing: it lays the same graph out several ways and prints what
  each one costs. Which way is better is a judgement, and the answer has already differed by lane.

  HOW TO RUN IT

    1. Render a set:   pwsh -File scripts/tree-viewer.ps1 .mod-cache/angels -OutName angels-lane
    2. Open tree-viewer-out/angels-lane.html in Chrome and WAIT for the cards to appear. The probe
       reads its node sizes off the rendered cards, so there have to be cards.
    3. Paste this whole file into the console.
    4. RIG.start('TB')  — or 'LR'. It yields between layouts; poll RIG.stage and RIG.rows.
    5. RIG.table()      — a markdown table of everything measured so far.

  Rows accumulate across sweeps, so a TB run and an LR run land in one table; RIG.clear() starts
  over. A third argument narrows the split to ranks holding more than n cards:
  RIG.start('TB', ['graph/floor', 'graph/ceil'], 12).

  WHY IT READS THE DOM FOR NODE SIZES

  The viewer computes each card's height from its unlock count and a measured head, and the levers
  note records three separate occasions where a MODEL of the card disagreed with the card. So this
  does not re-derive the formula: it reads offsetWidth/offsetHeight off the cards the viewer drew.
  A probe that cannot drift from the render is worth more than one that is merely shorter.

  WHAT A ROW MEANS

  Edge length is the summed segment length of the polyline dagre returns -- what the eye follows.
  Scaffolding edges (below) are marked and are never counted, never drawn, and never reported.

  THE RANK SPLIT (realistic-fusion-refreshed#182)

  "Use more ranks so each holds fewer cards" cannot be asked of dagre directly; minlen only scales
  the same ranks apart. It needs scaffolding edges between cards that currently SHARE a rank, which
  means laying out twice -- once to learn the ranks, once with the scaffolding in. Within a rank of
  n cards, ordered by `order`, the split takes the first k as the upper half and the rest as the
  lower, and joins them pairwise; `half` is where k falls on an odd n. That tie-break is not
  cosmetic -- see the note.

    order  graph  the order the viewer added the nodes
           x      by cross-rank coordinate in the first layout, ascending
           xrev   the same, descending
    half   floor  k = floor(n/2)
           ceil   k = ceil(n/2)
           alt    no block split at all: even indices up, odd indices down
*/
window.RIG = (function () {
  const sizes = new Map();

  /* Every card the viewer has drawn, at the size it drew it. Throws rather than guessing: an empty
     map would silently measure a graph of zero-sized nodes and report a plausible-looking canvas. */
  function sizeAll() {
    sizes.clear();
    for (const c of document.querySelectorAll('#world .card')) {
      sizes.set(c.dataset.id, { width: c.offsetWidth, height: c.offsetHeight });
    }
    if (!sizes.size) throw new Error('no rendered cards found — let the viewer finish drawing first');
    return sizes.size;
  }

  function layout(rankdir, scaffold, opts) {
    const g = new dagre.graphlib.Graph().setGraph(
      Object.assign({ rankdir, nodesep: 16, ranksep: 90, marginx: 40, marginy: 40 }, opts || {}));
    g.setDefaultEdgeLabel(() => ({}));
    for (const t of techs) {
      const size = sizes.get(t.id);
      /* A node with no width or height lays out to NaN and still reports a plausible-looking
         canvas, so this is loud rather than tolerant. It happens when the show-dead toggle changed
         `techs` after sizeAll() ran: size the cards again. */
      if (!size) throw new Error(`no rendered card for ${t.id} — call RIG.sizeAll() again`);
      g.setNode(t.id, Object.assign({}, size));
    }
    for (const [a, b] of edges) g.setEdge(a, b);
    /* Scaffolding joins two cards of the SAME rank, so no real edge can already connect them in
       either direction and none of these can close a cycle. */
    if (scaffold) for (const [a, b] of scaffold) g.setEdge(a, b, { sc: 1 });
    const t0 = performance.now();
    dagre.layout(g);
    return { g, ms: Math.round(performance.now() - t0) };
  }

  function stats(g) {
    const lens = [];
    for (const e of g.edges()) {
      const lbl = g.edge(e);
      if (lbl.sc) continue;                        // scaffolding is never counted
      const p = lbl.points;
      let s = 0;
      for (let i = 1; i < p.length; i++) s += Math.hypot(p[i].x - p[i - 1].x, p[i].y - p[i - 1].y);
      lens.push(s);
    }
    lens.sort((a, b) => a - b);
    return {
      W: Math.round(g.graph().width), H: Math.round(g.graph().height),
      total: Math.round(lens.reduce((a, b) => a + b, 0)),
      median: Math.round(lens[lens.length >> 1]),
      longest: Math.round(lens[lens.length - 1]),
      realEdges: lens.length, ranks: ranksOf(g, g.graph().rankdir).length
    };
  }

  /* dagre gives every node in a rank the same coordinate along the rank axis -- positionY assigns
     one y per layer -- so grouping by it recovers the layering exactly, with no access to dagre's
     internals. Dummy nodes never appear: layout() writes back only to the graph it was given.

     Upper-cased on the way in because dagre is not: it lower-cases rankdir internally and lays out
     correctly either way, so a 'tb' passed in here would lay out top-down and then be MEASURED
     across the wrong axis -- ranks recovered from the cross coordinate, scaffolding joining cards
     that share no rank, and a full table of numbers with nothing raised. */
  const rankKey = rd => (String(rd).toUpperCase() === 'TB' || String(rd).toUpperCase() === 'BT') ? 'y' : 'x';
  const crossKey = rd => rankKey(rd) === 'y' ? 'x' : 'y';

  function ranksOf(g, rd) {
    const k = rankKey(rd), m = new Map();
    for (const id of g.nodes()) {
      const v = g.node(id)[k];
      if (!m.has(v)) m.set(v, []);
      m.get(v).push(id);                           // insertion order within the rank
    }
    return [...m.entries()].sort((a, b) => a[0] - b[0]).map(e => e[1]);
  }

  /* minSize leaves narrow ranks alone: only ranks HOLDING MORE than it are split. The default of 1
     splits every rank of two or more, which is the whole family the note's main tables measure;
     RIG.start('TB', ['graph/floor'], 12) is how its "only ranks > 12" rows were produced. */
  function scaffoldFor(g, rd, order, half, minSize) {
    const c = crossKey(rd), out = [];
    for (const rank of ranksOf(g, rd)) {
      const ids = rank.slice();
      if (order === 'x') ids.sort((a, b) => g.node(a)[c] - g.node(b)[c]);
      else if (order === 'xrev') ids.sort((a, b) => g.node(b)[c] - g.node(a)[c]);
      const n = ids.length;
      if (n < 2 || n <= (minSize || 1)) continue;
      let A, B;
      if (half === 'alt') { A = ids.filter((_, i) => i % 2 === 0); B = ids.filter((_, i) => i % 2 === 1); }
      else {
        const k = half === 'floor' ? Math.floor(n / 2) : Math.ceil(n / 2);
        A = ids.slice(0, k); B = ids.slice(k);
      }
      for (let i = 0; i < Math.min(A.length, B.length); i++) out.push([A[i], B[i]]);
    }
    return out;
  }

  const CANDS = [];
  for (const order of ['graph', 'x', 'xrev']) for (const half of ['floor', 'ceil', 'alt']) CANDS.push({ order, half });

  /* A layout is seconds of blocking work, so hand the event loop back between them: without this
     the page is frozen for the whole sweep and nothing can read the rows as they land. */
  const breathe = () => new Promise(r => setTimeout(r, 0));

  async function run(rd, only, minSize) {
    rd = String(rd || 'TB').toUpperCase();
    const list = only ? CANDS.filter(c => only.includes(`${c.order}/${c.half}`)) : CANDS;
    const suffix = minSize > 1 ? ` >${minSize}` : '';
    sizeAll();
    api.stage = `${rd} baseline${suffix}`;
    await breathe();
    const base = layout(rd, null);
    /* Appended, not replaced: the note's tables come from two sweeps in one session (TB then LR),
       and a reset here would throw the first away before table() could print it. RIG.clear() is
       the way to start over. */
    api.rows.push(Object.assign({ name: `${rd} baseline`, scaffold: 0, ms: base.ms }, stats(base.g)));
    for (const c of list) {
      api.stage = `${rd} ${c.order}/${c.half}${suffix}`;
      await breathe();
      const sc = scaffoldFor(base.g, rd, c.order, c.half, minSize);
      const r = layout(rd, sc);
      api.rows.push(Object.assign({ name: api.stage, scaffold: sc.length, ms: r.ms }, stats(r.g)));
    }
    api.stage = 'done';
    return api.rows;
  }

  const api = {
    rows: [], stage: 'idle', done: true, error: null,
    /* Refused rather than queued while one is running: two sweeps would interleave their layouts,
       fight over `stage`, and land rows in an order neither of them chose. */
    start(rd, only, minSize) {
      if (!api.done) return `a sweep is already running (${api.stage}) — wait for RIG.done`;
      api.done = false; api.error = null;
      run(rd, only, minSize).then(() => { api.done = true; })
        .catch(e => { api.error = String((e && e.stack) || e); api.done = true; api.stage = 'failed'; });
      return `started ${String(rd || 'TB').toUpperCase()} — poll RIG.stage / RIG.rows, then RIG.table()`;
    },
    clear() { api.rows = []; api.stage = 'idle'; return 'rows cleared'; },
    table() {
      const cols = ['name', 'W', 'H', 'total', 'median', 'longest', 'ranks', 'scaffold', 'ms'];
      return [`| ${cols.join(' | ')} |`, `|${cols.map(() => '---').join('|')}|`]
        .concat(api.rows.map(r => `| ${cols.map(c => r[c]).join(' | ')} |`)).join('\n');
    },
    layout, stats, scaffoldFor, ranksOf, sizeAll, CANDS
  };
  return api;
})();
