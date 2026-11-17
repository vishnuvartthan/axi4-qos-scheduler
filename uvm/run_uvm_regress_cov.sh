#!/usr/bin/env bash
set -euo pipefail

tests=(
  qos_smoke_test
  qos_mixed_traffic_test
  qos_aw_w_order_test
  qos_response_routing_test
  qos_response_reorder_error_test
  qos_axi_sideband_test
  qos_mid_transaction_reset_test
  qos_multibeat_read_test
  qos_source_fifo_backpressure_test
  qos_aw_order_full_recovery_test
  qos_weighted_fairness_test
  qos_aging_override_test
  qos_csr_counter_test
  qos_csr_dynamic_update_test
  qos_csr_dynamic_update_cr_test
  qos_policy_corner_test
  qos_low_ready_zero_weight_mix_test
  qos_zero_weight_backpressure_test
)

seeds=(1 5 10 17 25 50 75 101 125 150)

rm -rf out/vcs_logs out/vcs_cov out/vcs_urg out/vcs_build
mkdir -p out/vcs_logs out/vcs_cov out/vcs_urg out/vcs_build

results_csv="out/vcs_logs/regression_results.csv"
printf 'test,seed,status,uvm_errors,uvm_fatals,log\n' > "$results_csv"

vcs -full64 -sverilog -ntb_opts uvm -notice \
  -timescale=1ps/1ps \
  -cm line+cond+tgl+branch+assert \
  -cm_dir out/vcs_cov/qos_uvm.vdb \
  -f files_uvm_local.f \
  -top tb_uvm_axi4_scheduler \
  -o out/vcs_build/simv \
  -l out/vcs_logs/compile.log

pass_count=0
fail_count=0

printf '%-42s %-8s %-8s\n' "TEST" "SEED" "STATUS"

for seed in "${seeds[@]}"; do
  for t in "${tests[@]}"; do
    run_name="${t}_seed_${seed}"
    log="out/vcs_logs/${run_name}.log"
    run_rc=0

    ./run_vcs_local.sh +UVM_TESTNAME="$t" +ntb_random_seed="$seed" || run_rc=$?

    uvm_errors=-1
    uvm_fatals=-1

    if [[ -f "$log" ]]; then
      uvm_errors=$(awk '$1 == "UVM_ERROR" && $2 == ":" {value=$3} END {if (value == "") print -1; else print value}' "$log")
      uvm_fatals=$(awk '$1 == "UVM_FATAL" && $2 == ":" {value=$3} END {if (value == "") print -1; else print value}' "$log")
    fi

    if [[ "$run_rc" -eq 0 && "$uvm_errors" -eq 0 && "$uvm_fatals" -eq 0 ]]; then
      status="PASS"
      ((pass_count += 1))
    else
      status="FAIL"
      ((fail_count += 1))
    fi

    printf '%s,%s,%s,%s,%s,%s\n' \
      "$t" "$seed" "$status" "$uvm_errors" "$uvm_fatals" "$log" >> "$results_csv"
    printf '%-42s %-8s %-8s\n' "$t" "$seed" "$status"
  done
done

total_count=$((pass_count + fail_count))

printf '\nRegression summary: %d passed, %d failed, %d total\n' \
  "$pass_count" "$fail_count" "$total_count"
printf 'Results: %s\n' "$results_csv"

coverage_rc=0
urg -full64 \
  -dir out/vcs_cov/qos_uvm.vdb \
  -report out/vcs_urg \
  -format both || coverage_rc=$?

if [[ "$fail_count" -ne 0 || "$coverage_rc" -ne 0 ]]; then
  exit 1
fi
