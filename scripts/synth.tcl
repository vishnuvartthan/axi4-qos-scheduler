# ————————————————————————————————————————————————————————————
# Genus single-corner synthesis script
# Project: scheduler
# Author: Vishnu G.
# ————————————————————————————————————————————————————————————

set RTL_FILES [list \
    req_fifo.sv \
    age_tracker.sv \
    wrr_arbiter.sv \
    scheduler_core.sv \
    csr_regs.sv \
    axi4lite_csr_if.sv \
    aw_src_order_fifo.sv \
    scheduler_channel.sv \
    axi4_scheduler_top.sv
]


file mkdir reports
file mkdir outputs

test_super_thread_servers

set_db init_lib_search_path ../../lib/skywater130
set_db init_hdl_search_path ../rtl
set_db library sky130_fd_sc_hd__tt_025C_1v80.lib

read_hdl -sv $RTL_FILES

elaborate axi4_scheduler_top

read_sdc ../scripts/constraints.sdc

set_db syn_generic_effort medium
syn_generic
set_db syn_map_effort high
syn_map
set_db syn_opt_effort high
syn_opt

proc next_report_name {basefile} {
    set root [file rootname $basefile]
    set ext  [file extension $basefile]
    set candidate $basefile
    set i 1
    while {[file exists $candidate]} {
        set candidate "${root}_$i$ext"
        incr i
    }
    return $candidate
}
set timing_rpt [next_report_name "reports/timing.rpt"]
set qor_rpt [next_report_name "reports/qor.rpt"]
set power_rpt [next_report_name "reports/power.rpt"]


# report_qor    > reports/qor.rpt
report_timing -max_paths 20 > reports/timing_125.rpt
# report_area   > reports/area.rpt
# report_power  > reports/power.rpt

# write_hdl > outputs/scheduler_netlist.v
# write_sdc > outputs/scheduler_sdc.sdc
# write_sdf -timescale ns -nonegchecks -recrem split -edges check_edge -setuphold split > outputs/delays.sdf

exit
