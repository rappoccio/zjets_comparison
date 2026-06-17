# zjets_comparison — self-contained Z+jets prediction vs HepData (CMS_2026_PAS_SMP_25_010)

Everything needed to generate particle-level **Z+jets** predictions and overlay
them on the unfolded HepData (normalized jet mass `log10(rho^2)` in 3 leading-jet
pT slices, groomed & ungroomed), with `rivet-mkhtml`. Designed to run **natively
on lxplus via a CVMFS LCG view** + **HTCondor** — no Docker, no container.

Copy this whole directory to **EOS** (not AFS home), then:

```bash
vi config.sh          # set LCG_VIEW (Rivet >= 4.0); tune NEV/NSEEDS if you like
./prepare.sh          # ONCE: build the plugin + driver under the LCG view

./submit_pythia8.sh   # one batch per generator (each independent) — see the
./submit_vincia.sh    #   Generators table below for the full set of 10 chains
./submit_herwig.sh    #   (amcnlo_herwig, mglo_pythia/vincia/herwig, powheg, sherpa)
./submit_amcnlo.sh
condor_q              #   ...watch them finish...

./merge_plot.sh       # auto-discovers yodas/* and merges them -> out/*.yoda
rivet-mkhtml -o html -c out/axis.plot out/*.yoda  # generate HTML plots
```

There is **one submit script per generator** — run any subset, in any order, even
concurrently (each uses its own AFS submit dir and its own `yodas/<tag>/`). You do
NOT edit `config.sh` to switch generators.

Quick end-to-end check before a big run: set `NSEEDS=4` (and `NSEEDS_MG=2`) in
`config.sh`, run one submit script, then `merge_plot.sh`.

## Contents

