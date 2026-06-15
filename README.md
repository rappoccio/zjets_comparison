# zjets_comparison — self-contained Z+jets prediction vs HepData (CMS_2026_PAS_SMP_25_010)

Everything needed to generate particle-level **Z+jets** predictions and overlay
them on the unfolded HepData (normalized jet mass `log10(rho^2)` in 3 leading-jet
pT slices, groomed & ungroomed), with `rivet-mkhtml`. Designed to run **natively
on lxplus via a CVMFS LCG view** + **HTCondor** — no Docker, no container.

Copy this whole directory to **EOS** (not AFS home), then:

```bash
vi config.sh          # set LCG_VIEW (Rivet >= 4.0); tune NEV/NSEEDS if you like
./prepare.sh          # ONCE: build the plugin + driver under the LCG view

./submit_pythia8.sh   # one batch per generator (each independent)
./submit_vincia.sh
./submit_herwig.sh
./submit_amcnlo.sh
condor_q              #   ...watch them finish...

./merge_plot.sh       # auto-discovers yodas/* and plots them all -> html/index.html
```

There is **one submit script per generator** — run any subset, in any order, even
concurrently (each uses its own AFS submit dir and its own `yodas/<tag>/`). You do
NOT edit `config.sh` to switch generators.

Quick end-to-end check before a big run: set `NSEEDS=4` (and `NSEEDS_MG=2`) in
`config.sh`, run one submit script, then `merge_plot.sh`.

## Contents

```
config.sh             SHARED settings only (LCG view, NEV/NSEEDS, paths) — edit this
prepare.sh            one-time build of the plugin + pythia8-rivet driver

submit_pythia8.sh     ┐ per-generator submit scripts (thin wrappers)
submit_vincia.sh      │   showers (pythia/vincia): _submit_shower.sh + gen_job.sh
submit_herwig.sh      │   herwig:  gen_herwig_job.sh   -> yodas/herwig/
submit_amcnlo.sh      ┘   aMC@NLO: gen_amcnlo_job.sh   -> yodas/amcnlo/
submit_lib.sh         shared condor_launch() used by all submit scripts
gen.sub               static HTCondor description (executable/args/queue appended)
gen_job.sh / gen_herwig_job.sh / gen_amcnlo_job.sh   per-generator payloads (one seed)

merge_plot.sh         sum every yodas/<gen>/ -> build_comparison.py -> rivet-mkhtml
build_comparison.py   slice each 2D prediction to per-slice unit-area 1D + /REF from npz

CMS_2026_PAS_SMP_25_010.cc      the Rivet analysis (2D, HepData binning)
hepdata_export_{groomed,ungroomed}.npz   the data
pythia/    main_rivet.cc, Makefile, cp5.cmnd, zjets.cmnd
herwig/    zjets.in           (Herwig steering — verify the process block)
madgraph/  zjets.mg5 (reference), zjets_batch.mg5 (@SEED@/@NEV@ template)
lhapdf-cache/   CP5 PDF (NNPDF31_nnlo_as_0118), used if CVMFS lacks it
```

## Pick an LCG view (Rivet >= 4.0 required)

The analysis uses the Rivet-4 API, so the view's Rivet must be ≥ 4.0. Rivet 4
entered the stacks at **LCG_106**; **LCG_107+** carry 4.1.x. List versions:

```bash
ls -d /cvmfs/sft.cern.ch/lcg/releases/LCG_*/MCGenerators/rivet/*/ 2>/dev/null | sort -V
```

Set the matching view in `config.sh` (`prepare.sh` prints the Rivet version so you
can confirm). Match the platform tag to the node (`x86_64-el9-gcc13-opt` on lxplus9).

## Output

`html/index.html`: 6 panels — `zjets_{groomed,ungroomed}` × pT `{200–290, 290–400,
>400}` — CMS data (points, asymmetric total errors from the npz) with each
generator overlaid and an MC/Data ratio pad. Each curve is unit-area-normalized
within its pT slice.

## Generators

| script               | generator                      | jobs        | output dir      |
|----------------------|--------------------------------|-------------|-----------------|
| `submit_pythia8.sh`  | PYTHIA8 simple shower          | `NSEEDS`    | `yodas/pythia8` |
| `submit_vincia.sh`   | PYTHIA8 + VINCIA shower         | `NSEEDS`    | `yodas/vincia`  |
| `submit_herwig.sh`   | HERWIG7 angular-ordered shower | `NSEEDS`    | `yodas/herwig`  |
| `submit_amcnlo.sh`   | aMC@NLO `p p > z j [QCD]` + PY8 | `NSEEDS_MG` | `yodas/amcnlo`  |

Each is independent. `merge_plot.sh` overlays whichever ones have produced YODAs —
no need to run them all. aMC@NLO and Herwig need an LCG view that also ships
MadGraph / Herwig7 (the recent ones do).

> **Herwig caveat:** `herwig/zjets.in` is the one steering file not validated here.
> Herwig's internal Z+jet ME and its decay/cut switches vary by release — if
> `Herwig read` errors, adjust the marked process block (compare with the
> `LHC-*.in` examples shipped in the Herwig share dir). Do the `NSEEDS=2` test
> first.

## Notes

- Keep the package on **EOS** so HTCondor workers can read inputs. `prepare.sh`
  builds against CVMFS, which the workers also mount.
- **lxplus batch + EOS:** the standard schedds forbid `/eos` paths *in the submit
  file*, so each submit script stages Condor's control files (executable + logs) to
  **`$SUBMIT_ROOT/<gen>`** on AFS (default `~/zjets_submit/<gen>`), and each job
  copies its YODA back to EOS with `xrdcp` (normalizing `/eos/home-*` →
  `/eos/user/*`). Just keep a little AFS quota free. (Alternative: the EosSubmit
  schedds keep everything on EOS — https://batchdocs.web.cern.ch/local/eossubmit.html.)
- Seeds are **summed** (raw counts) by `build_comparison.py`, so N jobs = N× stats.
  The `pT>400` slice needs the most events.
- The CP5 PDF is bundled; generation is otherwise offline. `gen.sub` renews the
  EOS/Kerberos token (`MY.SendCredential`) for long jobs.
- Analysis binning (must match the data): pT edges `200,290,400,∞`; mass edges
  `-10,-4.5,-4,…,-0.5,0`. Change both the `.cc` and the data if you rebin.
