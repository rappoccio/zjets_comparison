#!/usr/bin/env python3
"""Build YODA objects for a Rivet-style data/MC comparison of the Z+jets
normalized jet-mass distributions in CMS_2026_PAS_SMP_25_010.

  * REF  : the unfolded HepData (hepdata_export_{groomed,ungroomed}.npz),
           three pT slices per grooming, written under /REF/<ANA>/...
  * MC   : each generator's 2D prediction (<ANA>/zjets_<groom>), sliced into the
           same 3 pT bins and normalized to unit area per slice, written under
           /<ANA>/zjets_<groom>_pt{0,1,2} so rivet-mkhtml overlays + ratios them.

Usage (run inside hepstore/rivet-pythia):
  build_comparison.py REPO_ROOT OUTDIR  NAME=pred.yoda [NAME2=pred2.yoda ...] \
      [--also-truepythia]
"""
import os, sys
import numpy as np
import yoda

ANA   = "CMS_2026_PAS_SMP_25_010"
CHAN  = "zjets"
GROOMS = ["ungroomed", "groomed"]
NSLICE = 3
# Must match the analysis booking and the HepData export.
PT_EDGES   = [200., 290., 400., 13000.]
MASS_EDGES = [-10., -4.5, -4., -3.5, -3., -2.5, -2., -1.5, -1., -0.5, 0.]
SLICE_TITLE = {0: "200 < pT < 290 GeV", 1: "290 < pT < 400 GeV", 2: "pT > 400 GeV"}


def _scatter(path, value, eup, edn, title=None):
    """A Scatter2D over the MASS_EDGES bins: x=bin centre, y=value (density)."""
    s = yoda.Scatter2D(path=path)
    if title:
        s.setTitle(title)
    for j in range(len(value)):
        xlo, xhi = MASS_EDGES[j], MASS_EDGES[j + 1]
        xm = 0.5 * (xlo + xhi)
        p = yoda.Point2D(xm, float(value[j]), 0.0, 0.0)
        p.setXErrs(xm - xlo, xhi - xm)
        p.setYErrs(float(edn[j]), float(eup[j]))
        s.addPoint(p)
    return s


def build_ref(repo):
    """HepData -> /REF/<ANA>/zjets_<groom>_pt{s} (value + asymmetric total error)."""
    aos = []
    for groom in GROOMS:
        f = np.load(os.path.join(repo, f"hepdata_export_{groom}.npz"), allow_pickle=True)
        for s in range(NSLICE):
            p = f"pt{s}"
            aos.append(_scatter(
                f"/REF/{ANA}/{CHAN}_{groom}_pt{s}",
                f[f"{p}__value"], f[f"{p}__total_up"], f[f"{p}__total_down"],
                title=f"CMS data, {SLICE_TITLE[s]}"))
    return aos


def build_truepythia(repo):
    """The Pythia truth curve stored in the npz, as a cross-check MC line."""
    aos = []
    for groom in GROOMS:
        f = np.load(os.path.join(repo, f"hepdata_export_{groom}.npz"), allow_pickle=True)
        for s in range(NSLICE):
            v = f[f"pt{s}__true_pythia"]
            z = np.zeros_like(v)
            aos.append(_scatter(f"/{ANA}/{CHAN}_{groom}_pt{s}", v, z, z,
                                title="PYTHIA (npz truth)"))
    return aos


def _val_err(b):
    """(value, abs-error) for one bin of a YODA-2 BinnedEstimate2D. Rivet 4
    finalizes the 2D booking into an estimate, so bins expose val()/err(...)
    rather than sumW()/sumW2(). err/errAvg may be scalar or (down, up)."""
    v = float(b.val())
    try:
        e = b.errAvg()
    except Exception:
        try:
            e = b.err()
        except Exception:
            e = 0.0
    if isinstance(e, (tuple, list)):
        e = 0.5 * (abs(e[0]) + abs(e[1]))
    return v, float(e)


def _cells(paths, groom):
    """Sum (value, error^2) of the 2D <ANA>/zjets_<groom> over one or more YODA
    files, keyed by (xbin_lo, ybin_lo). Summing across files combines the
    independent (different-seed) runs; per-slice unit-area renormalization later
    makes any per-file scaling irrelevant, so only the relative shape matters."""
    cells = {}
    for path in paths:
        objs = yoda.read(path)
        h2 = objs.get(f"/{ANA}/{CHAN}_{groom}")
        if h2 is None:
            sys.stderr.write(f"WARN: /{ANA}/{CHAN}_{groom} not in {path}\n"); continue
        for b in h2.bins():
            k = (round(b.xMin(), 3), round(b.yMin(), 3))
            sw, sw2 = cells.get(k, (0., 0.))
            v, e = _val_err(b)
            cells[k] = (sw + v, sw2 + e * e)
    return cells