```
config.sh             SHARED settings only (LCG view, NEV/NSEEDS, paths) — edit this
prepare.sh            one-time build: plugin + pythia8-rivet + powheg8-rivet drivers,
                      bundle bc, fetch POWHEG pwhg_main, build Sherpa process libs

submit_*.sh           one per generator (10 total; see the Generators table). Wrappers
                      over submit_lib.sh's condor_launch() + a gen_*_job.sh payload.
submit_lib.sh         shared condor_launch() used by all submit scripts
gen.sub               static HTCondor description (executable/args/queue appended)
gen_*_job.sh          per-generator HTCondor payloads (one seed each):
                        gen_job.sh (pythia8/vincia), gen_herwig_job.sh, gen_amcnlo_job.sh,
                        gen_amcnlo_herwig_job.sh, gen_mglo_job.sh (pythia/vincia),
                        gen_mglo_herwig_job.sh, gen_powheg_job.sh, gen_sherpa_job.sh

merge_plot.sh         sum every yodas/<gen>/ -> build_comparison.py
build_comparison.py   slice each 2D prediction to per-slice unit-area 1D + /REF from npz
axis.plot             rivet-mkhtml configuration (axis ranges, log scale, legend position)

CMS_2026_PAS_SMP_25_010.cc      the Rivet analysis (2D, HepData binning)
hepdata_export_{groomed,ungroomed}.npz   the data
pythia/    main_rivet.cc, main_rivet_powheg.cc (PowhegHooks), Makefile, cp5.cmnd,
           vincia.cmnd, powheg.cmnd, zjets.cmnd, run_local.sh
herwig/    zjets.in (internal ME), lhe_shower.in (LHE reader), run_local.sh
madgraph/  zjets_batch.mg5 (NLO+PY8), zjets_herwig.mg5 (NLO+HERWIGPP),
           zjets_lo_batch.mg5 (LO), zjets.mg5 (reference), run_local*.sh
powheg/    Zj.input (@SEED@/@NEV@ template), run_local.sh  [+ pwhg_main built/fetched]
sherpa/    Sherpa.yaml (3.x MEPS@LO), run_local.sh        [+ Process/ built once]
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

Ten interchangeable chains. Each has **one submit script** (→ its own `yodas/<tag>/`)
and **one local tester** (no Condor/xrdcp, verbose, keeps its run dir). `merge_plot.sh`
auto-discovers whichever `yodas/<tag>/` exist — run any subset, in any order.

| submit script | hard process (ME) | order | shower / hadronization | jobs | `yodas/<tag>` | local tester |
|---|---|---|---|---|---|---|
| `submit_pythia8.sh`       | PYTHIA8 internal `q g→Zq`, `qq̄→Zg` | LO+PS | PYTHIA8 simple shower, CP5     | `NSEEDS`    | `pythia8`       | `pythia/run_local.sh 1` |
| `submit_vincia.sh`        | PYTHIA8 internal `q g→Zq`, `qq̄→Zg` | LO+PS | PYTHIA8 **VINCIA** shower       | `NSEEDS`    | `vincia`        | `pythia/run_local.sh 2` |
| `submit_herwig.sh`        | HERWIG7 internal `MEZJet`          | LO+PS | HERWIG7 angular-ordered         | `NSEEDS`    | `herwig`        | `herwig/run_local.sh` |
| `submit_amcnlo.sh`        | aMC@NLO `p p > z j [QCD]`          | NLO   | PYTHIA8 (PY8 counterterms)      | `NSEEDS_MG` | `amcnlo`        | `madgraph/run_local.sh` |
| `submit_amcnlo_herwig.sh` | aMC@NLO `p p > z j [QCD]`          | NLO   | HERWIG7 (HERWIGPP counterterms) | `NSEEDS_MG` | `amcnlo_herwig` | `madgraph/run_local_herwig.sh` |
| `submit_mglo_pythia.sh`   | LO MadGraph `p p > z j`           | LO+PS | PYTHIA8 simple shower, CP5      | `NSEEDS_MG` | `mglo_pythia`   | `madgraph/run_local_lo.sh 1` |
| `submit_mglo_vincia.sh`   | LO MadGraph `p p > z j`           | LO+PS | PYTHIA8 **VINCIA** shower       | `NSEEDS_MG` | `mglo_vincia`   | `madgraph/run_local_lo.sh 2` |
| `submit_mglo_herwig.sh`   | LO MadGraph `p p > z j`           | LO+PS | HERWIG7 angular-ordered         | `NSEEDS_MG` | `mglo_herwig`   | `madgraph/run_local_lo_herwig.sh` |
| `submit_powheg.sh`        | POWHEG-BOX `Zj`                   | NLO   | PYTHIA8 + PowhegHooks veto      | `NSEEDS_MG` | `powheg`        | `powheg/run_local.sh` |
| `submit_sherpa.sh`        | Sherpa MEPS@LO (0,1,2 jets, CKKW) | ME+PS | Sherpa (native, self-contained) | `NSEEDS`    | `sherpa`        | `sherpa/run_local.sh` |

Each is independent — `merge_plot.sh` overlays whichever ones produced YODAs.
`amcnlo*`/`mglo*` need an LCG view with MadGraph; `herwig`/`amcnlo_herwig`/`mglo_herwig`
need Herwig7; `sherpa` needs Sherpa; `powheg` needs a `Zj` `pwhg_main` (CVMFS or built).
The recent LCG views ship MadGraph/Herwig7/Sherpa.

**Why both NLO and LO MadGraph?** aMC@NLO's MC@NLO counterterms are shower-specific, so
the shower MUST match what the LHE was generated for (PYTHIA8 → `amcnlo`, HERWIGPP →
`amcnlo_herwig`); **VINCIA is not a valid aMC@NLO shower**. The `mglo_*` chains are plain
LO `p p > z j` (no counterterms), so the same LHE is valid input to *any* shower — that
is the only valid way to pair MadGraph with VINCIA, and gives a clean LO+PS comparison.

> **Status:** the four `amcnlo`/`pythia8`/`vincia`/`herwig` chains have run on lxplus;
> `amcnlo_herwig`, `mglo_*`, `powheg`, `sherpa` are scaffolded but **not yet validated
> there** — smoke-test each with its local tester first. See `HANDOFF.md` §7 for the
> per-generator CHECK items (Sherpa 3.x-YAML vs 2.2-Run.dat, POWHEG-BOX availability,
> the Herwig LHE-reader PDF lines).

> **Herwig caveat:** `herwig/zjets.in` is the one internal-ME steering file not validated
> here. Herwig's internal Z+jet ME and its decay/cut switches vary by release — if
> `Herwig read` errors, adjust the marked process block (compare with the `LHC-*.in`
> examples shipped in the Herwig share dir). Do the `NSEEDS=2` test first.

## Local testing (do this before every batch)

Each generator ships a **local tester** that runs the exact same chain as its
HTCondor payload, but interactively: no Condor, no `xrdcp`, verbose, and it keeps
its run directory so you can inspect the output. Always smoke-test a generator
locally on an lxplus login (or any node with the LCG view) **before** submitting a
batch — it's the fastest way to catch a steering/version problem.

Run from the package root. All take small defaults so a test is quick:

| generator(s)         | command                                       | args (defaults)                | first-run cost |
|----------------------|-----------------------------------------------|--------------------------------|----------------|
| pythia8 / vincia     | `./pythia/run_local.sh [MODEL] [NEV] [SEED]`  | MODEL 1=PY8/CP5, **2**=VINCIA; NEV 2000; SEED 1 | builds plugin |
| herwig               | `./herwig/run_local.sh [NEV] [SEED]`          | NEV 1000; SEED 1               | — |
| amcnlo               | `./madgraph/run_local.sh [NEV] [SEED]`        | NEV 2000; SEED 1               | aMC@NLO compiles the process |
| amcnlo_herwig        | `./madgraph/run_local_herwig.sh [NEV] [SEED]` | NEV 1000; SEED 1               | aMC@NLO compiles the process |
| mglo_pythia / mglo_vincia | `./madgraph/run_local_lo.sh [MODEL] [NEV] [SEED]` | MODEL **1**=PY8/CP5, 2=VINCIA; NEV 2000; SEED 1 | MadGraph compiles the LO process |
| mglo_herwig          | `./madgraph/run_local_lo_herwig.sh [NEV] [SEED]` | NEV 1000; SEED 1            | MadGraph compiles the LO process |
| powheg               | `./powheg/run_local.sh [NEV] [SEED]`          | NEV 2000; SEED 1               | needs a `Zj` `pwhg_main` |
| sherpa               | `./sherpa/run_local.sh [NEV] [SEED]`          | NEV 500; SEED 1                | builds Comix/**Amegic** process libs |

What a successful run produces: a `*.yoda` (path printed at the end; the run dir is
kept under `<gen>/local_run/` or similar). Sanity-check it before scaling up:

```bash
yoda ls <gen>/local_run/<file>.yoda | grep CMS_2026_PAS_SMP_25_010   # histos filled?
```

Recommended progression for any generator: **local tester** → tiny Condor test
(`NSEEDS=2 NEV=2000 ./submit_<gen>.sh`) → `merge_plot.sh` (eyeball the curve and
confirm jobs finish inside `JOBFLAVOUR`) → full `./submit_<gen>.sh`.

### Per-generator gotchas seen in local testing

- **Sherpa** — two real issues, both now fixed in the scripts:
  1. *Missing library at startup* (`libSherpaHepMC3Output.so.0.0.0: cannot open
     shared object file`). The LCG_107 view doesn't put Sherpa's `lib64/SHERPA-MC`
     on `LD_LIBRARY_PATH`. `run_local.sh`, `gen_sherpa_job.sh`, and `prepare.sh`
     locate that plugin under the Sherpa release tree and prepend its dir.
  2. *`Failed to parse NJET`* — in Sherpa 3.x YAML a `TAGS:` entry is only
     substituted when referenced as `$(NAME)`. The process multiplicity must be
     `93{$(NJET)}` (not `93{NJET}`); `CKKW: $(QCUT)` was already correct.

  **Before submitting Sherpa:** the local run builds the Comix/Amegic process libs
  under `sherpa/local_run/`. The batch jobs read them from `sherpa/Process` (+
  `sherpa/Results`) so all jobs skip the (slow) recompile/re-integration — lift them
  up once: `cp -a sherpa/local_run/Process sherpa/local_run/Results sherpa/`
  (or rerun `./prepare.sh`). Also note `MEPS@LO` is much slower per event than a
  plain shower, so test the per-job walltime before the full `NSEEDS×NEV`.

- **Herwig** (`herwig`/`amcnlo_herwig`/`mglo_herwig`) — see the Herwig caveat above;
  the internal-ME steering and the LHE-reader PDF lines are release-sensitive. If
  `Herwig read` errors, compare with the `LHC-*.in` examples in the Herwig share dir.

- **powheg** — needs a `Zj` `pwhg_main` (from CVMFS or built once by `prepare.sh`);
  the local tester errors out early if it isn't present.

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
