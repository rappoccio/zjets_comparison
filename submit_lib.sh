# Shared HTCondor submission helper. Source after config.sh.
#
# condor_launch <tag> <executable> <njobs> <flavour> <arguments>
#   * stages <executable> + gen.sub into an AFS submit dir (per <tag>, so batches
#     don't collide), creates the EOS output dir, and submits <njobs> jobs.
#   * <arguments> is the condor `arguments` line; put the literal $(Process) in it
#     for the per-job seed (quote it so the shell doesn't expand it).
condor_launch() {
  local tag="$1" exe="$2" njobs="$3" flavour="$4" args="$5"
  local sdir="$SUBMIT_ROOT/$tag"
  local outdir="$PKG/yodas/$tag"

  [ -f "$PKG/$exe" ] || { echo "missing payload: $PKG/$exe" >&2; return 1; }
  mkdir -p "$sdir/log" "$outdir"
  cp -f "$PKG/$exe" "$PKG/gen.sub" "$sdir/"

  echo ">>> $tag: $njobs jobs ($flavour)  ->  $outdir"
  ( cd "$sdir" && condor_submit \
      -append "executable = $exe" \
      -append "arguments  = $args" \
      -append "+JobFlavour = \"$flavour\"" \
      -append "queue $njobs" \
      gen.sub )
  echo "    logs: $sdir/log"
}
