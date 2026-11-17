  class qos_mid_transaction_reset_test extends qos_base_test;
    `uvm_component_utils(qos_mid_transaction_reset_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      cfg.ready_pct = 100;
    endfunction

    task check_reset_counters();
      bit [31:0] rdata;
      bit [7:0] counter_addr[6] = '{8'h30, 8'h34, 8'h38, 8'h3c, 8'h40, 8'h44};

      for (int i = 0; i < 6; i++) begin
        csr_rd(counter_addr[i], rdata);

        if (rdata != 0)
          `uvm_error("MID_RESET",
            $sformatf("counter 0x%0h did not reset: value=0x%0h",
                      counter_addr[i], rdata))
      end
    endtask

    task run_phase(uvm_phase phase);
      qos_cr_ar_stream_seq   outstanding_ar[NUM_REQ];
      qos_cr_aw_w_stream_seq outstanding_wr[NUM_REQ];
      qos_ar_stream_seq      stalled_ar[NUM_REQ];
      qos_aw_only_seq        stalled_aw[NUM_REQ];
      qos_cr_ar_stream_seq   recovery_ar[NUM_REQ];
      qos_cr_aw_w_stream_seq recovery_wr[NUM_REQ];
      bit [31:0] rdata;
      int unsigned reset_flush_start;
      int unsigned reset_drop_start;
      int unsigned mem_discard_start;
      int unsigned ar_start;
      int unsigned aw_start;
      int unsigned w_start;
      int unsigned r_start;
      int unsigned r_burst_start;
      int unsigned b_start;
      int unsigned expected_r_beats;
      int unsigned expected_w_beats;

      phase.raise_objection(this);

      env.mem.set_response_enable(1'b0);
      program_weights(9, 3, 5, 7, 8'h25);

      for (int i = 0; i < NUM_REQ; i++) begin
        automatic int s = i;

        fork
          begin
            outstanding_ar[s] =
              qos_cr_ar_stream_seq::type_id::create($sformatf("reset_outstanding_ar_%0d", s));
            outstanding_ar[s].src      = s;
            outstanding_ar[s].n_txn    = 8;
            outstanding_ar[s].idle_max = 2;
            outstanding_ar[s].max_len  = 3;
            outstanding_ar[s].start(env.src_agent[s].seqr);
          end

          begin
            outstanding_wr[s] =
              qos_cr_aw_w_stream_seq::type_id::create($sformatf("reset_outstanding_wr_%0d", s));
            outstanding_wr[s].src      = s;
            outstanding_wr[s].n_txn    = 4;
            outstanding_wr[s].idle_max = 2;
            outstanding_wr[s].max_len  = 3;
            outstanding_wr[s].start(env.src_agent[s].seqr);
          end
        join_none
      end

      wait fork;
      repeat (4) @(posedge cfg.vif.clk);

      if (env.mem.get_read_pending_count() == 0)
        `uvm_error("MID_RESET", "failed to establish outstanding read responses")

      if (env.mem.get_write_response_pending_count() == 0)
        `uvm_error("MID_RESET", "failed to establish outstanding write responses")

      env.mem.set_ready_pct(0);
      repeat (3) @(posedge cfg.vif.clk);

      for (int i = 0; i < NUM_REQ; i++) begin
        automatic int s = i;

        fork
          begin
            stalled_ar[s] =
              qos_ar_stream_seq::type_id::create($sformatf("reset_stalled_ar_%0d", s));
            stalled_ar[s].src      = s;
            stalled_ar[s].n_txn    = 4;
            stalled_ar[s].idle_max = 0;
            stalled_ar[s].max_len  = 0;
            stalled_ar[s].start(env.src_agent[s].seqr);
          end

          begin
            stalled_aw[s] =
              qos_aw_only_seq::type_id::create($sformatf("reset_stalled_aw_%0d", s));
            stalled_aw[s].src       = s;
            stalled_aw[s].n_txn     = 4;
            stalled_aw[s].idle_max  = 0;
            stalled_aw[s].fixed_len = 0;
            stalled_aw[s].start(env.src_agent[s].seqr);
          end
        join_none
      end

      wait fork;
      repeat (6) @(posedge cfg.vif.clk);

      if (!(cfg.vif.master_mon_cb.M_AXI_ARVALID &&
            !cfg.vif.master_mon_cb.M_AXI_ARREADY))
        `uvm_error("MID_RESET", "failed to establish stalled master AR")

      if (!(cfg.vif.master_mon_cb.M_AXI_AWVALID &&
            !cfg.vif.master_mon_cb.M_AXI_AWREADY))
        `uvm_error("MID_RESET", "failed to establish stalled master AW")

      if (env.sb.is_drained())
        `uvm_error("MID_RESET", "scoreboard was unexpectedly empty before reset")

      reset_flush_start = env.sb.get_reset_flush_count();
      reset_drop_start  = env.sb.get_reset_dropped_items();
      mem_discard_start = env.mem.get_reset_discarded_count();

      @(negedge cfg.vif.clk);
      cfg.vif.rst_n <= 1'b0;
      repeat (6) @(posedge cfg.vif.clk);

      if (cfg.vif.master_mon_cb.M_AXI_ARVALID !== 1'b0 ||
          cfg.vif.master_mon_cb.M_AXI_AWVALID !== 1'b0 ||
          cfg.vif.master_mon_cb.M_AXI_WVALID  !== 1'b0)
        `uvm_error("MID_RESET", "master request VALID remained asserted during reset")

      if (cfg.vif.source_mon_cb.S_AXI_RVALID !== '0 ||
          cfg.vif.source_mon_cb.S_AXI_BVALID !== '0)
        `uvm_error("MID_RESET", "source response VALID remained asserted during reset")

      if ((env.mem.get_read_pending_count() != 0) ||
          (env.mem.get_write_address_pending_count() != 0) ||
          (env.mem.get_write_response_pending_count() != 0))
        `uvm_error("MID_RESET", "memory model queues were not flushed by reset")

      if (!env.sb.is_drained())
        `uvm_error("MID_RESET", "scoreboard queues were not flushed by reset")

      @(negedge cfg.vif.clk);
      cfg.vif.rst_n <= 1'b1;
      repeat (4) @(posedge cfg.vif.clk);

      if (env.sb.get_reset_flush_count() != (reset_flush_start + 1))
        `uvm_error("MID_RESET",
          $sformatf("reset flush count=%0d expected=%0d",
                    env.sb.get_reset_flush_count(), reset_flush_start + 1))

      if (env.sb.get_reset_dropped_items() <= reset_drop_start)
        `uvm_error("MID_RESET", "reset did not discard any scoreboard state")

      if (env.mem.get_reset_discarded_count() <= mem_discard_start)
        `uvm_error("MID_RESET", "reset did not discard any outstanding memory response")

      check_programmed_policy("post_reset_defaults", 1, 1, 1, 1, 8'h10);
      check_reset_counters();
      csr_rd(8'h20, rdata);

      if ((rdata[NUM_REQ-1:0] != {NUM_REQ{1'b1}}) ||
          (rdata[(2*NUM_REQ)-1:NUM_REQ] != '0))
        `uvm_error("MID_RESET",
          $sformatf("FIFO status after reset=0x%0h expected empty=0x%0h full=0",
                    rdata, {NUM_REQ{1'b1}}))

      env.mem.set_ready_pct(75);
      env.mem.set_response_enable(1'b1);

      ar_start      = env.sb.get_ar_checks();
      aw_start      = env.sb.get_aw_checks();
      w_start       = env.sb.get_w_beat_checks();
      r_start       = env.sb.get_r_route_checks();
      r_burst_start = env.sb.get_r_burst_checks();
      b_start       = env.sb.get_b_route_checks();

      for (int i = 0; i < NUM_REQ; i++) begin
        automatic int s = i;

        fork
          begin
            recovery_ar[s] =
              qos_cr_ar_stream_seq::type_id::create($sformatf("reset_recovery_ar_%0d", s));
            recovery_ar[s].src      = s;
            recovery_ar[s].n_txn    = 8;
            recovery_ar[s].idle_max = 3;
            recovery_ar[s].max_len  = 7;
            recovery_ar[s].start(env.src_agent[s].seqr);
          end

          begin
            recovery_wr[s] =
              qos_cr_aw_w_stream_seq::type_id::create($sformatf("reset_recovery_wr_%0d", s));
            recovery_wr[s].src      = s;
            recovery_wr[s].n_txn    = 4;
            recovery_wr[s].idle_max = 3;
            recovery_wr[s].max_len  = 7;
            recovery_wr[s].start(env.src_agent[s].seqr);
          end
        join_none
      end

      wait fork;
      wait_scoreboard_drain(12000);

      expected_r_beats = 0;
      expected_w_beats = 0;

      for (int i = 0; i < NUM_REQ; i++) begin
        expected_r_beats += recovery_ar[i].generated_beats;
        expected_w_beats += recovery_wr[i].generated_beats;
      end

      if ((env.sb.get_ar_checks() - ar_start) != (NUM_REQ * 8))
        `uvm_error("MID_RESET", "AR transaction count mismatch after reset")

      if ((env.sb.get_aw_checks() - aw_start) != (NUM_REQ * 4))
        `uvm_error("MID_RESET", "AW transaction count mismatch after reset")

      if ((env.sb.get_w_beat_checks() - w_start) != expected_w_beats)
        `uvm_error("MID_RESET", "W beat count mismatch after reset")

      if ((env.sb.get_r_route_checks() - r_start) != expected_r_beats)
        `uvm_error("MID_RESET", "R beat count mismatch after reset")

      if ((env.sb.get_r_burst_checks() - r_burst_start) != (NUM_REQ * 8))
        `uvm_error("MID_RESET", "R burst count mismatch after reset")

      if ((env.sb.get_b_route_checks() - b_start) != (NUM_REQ * 4))
        `uvm_error("MID_RESET", "B transaction count mismatch after reset")

      phase.drop_objection(this);
    endtask
  endclass
