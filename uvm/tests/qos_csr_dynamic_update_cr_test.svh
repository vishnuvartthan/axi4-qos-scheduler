  class qos_csr_dynamic_update_cr_test extends qos_csr_dynamic_update_test;
    `uvm_component_utils(qos_csr_dynamic_update_cr_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      qos_ar_stream_seq seq[NUM_REQ];
      int unsigned phase0_start[NUM_REQ];
      int unsigned phase0_end[NUM_REQ];
      int unsigned phase1_start[NUM_REQ];
      int unsigned phase1_end[NUM_REQ];
      int unsigned phase0_weights[NUM_REQ];
      int unsigned phase1_weights[NUM_REQ];
      int unsigned phase0_dominant;
      int unsigned phase1_dominant;
      int unsigned phase0_w0;
      int unsigned phase0_w1;
      int unsigned phase0_w2;
      int unsigned phase0_w3;
      int unsigned phase1_w0;
      int unsigned phase1_w1;
      int unsigned phase1_w2;
      int unsigned phase1_w3;
      int unsigned phase0_settle_cycles;
      int unsigned phase1_settle_cycles;
      int unsigned phase0_measure_cycles;
      int unsigned phase1_measure_cycles;

      phase.raise_objection(this);
      env.sb.set_allow_pending_ar(1'b1);

      if (!std::randomize(phase0_dominant,
                          phase1_dominant,
                          phase0_w0,
                          phase0_w1,
                          phase0_w2,
                          phase0_w3,
                          phase1_w0,
                          phase1_w1,
                          phase1_w2,
                          phase1_w3,
                          phase0_settle_cycles,
                          phase1_settle_cycles,
                          phase0_measure_cycles,
                          phase1_measure_cycles) with {
            phase0_dominant inside {[0:NUM_REQ-1]};
            phase1_dominant inside {[0:NUM_REQ-1]};
            phase0_dominant != phase1_dominant;

            if (phase0_dominant == 0) {
              phase0_w0 inside {[8:15]};
              phase0_w1 inside {[1:3]};
              phase0_w2 inside {[1:3]};
              phase0_w3 inside {[1:3]};
            } else if (phase0_dominant == 1) {
              phase0_w0 inside {[1:3]};
              phase0_w1 inside {[8:15]};
              phase0_w2 inside {[1:3]};
              phase0_w3 inside {[1:3]};
            } else if (phase0_dominant == 2) {
              phase0_w0 inside {[1:3]};
              phase0_w1 inside {[1:3]};
              phase0_w2 inside {[8:15]};
              phase0_w3 inside {[1:3]};
            } else {
              phase0_w0 inside {[1:3]};
              phase0_w1 inside {[1:3]};
              phase0_w2 inside {[1:3]};
              phase0_w3 inside {[8:15]};
            }

            if (phase1_dominant == 0) {
              phase1_w0 inside {[8:15]};
              phase1_w1 inside {[1:3]};
              phase1_w2 inside {[1:3]};
              phase1_w3 inside {[1:3]};
            } else if (phase1_dominant == 1) {
              phase1_w0 inside {[1:3]};
              phase1_w1 inside {[8:15]};
              phase1_w2 inside {[1:3]};
              phase1_w3 inside {[1:3]};
            } else if (phase1_dominant == 2) {
              phase1_w0 inside {[1:3]};
              phase1_w1 inside {[1:3]};
              phase1_w2 inside {[8:15]};
              phase1_w3 inside {[1:3]};
            } else {
              phase1_w0 inside {[1:3]};
              phase1_w1 inside {[1:3]};
              phase1_w2 inside {[1:3]};
              phase1_w3 inside {[8:15]};
            }

            phase0_settle_cycles inside {[40:80]};
            phase1_settle_cycles inside {[40:80]};
            phase0_measure_cycles inside {[600:900]};
            phase1_measure_cycles inside {[600:900]};
          })
        `uvm_fatal("CSR_DYNAMIC_CR_CFG", "dynamic policy scenario randomization failed")

      phase0_weights = '{phase0_w0, phase0_w1, phase0_w2, phase0_w3};
      phase1_weights = '{phase1_w0, phase1_w1, phase1_w2, phase1_w3};

      `uvm_info("CSR_DYNAMIC_CR_CFG",
        $sformatf("phase0 weights=%0d:%0d:%0d:%0d dominant=%0d settle=%0d measure=%0d; phase1 weights=%0d:%0d:%0d:%0d dominant=%0d settle=%0d measure=%0d",
                  phase0_w0, phase0_w1, phase0_w2, phase0_w3,
                  phase0_dominant, phase0_settle_cycles, phase0_measure_cycles,
                  phase1_w0, phase1_w1, phase1_w2, phase1_w3,
                  phase1_dominant, phase1_settle_cycles, phase1_measure_cycles),
        UVM_LOW)

      program_weights(phase0_w0, phase0_w1, phase0_w2, phase0_w3, 8'hff);
      check_programmed_policy("phase0",
                              phase0_w0, phase0_w1, phase0_w2, phase0_w3, 8'hff);

      for (int i = 0; i < NUM_REQ; i++) begin
        automatic int s = i;

        fork
          begin
            seq[s] = qos_ar_stream_seq::type_id::create($sformatf("dynamic_cr_ar_%0d", s));
            seq[s].src      = s;
            seq[s].n_txn    = 4096;
            seq[s].idle_max = 0;
            seq[s].start(env.src_agent[s].seqr);
          end
        join_none
      end

      repeat (phase0_settle_cycles) @(posedge cfg.vif.clk);
      sample_grants(phase0_start);
      repeat (phase0_measure_cycles) @(posedge cfg.vif.clk);
      sample_grants(phase0_end);
      check_distribution("randomized_phase0",
                         phase0_start, phase0_end, phase0_weights, phase0_dominant);

      program_weights(phase1_w0, phase1_w1, phase1_w2, phase1_w3, 8'hff);
      check_programmed_policy("phase1",
                              phase1_w0, phase1_w1, phase1_w2, phase1_w3, 8'hff);

      repeat (phase1_settle_cycles) @(posedge cfg.vif.clk);
      sample_grants(phase1_start);
      repeat (phase1_measure_cycles) @(posedge cfg.vif.clk);
      sample_grants(phase1_end);
      check_distribution("randomized_phase1",
                         phase1_start, phase1_end, phase1_weights, phase1_dominant);

      phase.drop_objection(this);
    endtask
  endclass


