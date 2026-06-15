# zjets_comparison — self-contained Z+jets prediction vs HepData (CMS_2026_PAS_SMP_25_010)

Everything needed to generate particle-level **Z+jets** predictions and overlay
them on the unfolded HepData (normalized jet mass `log10(rho^2)` in 3 leading-jet
pT slices, groomed & ungroomed), with `rivet-mkhtml`. Designed to run **natively
on lxplus via a CVMFS LCG view** + **HTCondor** — no Docker, no container.

Copy this whole directory to **EOS** (not AFS home), then:

```bash
vi config.sh        # set LCG_VIEW (Rivet >= 4.0), NEV, NSEEDS
./prepare.sh        # ONCE: build the plugin + driver under the LCG view
./submit.sh         # queue NSEEDS parallel jobs   (total = NEV*NSEEDS events)
condor_q            #   ...watch them finish...
./merge_plot.sh     # sum the seeds + make plots  ->  html/index.html
```

Quick end-to-end check before a big run: `NEV=20000 NSEEDS=4` in `config.sh`.

## Contents

```
config.sh                     <- the ONLY file you edit (paths, stats, LCG view)
prepare.sh                    one-time build of the plugin + pythia8-rivet
submit.sh / gen.sub / gen_job.sh   HTCondor: one seed per job, YODA -> yodas/<tag>/
merge_plot.sh                 sum seeds -> build_comparison.py -> rivet-mkhtml
build_comparison.py           slices each 2D prediction to per-slice unit-area 1D,
                              builds the /REF data from the npz
CMS_2026_PAS_SMP_25_010.cc    the Rivet analysis (2D, HepData binning)
hepdata_export_groomed.npz    the data (Z+jets, groomed)
hepdata_export_ungroomed.npz  the data (Z+jets, ungroomed)
pythia/                       main_rivet.cc, Makefile, cp5.cmnd, zjets.cmnd
madgraph/                     zjets.mg5 + gen_madgraph.sh  (optional aMC@NLO)
lhapdf-cache/                 CP5 PDF (NNPDF31_nnlo_as_0118), used if CVMFS lacks it
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

## More generators

- **VINCIA**: set `TAG=vincia MODEL=2` (and a distinct `OUTDIR`) in `config.sh`,
  re-run `./submit.sh`, then `./merge_plot.sh VINCIA=yodas/vincia`.
- **aMC@NLO** (optional, needs an LCG view with MadGraph): `./madgraph/gen_madgraph.sh`,
  then `./merge_plot.sh aMCNLO=yodas/amcnlo`.

## Notes

- Keep the package on **EOS** so HTCondor workers can read inputs. `prepare.sh`
  builds against CVMFS, which the workers also mount.
- **lxplus batch + EOS:** the standard schedds forbid `/eos` paths *in the submit
  file*, so `submit.sh` automatically stages Condor's control files (executable +
  logs) to **`$SUBMIT_DIR`** on AFS (default `~/zjets_submit`), and each job copies
  its YODA back to `OUTDIR` on EOS with `xrdcp`. You don't have to do anything —
  just keep a little AFS quota free. (Alternative: the EosSubmit schedds let you
  keep everything on EOS — https://batchdocs.web.cern.ch/local/eossubmit.html.)
- Seeds are **summed** (raw counts) by `build_comparison.py`, so N jobs = N× stats.
  The `pT>400` slice needs the most events.
- The CP5 PDF is bundled; generation is otherwise offline. `gen.sub` renews the
  EOS/Kerberos token (`MY.SendCredential`) for long jobs.
- Analysis binning (must match the data): pT edges `200,290,400,∞`; mass edges
  `-10,-4.5,-4,…,-0.5,0`. Change both the `.cc` and the data if you rebin.
