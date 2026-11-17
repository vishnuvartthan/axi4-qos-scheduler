#!/usr/bin/env bash
set -euo pipefail

TESTNAME="qos_smoke_test"
SEED=""
sim_args=()

for arg in "$@"; do
  case "$arg" in
    +UVM_TESTNAME=*) TESTNAME="${arg#*=}" ;;
    +ntb_random_seed=*)
      SEED="${arg#*=}"
      sim_args+=("$arg")
      ;;
    *) sim_args+=("$arg") ;;
  esac
done

run_name="$TESTNAME"
if [[ -n "$SEED" ]]; then
  if [[ ! "$SEED" =~ ^[0-9]+$ ]]; then
    echo "Invalid VCS seed: $SEED" >&2
    exit 2
  fi
  run_name="${TESTNAME}_seed_${SEED}"
fi

mkdir -p out/vcs_logs out/vcs_cov

./out/vcs_build/simv \
  +UVM_TESTNAME="$TESTNAME" \
  -cm line+cond+tgl+branch+assert \
  -cm_name "$run_name" \
  -cm_dir out/vcs_cov/qos_uvm.vdb \
  -l "out/vcs_logs/${run_name}.log" \
  "${sim_args[@]}"
