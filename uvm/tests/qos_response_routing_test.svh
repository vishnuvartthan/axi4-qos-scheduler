  class qos_response_routing_test extends qos_base_test;
    `uvm_component_utils(qos_response_routing_test)

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
            rready_pct inside {[40:80]};
            bready_pct inside {[40:80]};
          })
        `uvm_fatal("ROUTE_CR_CFG", "backpressure configuration randomization failed")

      cfg.ready_pct = ready_pct;
      cfg.source_resp_ready_randomize = 1'b1;
      cfg.rready_pct = rready_pct;
      cfg.bready_pct = bready_pct;

      `uvm_info("ROUTE_CR_CFG",
        $sformatf("downstream_ready=%0d%% source_rready=%0d%% source_bready=%0d%%",
                  cfg.ready_pct, cfg.rready_pct, cfg.bready_pct),
        UVM_LOW)
    endfunction

    task run_phase(uvm_phase phase);
      qos_cr_ar_stream_seq   ar_seq[NUM_REQ];
      qos_cr_aw_w_stream_seq wr_seq[NUM_REQ];
      bit [AXI_ID_W-1:0] shared_id;
      int unsigned expected_r_beats;
      int unsigned expected_w_beats;

      phase.raise_objection(this);
      program_weights(1, 2, 4, 8, 8'h40);

      if (!std::randomize(shared_id))
        `uvm_fatal("ROUTE_CR_CFG", "shared ID randomization failed")

      `uvm_info("ROUTE_CR_CFG", $sformatf("shared_original_id=0x%0h", shared_id), UVM_LOW)

      for (int i = 0; i < NUM_REQ; i++) begin
        automatic int s = i;
        fork
          begin
            ar_seq[s] = qos_cr_ar_stream_seq::type_id::create($sformatf("ar_seq_%0d", s));
            ar_seq[s].src      = s;
            ar_seq[s].n_txn    = 48;
            ar_seq[s].idle_max = 8;
            ar_seq[s].max_len  = 15;
            ar_seq[s].same_id  = 1'b1;
            ar_seq[s].fixed_id = shared_id;
            ar_seq[s].start(env.src_agent[s].seqr);
          end
        join_none
      end

      for (int i = 0; i < NUM_REQ; i++) begin
        automatic int s = i;
        fork
          begin
            wr_seq[s] = qos_cr_aw_w_stream_seq::type_id::create($sformatf("wr_seq_%0d", s));
            wr_seq[s].src      = s;
            wr_seq[s].n_txn    = 24;
            wr_seq[s].idle_max = 8;
            wr_seq[s].max_len  = 15;
            wr_seq[s].same_id  = 1'b1;
            wr_seq[s].fixed_id = shared_id;
            wr_seq[s].start(env.src_agent[s].seqr);
          end
        join_none
      end

      wait fork;

      wait_scoreboard_drain(16000);

      expected_r_beats = 0;
      expected_w_beats = 0;

      for (int i = 0; i < NUM_REQ; i++) begin
        expected_r_beats += ar_seq[i].generated_beats;
        expected_w_beats += wr_seq[i].generated_beats;
      end

      if (env.sb.get_ar_checks() != (NUM_REQ * 48))
        `uvm_error("ROUTE_CR",
          $sformatf("AR checks=%0d expected=%0d", env.sb.get_ar_checks(), NUM_REQ * 48))

      if (env.sb.get_aw_checks() != (NUM_REQ * 24))
        `uvm_error("ROUTE_CR",
          $sformatf("AW checks=%0d expected=%0d", env.sb.get_aw_checks(), NUM_REQ * 24))

      if (env.sb.get_r_route_checks() != expected_r_beats)
        `uvm_error("ROUTE_CR",
          $sformatf("R beat checks=%0d expected=%0d", env.sb.get_r_route_checks(), expected_r_beats))

      if (env.sb.get_r_burst_checks() != (NUM_REQ * 48))
        `uvm_error("ROUTE_CR",
          $sformatf("R burst checks=%0d expected=%0d", env.sb.get_r_burst_checks(), NUM_REQ * 48))

      if (env.sb.get_w_beat_checks() != expected_w_beats)
        `uvm_error("ROUTE_CR",
          $sformatf("W beat checks=%0d expected=%0d", env.sb.get_w_beat_checks(), expected_w_beats))

      if (env.sb.get_b_route_checks() != (NUM_REQ * 24))
        `uvm_error("ROUTE_CR",
          $sformatf("B route checks=%0d expected=%0d", env.sb.get_b_route_checks(), NUM_REQ * 24))

      phase.drop_objection(this);
    endtask
  endclass
