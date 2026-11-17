  class qos_zero_weight_backpressure_test extends qos_base_test;
    `uvm_component_utils(qos_zero_weight_backpressure_test)

    bit [NUM_REQ-1:0] zero_mask;
    int unsigned w0;
    int unsigned w1;
    int unsigned w2;
    int unsigned w3;
    int unsigned aging;
    int unsigned downstream_ready_pct;
    int unsigned source_rready_pct;
    int unsigned source_bready_pct;
    int unsigned n_ar;
    int unsigned n_wr;
    int unsigned max_len;
    int unsigned idle_max;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      if (!std::randomize(zero_mask,
                          w0,
                          w1,
                          w2,
                          w3,
                          aging,
                          downstream_ready_pct,
                          source_rready_pct,
                          source_bready_pct,
                          n_ar,
                          n_wr,
                          max_len,
                          idle_max) with {
            zero_mask inside {[1:14]};

            if (zero_mask[0])
              w0 == 0;
            else
              w0 inside {[2:15]};

            if (zero_mask[1])
              w1 == 0;
            else
              w1 inside {[2:15]};

            if (zero_mask[2])
              w2 == 0;
            else
              w2 inside {[2:15]};

            if (zero_mask[3])
              w3 == 0;
            else
              w3 inside {[2:15]};

            aging inside {[2:12]};
            downstream_ready_pct inside {[25:55]};
            source_rready_pct inside {[30:65]};
            source_bready_pct inside {[30:65]};
            n_ar inside {[96:144]};
            n_wr inside {[20:36]};
            max_len inside {[7:15]};
            idle_max inside {[0:3]};
          })
        `uvm_fatal("ZERO_WEIGHT_CFG", "zero weight backpressure scenario randomization failed")

      cfg.ready_pct = downstream_ready_pct;
      cfg.source_resp_ready_randomize = 1'b1;
      cfg.rready_pct = source_rready_pct;
      cfg.bready_pct = source_bready_pct;

      `uvm_info("ZERO_WEIGHT_CFG",
        $sformatf("zero_mask=0x%0h weights=%0d:%0d:%0d:%0d aging=%0d downstream_ready=%0d%% source_rready=%0d%% source_bready=%0d%% ar_per_src=%0d wr_per_src=%0d max_len=%0d idle_max=%0d",
                  zero_mask, w0, w1, w2, w3, aging,
                  cfg.ready_pct, cfg.rready_pct, cfg.bready_pct,
                  n_ar, n_wr, max_len, idle_max),
        UVM_LOW)
    endfunction

    task run_phase(uvm_phase phase);
      qos_cr_ar_stream_seq   ar_seq[NUM_REQ];
      qos_cr_aw_w_stream_seq wr_seq[NUM_REQ];
      int unsigned grant_start[NUM_REQ];
      int unsigned grant_end[NUM_REQ];
      int unsigned age_start[NUM_REQ];
      int unsigned age_end[NUM_REQ];
      bit [31:0] stall_start;
      bit [31:0] stall_end;
      int unsigned ar_start;
      int unsigned aw_start;
      int unsigned w_start;
      int unsigned r_start;
      int unsigned r_burst_start;
      int unsigned b_start;
      int unsigned expected_r_beats;
      int unsigned expected_w_beats;
      int unsigned cycles;

      phase.raise_objection(this);

      program_weights(w0, w1, w2, w3, aging);
      check_programmed_policy("zero_weight", w0, w1, w2, w3, aging);

      for (int i = 0; i < NUM_REQ; i++) begin
        grant_start[i] = env.policy.get_total_grants(i);
        age_start[i]   = env.policy.get_total_age_grants(i);
      end

      csr_rd(8'h40, stall_start);

      ar_start      = env.sb.get_ar_checks();
      aw_start      = env.sb.get_aw_checks();
      w_start       = env.sb.get_w_beat_checks();
      r_start       = env.sb.get_r_route_checks();
      r_burst_start = env.sb.get_r_burst_checks();
      b_start       = env.sb.get_b_route_checks();

      env.mem.set_ready_pct(0);

      for (int i = 0; i < NUM_REQ; i++) begin
        automatic int s = i;

        fork
          begin
            ar_seq[s] = qos_cr_ar_stream_seq::type_id::create(
              $sformatf("zero_weight_ar_%0d", s));
            ar_seq[s].src      = s;
            ar_seq[s].n_txn    = n_ar;
            ar_seq[s].idle_max = idle_max;
            ar_seq[s].max_len  = max_len;
            ar_seq[s].same_id  = 1'b0;
            ar_seq[s].start(env.src_agent[s].seqr);
          end

          begin
            wr_seq[s] = qos_cr_aw_w_stream_seq::type_id::create(
              $sformatf("zero_weight_wr_%0d", s));
            wr_seq[s].src      = s;
            wr_seq[s].n_txn    = n_wr;
            wr_seq[s].idle_max = idle_max;
            wr_seq[s].max_len  = max_len;
            wr_seq[s].same_id  = 1'b0;
            wr_seq[s].start(env.src_agent[s].seqr);
          end
        join_none
      end

      cycles = 0;
      while (!(cfg.vif.master_mon_cb.M_AXI_ARVALID ||
               cfg.vif.master_mon_cb.M_AXI_AWVALID) &&
             (cycles < 200)) begin
        @(cfg.vif.master_mon_cb);
        cycles++;
      end

      if (!(cfg.vif.master_mon_cb.M_AXI_ARVALID ||
            cfg.vif.master_mon_cb.M_AXI_AWVALID))
        `uvm_error("ZERO_WEIGHT", "failed to establish downstream request backpressure")
      else
        repeat (8) @(cfg.vif.master_mon_cb);

      env.mem.set_ready_pct(downstream_ready_pct);

      wait fork;
      wait_scoreboard_drain(60000);

      expected_r_beats = 0;
      expected_w_beats = 0;

      for (int i = 0; i < NUM_REQ; i++) begin
        expected_r_beats += ar_seq[i].generated_beats;
        expected_w_beats += wr_seq[i].generated_beats;
      end

      if ((env.sb.get_ar_checks() - ar_start) != (NUM_REQ * n_ar))
        `uvm_error("ZERO_WEIGHT",
          $sformatf("AR checks=%0d expected=%0d",
                    env.sb.get_ar_checks() - ar_start, NUM_REQ * n_ar))

      if ((env.sb.get_aw_checks() - aw_start) != (NUM_REQ * n_wr))
        `uvm_error("ZERO_WEIGHT",
          $sformatf("AW checks=%0d expected=%0d",
                    env.sb.get_aw_checks() - aw_start, NUM_REQ * n_wr))

      if ((env.sb.get_w_beat_checks() - w_start) != expected_w_beats)
        `uvm_error("ZERO_WEIGHT",
          $sformatf("W beat checks=%0d expected=%0d",
                    env.sb.get_w_beat_checks() - w_start, expected_w_beats))

      if ((env.sb.get_r_route_checks() - r_start) != expected_r_beats)
        `uvm_error("ZERO_WEIGHT",
          $sformatf("R beat checks=%0d expected=%0d",
                    env.sb.get_r_route_checks() - r_start, expected_r_beats))

      if ((env.sb.get_r_burst_checks() - r_burst_start) != (NUM_REQ * n_ar))
        `uvm_error("ZERO_WEIGHT",
          $sformatf("R burst checks=%0d expected=%0d",
                    env.sb.get_r_burst_checks() - r_burst_start, NUM_REQ * n_ar))

      if ((env.sb.get_b_route_checks() - b_start) != (NUM_REQ * n_wr))
        `uvm_error("ZERO_WEIGHT",
          $sformatf("B route checks=%0d expected=%0d",
                    env.sb.get_b_route_checks() - b_start, NUM_REQ * n_wr))

      for (int i = 0; i < NUM_REQ; i++) begin
        grant_end[i] = env.policy.get_total_grants(i);
        age_end[i]   = env.policy.get_total_age_grants(i);
      end

      csr_rd(8'h40, stall_end);

      for (int i = 0; i < NUM_REQ; i++) begin
        if ((grant_end[i] - grant_start[i]) != (n_ar + n_wr))
          `uvm_error("ZERO_WEIGHT",
            $sformatf("source %0d zero_weight=%0b grant delta=%0d expected=%0d",
                      i, zero_mask[i], grant_end[i] - grant_start[i], n_ar + n_wr))

        if (zero_mask[i] && (age_end[i] == age_start[i]))
          `uvm_error("ZERO_WEIGHT",
            $sformatf("zero weight source %0d had no observed aging grant", i))
      end

      if (stall_end == stall_start)
        `uvm_error("ZERO_WEIGHT", "stall counter did not advance")

      phase.drop_objection(this);
    endtask
  endclass