def _slice_cells(cells):
    """Return {slice: (dens[10], err[10])} from summed cells, per-slice unit area."""
    out = {}
    for s in range(NSLICE):
        xlo = round(PT_EDGES[s], 3)
        w  = np.array([cells.get((xlo, round(MASS_EDGES[j], 3)), (0., 0.))[0] for j in range(len(MASS_EDGES) - 1)])
        w2 = np.array([cells.get((xlo, round(MASS_EDGES[j], 3)), (0., 0.))[1] for j in range(len(MASS_EDGES) - 1)])
        dy = np.diff(MASS_EDGES)
        T = w.sum()
        if T <= 0:
            out[s] = (np.zeros_like(w), np.zeros_like(w))
            continue
        dens = w / (T * dy)              # unit area: sum(dens*dy) = 1
        err  = np.sqrt(w2) / (T * dy)    # stat only (ignores T uncertainty)
        out[s] = (dens, err)
    return out


def build_mc(paths, title):
    aos = []
    for groom in GROOMS:
        sl = _slice_cells(_cells(paths, groom))
        for s in range(NSLICE):
            dens, err = sl[s]
            aos.append(_scatter(f"/{ANA}/{CHAN}_{groom}_pt{s}", dens, err, err, title=title))
    return aos


def write_plot_files(outdir):
    """Write Rivet plot-config file with per-YODA-source styling via HISTOGRAM blocks.
    The HISTOGRAM block ID syntax is: <yoda_filename>/<histogram_path>"""
    # MC process styles: colors and line styles
    mc_styles = {
        "pythia8":    {"color": "blue", "linestyle": "solid", "marker": "*"},
        "vincia":     {"color": "orange", "linestyle": "dashed", "marker": "o"},
        "amcnlo":     {"color": "green", "linestyle": "dotted", "marker": "triangle"},
        "herwig":     {"color": "red", "linestyle": "dotdashed", "marker": "diamond"},
        "mglo_pythia": {"color": "purple", "linestyle": "solid", "marker": "+"},
        "mglo_vincia": {"color": "brown", "linestyle": "dashed", "marker": "x"},
        "mglo_herwig": {"color": "pink", "linestyle": "dotted", "marker": "pentagon"},
    }

    blocks = []

    # PLOT sections: global axis configuration
    for groom in GROOMS:
        for s in range(NSLICE):
            blocks.append(f"""# BEGIN PLOT /{ANA}/{CHAN}_{groom}_pt{s}
XMin=-4.5
XMax=0.0
# END PLOT
""")

    # HISTOGRAM sections: per-YODA-source styling
    for groom in GROOMS:
        for s in range(NSLICE):
            hist_path = f"/{ANA}/{CHAN}_{groom}_pt{s}"
            # Reference data
            blocks.append(f"""# BEGIN HISTOGRAM ref.yoda{hist_path}
LineColor=black
LineWidth=2
PolyMarker=square
ErrorBars=1
# END HISTOGRAM
""")
            # Each MC source
            for mc_name, style in mc_styles.items():
                blocks.append(f"""# BEGIN HISTOGRAM mc_{mc_name}.yoda{hist_path}
LineColor={style['color']}
LineStyle={style['linestyle']}
PolyMarker={style['marker']}
# END HISTOGRAM
""")

    plot_file = os.path.join(outdir, "axis.plot")
    with open(plot_file, "w") as f:
        f.write("\n".join(blocks))
    print(f"wrote {plot_file} (with per-YODA-source styling)")


def main():
    repo, outdir = sys.argv[1], sys.argv[2]
    preds, also_tp = [], False
    for a in sys.argv[3:]:
        if a == "--also-truepythia":
            also_tp = True
        else:
            preds.append(a)
    os.makedirs(outdir, exist_ok=True)

    yoda.write(build_ref(repo), os.path.join(outdir, "ref.yoda"))
    print("wrote ref.yoda (HepData)")
    if also_tp:
        yoda.write(build_truepythia(repo), os.path.join(outdir, "mc_truepythia.yoda"))
        print("wrote mc_truepythia.yoda (npz truth cross-check)")
    for spec in preds:
        name, paths = spec.split("=", 1)
        paths = paths.split(",")            # one or more (different-seed) files, summed
        aos = build_mc(paths, name)
        out = os.path.join(outdir, f"mc_{name}.yoda")
        yoda.write(aos, out)
        print(f"wrote {out} ({len(aos)} objects) from {len(paths)} file(s)")

    # Write .plot files to control x-axis range (Rivet standard method)
    write_plot_files(outdir)


if __name__ == "__main__":
    main()
