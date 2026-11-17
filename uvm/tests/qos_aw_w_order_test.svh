  class qos_aw_w_order_test extends qos_base_test;
    `uvm_component_utils(qos_aw_w_order_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      int unsigned ready_pct;
      int unsigned bready_pct;

      super.build_phase(phase);

      if (!std::randomize(ready_pct, bready_pct) with {
            ready_pct  inside {[55:85]};
            bready_pct inside {[45:85]};
          })
        `uvm_fatal("AW_W_ORDER_CFG", "backpressure configuration randomization failed")

      cfg.ready_pct = ready_pct;
      cfg.source_resp_ready_randomize = 1'b1;
      cfg.rready_pct = 100;
      cfg.bready_pct = bready_pct;

      `uvm_info("AW_W_ORDER_CFG",
        $sformatf("downstream_ready=%0d%% source_bready=%0d%%",
                  cfg.ready_pct, cfg.bready_pct),
        UVM_LOW)
    endfunction

    task run_phase(uvm_phase phase);
      qos_cr_aw_w_stream_seq seq[NUM_REQ];
      bit [AXI_ID_W-1:0] shared_id;
      int unsigned expected_w_beats;

      phase.raise_objection(this);
      program_weights(1, 1, 1, 1, 8'h40);

      if (!std::randomize(shared_id))
        `uvm_fatal("AW_W_ORDER_CFG", "shared ID randomization failed")

      `uvm_info("AW_W_ORDER_CFG", $sformatf("shared_original_id=0x%0h", shared_id), UVM_LOW)

      fork
        for (int i = 0; i < NUM_REQ; i++) begin
          automatic int s = i;
          begin
            seq[s] = qos_cr_aw_w_stream_seq::type_id::create($sformatf("aw_w_seq_%0d", s));
            seq[s].src      = s;
            seq[s].n_txn    = 32;
            seq[s].idle_max = 8;
            seq[s].max_len  = 15;
            seq[s].same_id  = 1'b1;
            seq[s].fixed_id = shared_id;
            seq[s].start(env.src_agent[s].seqr);
          end
        end
      join

      wait_scoreboard_drain(12000);

      expected_w_beats = 0;
      for (int i = 0; i < NUM_REQ; i++)
        expected_w_beats += seq[i].generated_beats;

      if (env.sb.get_aw_checks() != (NUM_REQ * 32))
        `uvm_error("AW_W_ORDER",
          $sformatf("AW checks=%0d expected=%0d", env.sb.get_aw_checks(), NUM_REQ * 32))

      if (env.sb.get_w_beat_checks() != expected_w_beats)
        `uvm_error("AW_W_ORDER",
          $sformatf("W beat checks=%0d expected=%0d", env.sb.get_w_beat_checks(), expected_w_beats))

      if (env.sb.get_b_route_checks() != (NUM_REQ * 32))
        `uvm_error("AW_W_ORDER",
          $sformatf("B route checks=%0d expected=%0d", env.sb.get_b_route_checks(), NUM_REQ * 32))

      phase.drop_objection(this);
    endtask
  endclass
