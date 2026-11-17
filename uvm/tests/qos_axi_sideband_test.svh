  class qos_axi_sideband_test extends qos_base_test;
    `uvm_component_utils(qos_axi_sideband_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      int unsigned ready_pct;
      int unsigned rready_pct;
      int unsigned bready_pct;

      super.build_phase(phase);

      if (!std::randomize(ready_pct, rready_pct, bready_pct) with {
            ready_pct  inside {[55:85]};
            rready_pct inside {[45:85]};
            bready_pct inside {[45:85]};
          })
        `uvm_fatal("SIDEBAND_CFG", "backpressure configuration randomization failed")

      cfg.ready_pct = ready_pct;
      cfg.source_resp_ready_randomize = 1'b1;
      cfg.rready_pct = rready_pct;
      cfg.bready_pct = bready_pct;

      `uvm_info("SIDEBAND_CFG",
        $sformatf("downstream_ready=%0d%% source_rready=%0d%% source_bready=%0d%%",
                  cfg.ready_pct, cfg.rready_pct, cfg.bready_pct),
        UVM_LOW)
    endfunction

    task run_phase(uvm_phase phase);
      qos_cr_ar_stream_seq   ar_seq[NUM_REQ];
      qos_cr_aw_w_stream_seq wr_seq[NUM_REQ];
      int unsigned sideband_start;
      int unsigned expected_sideband_checks;
      int unsigned expected_r_beats;
      int unsigned expected_w_beats;

      phase.raise_objection(this);
      program_weights(1, 2, 4, 8, 8'h40);
      sideband_start = env.sb.get_sideband_checks();

      for (int i = 0; i < NUM_REQ; i++) begin
        automatic int s = i;

        fork
          begin
            ar_seq[s] =
              qos_cr_ar_stream_seq::type_id::create($sformatf("sideband_ar_%0d", s));
            ar_seq[s].src                = s;
            ar_seq[s].n_txn              = 32;
            ar_seq[s].idle_max           = 5;
            ar_seq[s].max_len            = 15;
            ar_seq[s].randomize_sideband = 1'b1;
            ar_seq[s].start(env.src_agent[s].seqr);
          end

          begin
            wr_seq[s] =
              qos_cr_aw_w_stream_seq::type_id::create($sformatf("sideband_wr_%0d", s));
            wr_seq[s].src                = s;
            wr_seq[s].n_txn              = 24;
            wr_seq[s].idle_max           = 5;
            wr_seq[s].max_len            = 15;
            wr_seq[s].randomize_sideband = 1'b1;
            wr_seq[s].start(env.src_agent[s].seqr);
          end
        join_none
      end

      wait fork;
      wait_scoreboard_drain(24000);

      expected_sideband_checks = NUM_REQ * (32 + 24);
      expected_r_beats = 0;
      expected_w_beats = 0;

      for (int i = 0; i < NUM_REQ; i++) begin
        expected_r_beats += ar_seq[i].generated_beats;
        expected_w_beats += wr_seq[i].generated_beats;
      end

      if ((env.sb.get_sideband_checks() - sideband_start) != expected_sideband_checks)
        `uvm_error("SIDEBAND",
          $sformatf("sideband checks=%0d expected=%0d",
                    env.sb.get_sideband_checks() - sideband_start,
                    expected_sideband_checks))

      if ((env.sb.get_sideband_size_seen() & 8'h07) != 8'h07)
        `uvm_error("SIDEBAND",
          $sformatf("SIZE values were not all exercised: seen=0x%0h",
                    env.sb.get_sideband_size_seen()))

      if (((env.sb.get_sideband_burst_seen() & 4'h7) != 4'h7) ||
          ((env.sb.get_sideband_burst_seen() & 4'h8) != 0))
        `uvm_error("SIDEBAND",
          $sformatf("master did not receive every legal BURST value, or received reserved value: seen=0x%0h",
                    env.sb.get_sideband_burst_seen()))

      if (env.sb.get_sideband_lock_seen() != 2'b11)
        `uvm_error("SIDEBAND",
          $sformatf("LOCK values were not both exercised: seen=0x%0h",
                    env.sb.get_sideband_lock_seen()))

      if ((env.mem.get_read_exokay_sources() != {NUM_REQ{1'b1}}) ||
          (env.mem.get_write_exokay_sources() != {NUM_REQ{1'b1}}))
        `uvm_error("SIDEBAND",
          $sformatf("EXOKAY routing was not observed for every source: R=0x%0h B=0x%0h",
                    env.mem.get_read_exokay_sources(), env.mem.get_write_exokay_sources()))

      if (!(env.sb.get_sideband_cache_zero_seen() && env.sb.get_sideband_cache_nonzero_seen() &&
            env.sb.get_sideband_prot_zero_seen()  && env.sb.get_sideband_prot_nonzero_seen()  &&
            env.sb.get_sideband_qos_zero_seen()   && env.sb.get_sideband_qos_nonzero_seen()))
        `uvm_error("SIDEBAND", "CACHE/PROT/QOS boundary categories were not all exercised")

      if (env.sb.get_r_route_checks() != expected_r_beats)
        `uvm_error("SIDEBAND", "read response beat count mismatch")

      if (env.sb.get_w_beat_checks() != expected_w_beats)
        `uvm_error("SIDEBAND", "write data beat count mismatch")

      phase.drop_objection(this);
    endtask
  endclass
