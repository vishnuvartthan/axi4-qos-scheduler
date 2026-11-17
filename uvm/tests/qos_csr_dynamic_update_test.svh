  class qos_csr_dynamic_update_test extends qos_base_test;
    `uvm_component_utils(qos_csr_dynamic_update_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      cfg.ready_pct = 100;
    endfunction

    task sample_grants(output int unsigned grant[NUM_REQ]);
      for (int i = 0; i < NUM_REQ; i++)
        grant[i] = env.policy.get_ar_grants(i);
    endtask

    task check_distribution(input string tag,
                            input int unsigned start_count[NUM_REQ],
                            input int unsigned end_count[NUM_REQ],
                            input int unsigned weights[NUM_REQ],
                            input int unsigned dominant_src);
      int unsigned delta[NUM_REQ];
      int unsigned total;
      int unsigned weight_total;
      int unsigned expected;
      int unsigned diff;
      int unsigned tolerance;

      total        = 0;
      weight_total = 0;

      for (int i = 0; i < NUM_REQ; i++) begin
        delta[i] = end_count[i] - start_count[i];
        total += delta[i];
        weight_total += weights[i];
      end

      if (total < 300)
        `uvm_error("CSR_DYNAMIC",
          $sformatf("%s sampled too few grants: total=%0d", tag, total))

      for (int i = 0; i < NUM_REQ; i++) begin
        expected = (total * weights[i]) / weight_total;
        diff = (delta[i] > expected) ? (delta[i] - expected) : (expected - delta[i]);
        tolerance = weights[i] + (NUM_REQ * 3);

        if (diff > tolerance)
          `uvm_error("CSR_DYNAMIC",
            $sformatf("%s src%0d grants=%0d expected_approx=%0d tolerance=%0d total=%0d",
                      tag, i, delta[i], expected, tolerance, total))
      end

      for (int i = 0; i < NUM_REQ; i++) begin
        if ((i != dominant_src) && (delta[dominant_src] <= delta[i]))
          `uvm_error("CSR_DYNAMIC",
            $sformatf("%s dominant src%0d grants=%0d did not exceed src%0d grants=%0d",
                      tag, dominant_src, delta[dominant_src], i, delta[i]))
      end
    endtask

    task run_phase(uvm_phase phase);
      qos_ar_stream_seq seq[NUM_REQ];
      int unsigned phase0_start[NUM_REQ];
      int unsigned phase0_end[NUM_REQ];
      int unsigned phase1_start[NUM_REQ];
      int unsigned phase1_end[NUM_REQ];
      int unsigned phase0_weights[NUM_REQ] = '{8, 1, 1, 1};
      int unsigned phase1_weights[NUM_REQ] = '{1, 1, 1, 8};

      phase.raise_objection(this);
      env.sb.set_allow_pending_ar(1'b1);

      program_weights(8, 1, 1, 1, 8'hff);

      for (int i = 0; i < NUM_REQ; i++) begin
        automatic int s = i;
        fork
          begin
            seq[s] = qos_ar_stream_seq::type_id::create($sformatf("dynamic_ar_%0d", s));
            seq[s].src      = s;
            seq[s].n_txn    = 4096;
            seq[s].idle_max = 0;
            seq[s].start(env.src_agent[s].seqr);
          end
        join_none
      end

      repeat (60) @(posedge cfg.vif.clk);
      sample_grants(phase0_start);
      repeat (600) @(posedge cfg.vif.clk);
      sample_grants(phase0_end);
      check_distribution("weights_8_1_1_1",
                         phase0_start, phase0_end, phase0_weights, 0);

      program_weights(1, 1, 1, 8, 8'hff);

      repeat (40) @(posedge cfg.vif.clk);
      sample_grants(phase1_start);
      repeat (600) @(posedge cfg.vif.clk);
      sample_grants(phase1_end);
      check_distribution("weights_1_1_1_8",
                         phase1_start, phase1_end, phase1_weights, 3);

      phase.drop_objection(this);
    endtask
  endclass
