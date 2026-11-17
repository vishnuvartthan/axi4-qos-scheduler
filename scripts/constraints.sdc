current_design axi4_scheduler_top

create_clock -name clk -period 10.000 [get_ports clk]


set_clock_uncertainty 0.500 [get_clocks clk]
set_clock_transition  0.200 [get_clocks clk]


set_input_delay  -max 1.000 -clock clk [remove_from_collection [all_inputs] [get_ports {clk rst_n}]]
set_input_delay  -min 0.200 -clock clk [remove_from_collection [all_inputs] [get_ports {clk rst_n}]]
set_output_delay -max 1.000 -clock clk [all_outputs]
set_output_delay -min 0.200 -clock clk [all_outputs]

set_input_transition 1.000 [remove_from_collection [all_inputs] [get_ports {clk rst_n}]]

set_load 0.020 [all_outputs]
set_max_fanout 16 [current_design]
