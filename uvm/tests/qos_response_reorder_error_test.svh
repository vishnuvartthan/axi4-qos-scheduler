  class qos_response_reorder_error_test extends qos_base_test;
    `uvm_component_utils(qos_response_reorder_error_test)

    // Ten requests include one exclusive access while responses return in order.
    localparam int unsigned ORDERED_TXNS_PER_SOURCE = 10;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      int unsigned ready_pct;
      int unsigned rready_pct;
      int unsigned bready_pct;

      super.build_phase(phase);

      if (!std::randomize(ready_pct, rready_pct, bready_pct) with {
            ready_pct  inside {[70:90]};
            rready_pct inside {[45:80]};
            bready_pct inside {[45:80]};
          })
        `uvm_fatal("RESP_REORDER_CFG", "response configuration randomization failed")

      cfg.ready_pct = ready_pct;
      cfg.source_resp_ready_randomize = 1'b1;
      cfg.rready_pct = rready_pct;
      cfg.bready_pct = bready_pct;

      `uvm_info("RESP_REORDER_CFG",
        $sformatf("downstream_ready=%0d%% source_rready=%0d%% source_bready=%0d%%",
                  cfg.ready_pct, cfg.rready_pct, cfg.bready_pct),
        UVM_LOW)
    endfunction

    task run_phase(uvm_phase phase);
      qos_cr_ar_stream_seq   ar_seq[NUM_REQ];
      qos_cr_aw_w_stream_seq wr_seq[NUM_REQ];
      qos_cr_ar_stream_seq   ordered_ar;
      qos_cr_aw_w_stream_seq ordered_wr;
      int unsigned expected_r_beats;
      int unsigned expected_w_beats;
      int unsigned ordered_r_start;
      int unsigned ordered_b_start;

      phase.raise_objection(this);

      env.mem.set_response_enable(1'b0);
      env.mem.set_response_reorder_enable(1'b1);
      env.mem.set_error_injection_enable(1'b1);
      env.mem.set_response_collect_cycles(12);
      env.mem.set_response_reorder_depth(6);
      env.mem.set_response_error_period(3);
      program_weights(1, 2, 4, 8, 8'h40);

      for (int i = 0; i < NUM_REQ; i++) begin
        automatic int s = i;

        fork
          begin
            ar_seq[s] =
              qos_cr_ar_stream_seq::type_id::create($sformatf("reorder_ar_%0d", s));
            ar_seq[s].src      = s;
            ar_seq[s].n_txn    = 24;
            ar_seq[s].idle_max = 4;
            ar_seq[s].max_len  = 7;
            ar_seq[s].same_id  = 1'b0;
            ar_seq[s].randomize_sideband = 1'b1;
            ar_seq[s].start(env.src_agent[s].seqr);
          end

          begin
            wr_seq[s] =
              qos_cr_aw_w_stream_seq::type_id::create($sformatf("reorder_wr_%0d", s));
            wr_seq[s].src      = s;
            wr_seq[s].n_txn    = 12;
            wr_seq[s].idle_max = 4;
            wr_seq[s].max_len  = 7;
            wr_seq[s].same_id  = 1'b0;
            wr_seq[s].randomize_sideband = 1'b1;
            wr_seq[s].start(env.src_agent[s].seqr);
          end
        join_none
      end

      wait fork;

      if (env.mem.get_read_pending_count() < env.mem.get_response_reorder_depth())
        `uvm_error("RESP_REORDER",
          $sformatf("read response pool=%0d expected at least %0d",
                    env.mem.get_read_pending_count(), env.mem.get_response_reorder_depth()))

      if (env.mem.get_write_response_pending_count() < env.mem.get_response_reorder_depth())
        `uvm_error("RESP_REORDER",
          $sformatf("write response pool=%0d expected at least %0d",
                    env.mem.get_write_response_pending_count(), env.mem.get_response_reorder_depth()))

      env.mem.set_response_enable(1'b1);
      wait_scoreboard_drain(30000);

      expected_r_beats = 0;
      expected_w_beats = 0;

      for (int i = 0; i < NUM_REQ; i++) begin
        expected_r_beats += ar_seq[i].generated_beats;
        expected_w_beats += wr_seq[i].generated_beats;
      end

      if (env.sb.get_ar_checks() != (NUM_REQ * 24))
        `uvm_error("RESP_REORDER", "AR transaction count mismatch")

      if (env.sb.get_aw_checks() != (NUM_REQ * 12))
        `uvm_error("RESP_REORDER", "AW transaction count mismatch")

      if (env.sb.get_w_beat_checks() != expected_w_beats)
        `uvm_error("RESP_REORDER", "W beat count mismatch")

      if (env.sb.get_r_route_checks() != expected_r_beats)
        `uvm_error("RESP_REORDER", "R beat routing count mismatch")

      if (env.sb.get_r_burst_checks() != (NUM_REQ * 24))
        `uvm_error("RESP_REORDER", "R burst completion count mismatch")

      if (env.sb.get_b_route_checks() != (NUM_REQ * 12))
        `uvm_error("RESP_REORDER", "B routing count mismatch")

      if ((env.mem.get_read_response_count() != (NUM_REQ * 24)) ||
          (env.mem.get_write_response_count() != (NUM_REQ * 12)))
        `uvm_error("RESP_REORDER",
          $sformatf("response counts R=%0d B=%0d expected R=%0d B=%0d",
                    env.mem.get_read_response_count(), env.mem.get_write_response_count(),
                    NUM_REQ * 24, NUM_REQ * 12))

      if ((env.mem.get_read_reorder_count() == 0) || (env.mem.get_write_reorder_count() == 0))
        `uvm_error("RESP_REORDER",
          $sformatf("reordering across different IDs was not observed: R=%0d B=%0d",
                    env.mem.get_read_reorder_count(), env.mem.get_write_reorder_count()))

      if ((env.mem.get_read_slverr_count() == 0) || (env.mem.get_read_decerr_count() == 0) ||
          (env.mem.get_write_slverr_count() == 0) || (env.mem.get_write_decerr_count() == 0))
        `uvm_error("RESP_REORDER",
          $sformatf("both error classes were not injected: R_SLV=%0d R_DEC=%0d B_SLV=%0d B_DEC=%0d",
                    env.mem.get_read_slverr_count(), env.mem.get_read_decerr_count(),
                    env.mem.get_write_slverr_count(), env.mem.get_write_decerr_count()))

      if (env.sb.get_r_error_route_checks() <
          (env.mem.get_read_slverr_count() + env.mem.get_read_decerr_count()))
        `uvm_error("RESP_REORDER", "not every read error burst reached a source")

      if (env.sb.get_b_error_route_checks() !=
          (env.mem.get_write_slverr_count() + env.mem.get_write_decerr_count()))
        `uvm_error("RESP_REORDER", "write error response routing count mismatch")

      `uvm_info("RESP_REORDER",
        $sformatf("reordered R=%0d B=%0d; routed error beats R=%0d B=%0d",
                  env.mem.get_read_reorder_count(), env.mem.get_write_reorder_count(),
                  env.sb.get_r_error_route_checks(), env.sb.get_b_error_route_checks()),
        UVM_LOW)

      env.mem.set_response_reorder_enable(1'b0);
      ordered_r_start = env.mem.get_read_response_count();
      ordered_b_start = env.mem.get_write_response_count();

      for (int i = 0; i < NUM_REQ; i++) begin
        ordered_ar = qos_cr_ar_stream_seq::type_id::create(
          $sformatf("ordered_error_ar_%0d", i));
        ordered_ar.src      = i;
        ordered_ar.n_txn    = ORDERED_TXNS_PER_SOURCE;
        ordered_ar.idle_max = 0;
        ordered_ar.max_len  = 1;
        ordered_ar.same_id  = 1'b0;
        ordered_ar.randomize_sideband = 1'b1;
        ordered_ar.start(env.src_agent[i].seqr);

        ordered_wr = qos_cr_aw_w_stream_seq::type_id::create(
          $sformatf("ordered_error_wr_%0d", i));
        ordered_wr.src      = i;
        ordered_wr.n_txn    = ORDERED_TXNS_PER_SOURCE;
        ordered_wr.idle_max = 0;
        ordered_wr.max_len  = 1;
        ordered_wr.same_id  = 1'b0;
        ordered_wr.randomize_sideband = 1'b1;
        ordered_wr.start(env.src_agent[i].seqr);

        wait_scoreboard_drain(6000);
      end

      if ((env.mem.get_read_response_count() - ordered_r_start) !=
          (NUM_REQ * ORDERED_TXNS_PER_SOURCE))
        `uvm_error("RESP_ORDERED",
          $sformatf("ordered R responses=%0d expected=%0d",
                    env.mem.get_read_response_count() - ordered_r_start,
                    NUM_REQ * ORDERED_TXNS_PER_SOURCE))

      if ((env.mem.get_write_response_count() - ordered_b_start) !=
          (NUM_REQ * ORDERED_TXNS_PER_SOURCE))
        `uvm_error("RESP_ORDERED",
          $sformatf("ordered B responses=%0d expected=%0d",
                    env.mem.get_write_response_count() - ordered_b_start,
                    NUM_REQ * ORDERED_TXNS_PER_SOURCE))

      phase.drop_objection(this);
    endtask
  endclass
