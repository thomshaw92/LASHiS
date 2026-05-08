"""Single-page NiiVue-based QC viewer.

Renders one ``qc/index.html`` powered by NiiVue (https://github.com/niivue/niivue)
— a WebGL2 NIfTI viewer used by FSL, AFNI integrations, and many recent
neuroimaging projects. Replaces the old per-(timepoint, side, method)
nilearn HTMLs which were ~10 MB each, slow to render, and had a clumsy
overlay UI.

The page lives at ``<output>/qc/index.html`` and references the warped
labels + per-tp TSEs via relative paths. Browsers block local file://
fetches, so to view it::

    cd <output>/qc && python3 -m http.server
    open http://localhost:8000

Loaded NiiVue from a CDN; no internet needed once the JS is browser-cached.
"""
from __future__ import annotations

import json
from pathlib import Path

from nipype.interfaces.utility import Function
from nipype.pipeline import engine as pe

from ..config import LashisConfig
from ..utils.paths import qc_dir


def _make_qc_index_html(
    subject: str,
    tse_per_tp: list[str],
    labels_jlf_left: list[str],
    labels_jlf_right: list[str],
    labels_majority_left: list[str],
    labels_majority_right: list[str],
    labels_jacpen_jlf_left: list[str],
    labels_jacpen_jlf_right: list[str],
    labels_jacpen_majority_left: list[str],
    labels_jacpen_majority_right: list[str],
    output_path: str,
) -> str:
    """Build a single NiiVue-powered viewer covering every (tp, side, method).

    All paths in the manifest are made relative to ``output_path.parent``
    (i.e. the qc/ dir). NIfTI files are loaded by the browser at view time.

    Self-contained: Nipype ships Function-node source to workers as text and
    runs it in a fresh namespace, so the HTML template lives INSIDE this
    function (not as a module-level constant).
    """
    import json as _json
    from pathlib import Path as _P

    html_template = r"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>LASHiS QC — __SUBJECT__</title>
  <style>
    body { font-family: -apple-system, system-ui, sans-serif; margin: 0;
           display: flex; flex-direction: column; height: 100vh; color: #222; }
    header { padding: 10px 16px; background: #1a3c5e; color: #fff;
             display: flex; align-items: center; justify-content: space-between; }
    header h1 { margin: 0; font-size: 16px; font-weight: 600; }
    header .meta { font-size: 12px; opacity: 0.9; }
    .banner { background: #fff7d0; padding: 8px 16px; font-size: 12px;
              border-bottom: 1px solid #ddd; color: #5a4400; }
    .banner code { background: #fff; padding: 1px 5px; border: 1px solid #d4c890;
                   border-radius: 3px; font-size: 11px; }
    #app { display: flex; flex: 1; min-height: 0; }
    aside { width: 250px; padding: 14px; overflow-y: auto;
            background: #f4f4f7; border-right: 1px solid #ccc; }
    .group { margin-bottom: 18px; }
    .group h3 { margin: 0 0 6px; font-size: 10px; text-transform: uppercase;
                letter-spacing: 0.6px; color: #666; }
    .group label { display: block; padding: 2px 0; font-size: 13px; cursor: pointer; }
    .group input[type=radio] { margin-right: 6px; }
    select, input[type=range] { width: 100%; box-sizing: border-box; }
    main { flex: 1; display: flex; flex-direction: column; min-width: 0; }
    #gl1 { flex: 1; min-height: 320px; background: #000; }
    #intensity { padding: 6px 14px; background: #fff; border-top: 1px solid #ccc;
                 font-family: ui-monospace, monospace; font-size: 12px; min-height: 1em; }
    #paths { font-family: ui-monospace, monospace; font-size: 10px;
             word-break: break-all; color: #555; }
    .danger { color: #b00; }
  </style>
</head>
<body>
  <noscript><strong>This QC viewer requires JavaScript and a modern WebGL2 browser.</strong></noscript>
  <header>
    <h1>LASHiS QC — __SUBJECT__</h1>
    <span class="meta" id="meta-info"></span>
  </header>
  <div class="banner" id="banner">
    If volumes don't load, run <code>python3 -m http.server</code> from
    <code>__OUTPUT_PREFIX__</code> and open
    <code>http://localhost:8000/qc/index.html</code> instead of opening the file directly.
    <span id="banner-status"></span>
  </div>
  <div id="app">
    <aside>
      <div class="group" id="tp-group"><h3>Timepoint</h3></div>
      <div class="group" id="side-group"><h3>Side</h3></div>
      <div class="group" id="method-group"><h3>Fusion method</h3></div>
      <div class="group">
        <h3>Overlay opacity</h3>
        <input type="range" id="opacity" min="0" max="1" step="0.05" value="0.7">
        <span id="opacity-value">0.70</span>
      </div>
      <div class="group">
        <h3>View</h3>
        <select id="sliceType">
          <option value="3" selected>A+C+S+R</option>
          <option value="0">Axial</option>
          <option value="1">Coronal</option>
          <option value="2">Sagittal</option>
          <option value="4">3D render</option>
        </select>
      </div>
      <div class="group">
        <h3>Loaded files</h3>
        <div id="paths"></div>
      </div>
    </aside>
    <main>
      <canvas id="gl1"></canvas>
    </main>
  </div>
  <footer id="intensity">&nbsp;</footer>

  <script src="https://cdn.jsdelivr.net/npm/@niivue/niivue@latest/dist/niivue.umd.js"></script>
  <script>
    const MANIFEST = __MANIFEST_JSON__;

    function buildRadios(groupId, options, name, defaultIdx = 0) {
      const root = document.getElementById(groupId);
      options.forEach((opt, i) => {
        const lab = document.createElement('label');
        const inp = document.createElement('input');
        inp.type = 'radio';
        inp.name = name;
        inp.value = opt.value;
        inp.checked = i === defaultIdx;
        inp.addEventListener('change', refresh);
        lab.appendChild(inp);
        lab.appendChild(document.createTextNode(' ' + opt.label));
        root.appendChild(lab);
      });
    }
    buildRadios('tp-group', MANIFEST.timepoints, 'tp');
    buildRadios('side-group', MANIFEST.sides, 'side');
    buildRadios('method-group', MANIFEST.methods, 'method');

    document.getElementById('meta-info').textContent =
      MANIFEST.timepoints.length + ' tp × ' +
      MANIFEST.sides.length + ' sides × ' +
      MANIFEST.methods.length + ' methods';

    function selected(name) {
      const el = document.querySelector('input[name=' + name + ']:checked');
      return el ? el.value : null;
    }

    const nv = new window.niivue.Niivue({
      dragAndDropEnabled: true,
      onLocationChange: data => {
        document.getElementById('intensity').innerHTML =
          '&nbsp;&nbsp;' + (data.string || '');
      },
    });
    nv.attachTo('gl1').then(() => {
      nv.setSliceType(parseInt(document.getElementById('sliceType').value));
      nv.setIsOrientationTextVisible(true);
      refresh();
    });

    document.getElementById('sliceType').addEventListener('change', () => {
      nv.setSliceType(parseInt(document.getElementById('sliceType').value));
    });
    document.getElementById('opacity').addEventListener('input', e => {
      const v = parseFloat(e.target.value);
      document.getElementById('opacity-value').textContent = v.toFixed(2);
      if (nv.volumes.length > 1) {
        nv.setOpacity(1, v);
      }
    });

    let currentLoad = 0;
    async function refresh() {
      const tp = selected('tp');
      const side = selected('side');
      const method = selected('method');
      if (tp === null || side === null || method === null) return;
      const key = tp + '|' + side + '|' + method;
      const view = MANIFEST.viewers[key];
      const pathsEl = document.getElementById('paths');
      if (!view) {
        pathsEl.innerHTML = '<span class="danger">No viewer for ' + key + '</span>';
        return;
      }
      const op = parseFloat(document.getElementById('opacity').value);
      pathsEl.innerHTML =
        '<div>tse: ' + view.tse + '</div><div>labels: ' + view.labels + '</div>';
      const myLoad = ++currentLoad;
      try {
        // Underlay: TSE in greyscale, default windowing.
        // Overlay: discrete subfield labels — 'random' colormap gives a
        // distinct colour per integer; cal_min=0.5 hides label 0 (background).
        // cal_max=64 covers any reasonable atlas (UMC Utrecht uses ~10 labels;
        // PMC uses up to ~30; bumping to 64 makes the colormap stable across
        // atlases without recomputing per file).
        await nv.loadVolumes([
          { url: view.tse,    colormap: 'gray',   opacity: 1.0 },
          { url: view.labels, colormap: 'random', opacity: op,
            cal_min: 0.5, cal_max: 64 },
        ]);
        if (myLoad !== currentLoad) return;

        // Robust windowing for the TSE underlay. NiiVue precomputes
        // robust_min/robust_max (1st/99th percentile) on load; default
        // display range is the data min/max which gets thrown off by bright
        // outliers in 7T TSE. Snap to the robust range for sane contrast.
        const tseVol = nv.volumes[0];
        if (tseVol && typeof tseVol.robust_min === 'number') {
          tseVol.cal_min = tseVol.robust_min;
          tseVol.cal_max = tseVol.robust_max;
          nv.updateGLVolume();
        }

        document.getElementById('banner-status').innerHTML =
          ' <span style="color:green">✓ loaded · middle-click-drag to window</span>';
      } catch (err) {
        document.getElementById('banner-status').innerHTML =
          ' <span class="danger">✗ ' + err.message + '</span>';
        console.error(err);
      }
    }
  </script>
</body>
</html>
"""

    out = _P(output_path)
    qc_dir = out.parent
    qc_dir.mkdir(parents=True, exist_ok=True)

    def _relto(p: str) -> str:
        """Relative path from qc/ to the NIfTI. Resolve both ends so symlinks
        like macOS /tmp → /private/var/folders/... don't confuse relpath."""
        import os
        return os.path.relpath(
            str(_P(p).resolve()), str(qc_dir.resolve())
        )

    method_specs: list[tuple[str, str, list[str], list[str]]] = []
    if labels_jlf_left:
        method_specs.append(("jlf", "JLF (joint fusion)", labels_jlf_left, labels_jlf_right))
    if labels_majority_left:
        method_specs.append(("majority", "Majority voting", labels_majority_left, labels_majority_right))
    if labels_jacpen_jlf_left:
        method_specs.append(
            ("jlf_jacpen", "JLF · Jacobian-penalised", labels_jacpen_jlf_left, labels_jacpen_jlf_right))
    if labels_jacpen_majority_left:
        method_specs.append(
            ("majority_jacpen", "Majority · Jacobian-penalised",
             labels_jacpen_majority_left, labels_jacpen_majority_right))

    n_tp = len(tse_per_tp)
    timepoints = [{"value": str(i), "label": f"Session {i + 1} (tp{i:02d})"} for i in range(n_tp)]
    sides = [{"value": "left", "label": "Left"}, {"value": "right", "label": "Right"}]
    methods = [{"value": k, "label": lbl} for k, lbl, *_ in method_specs]

    viewers: dict[str, dict] = {}
    for method_key, _label, left_paths, right_paths in method_specs:
        for tp in range(n_tp):
            for side, paths in (("left", left_paths), ("right", right_paths)):
                if tp >= len(paths):
                    continue
                viewers[f"{tp}|{side}|{method_key}"] = {
                    "tse": _relto(tse_per_tp[tp]),
                    "labels": _relto(paths[tp]),
                }

    manifest = {"timepoints": timepoints, "sides": sides, "methods": methods, "viewers": viewers}

    html = (
        html_template
        .replace("__SUBJECT__", subject)
        .replace("__OUTPUT_PREFIX__", str(qc_dir.parent))
        .replace("__MANIFEST_JSON__", _json.dumps(manifest, indent=2))
    )
    out.write_text(html)

    # Drop a tiny helper next to the HTML so users don't have to remember
    # `python3 -m http.server` invocation to bypass browser file:// fetch
    # restrictions. Browsers block JS fetches from file:// for security.
    serve_sh = qc_dir / "serve.sh"
    serve_sh.write_text(
        '#!/bin/bash\n'
        '# Serve this LASHiS output dir over HTTP so the QC viewer can fetch '
        'its NIfTIs.\n'
        '# Browsers block JS fetches from file:// for security; this works around it.\n'
        '#   ./qc/serve.sh           # default port 8765\n'
        '#   PORT=9000 ./qc/serve.sh # custom port\n'
        'set -e\n'
        'PORT="${PORT:-8765}"\n'
        'HERE="$(cd "$(dirname "$0")/.." && pwd)"\n'
        'echo "Serving $HERE \xe2\x86\x92 http://localhost:${PORT}/qc/index.html"\n'
        'echo "Ctrl-C to stop."\n'
        'cd "$HERE" && exec python3 -m http.server "$PORT"\n'
    )
    import os, stat
    os.chmod(serve_sh, os.stat(serve_sh).st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)

    return str(out)


def build_qc(config: LashisConfig, methods: list[str]) -> pe.Node:
    """Single Function node that writes one ``qc/index.html`` covering everything.

    Caller wires from xs_ashs.tse + per-(side, method) reverse_warp.warped_labels
    + (optional) per-(side, method) jacpen.jacpen_labels into the input slots.
    Unwired slots default to empty lists so methods/jacpen that weren't run
    just don't appear in the sidebar.
    """
    out_path = qc_dir(config.output_prefix) / "index.html"
    qc_dir(config.output_prefix).mkdir(parents=True, exist_ok=True)

    node = pe.Node(
        Function(
            input_names=[
                "subject", "tse_per_tp",
                "labels_jlf_left", "labels_jlf_right",
                "labels_majority_left", "labels_majority_right",
                "labels_jacpen_jlf_left", "labels_jacpen_jlf_right",
                "labels_jacpen_majority_left", "labels_jacpen_majority_right",
                "output_path",
            ],
            output_names=["index_path"],
            function=_make_qc_index_html,
        ),
        name="qc_viewer",
    )
    # subject string, taken from first timepoint's basename root.
    sample = config.timepoints[0].t1w.name
    subject = sample.split("_")[0] if "_" in sample else "subject"
    node.inputs.subject = subject
    node.inputs.output_path = str(out_path)
    # Default empty lists so methods that weren't run don't fail the trait check.
    for slot in (
        "labels_jlf_left", "labels_jlf_right",
        "labels_majority_left", "labels_majority_right",
        "labels_jacpen_jlf_left", "labels_jacpen_jlf_right",
        "labels_jacpen_majority_left", "labels_jacpen_majority_right",
    ):
        setattr(node.inputs, slot, [])
    return node
