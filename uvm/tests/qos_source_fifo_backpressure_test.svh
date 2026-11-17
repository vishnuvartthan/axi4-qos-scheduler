  class qos_source_fifo_backpressure_test extends qos_base_test;
    `uvm_component_utils(qos_source_fifo_backpressure_test)

    localparam int unsigned STALL_TXN_COUNT = 11;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      cfg.ready_pct = 100;
    endfunction

    task run_phase(uvm_phase phase);
      qos_ar_stream_seq ar_seq[NUM_REQ];
      qos_aw_only_seq aw_seq[NUM_REQ];
      qos_w_only_seq  w_seq[NUM_REQ];
      bit [NUM_REQ-1:0] ar_stalled_mask;
      bit [NUM_REQ-1:0] aw_stalled_mask;

      phase.raise_objection(this);
      program_weights(1, 1, 1, 1, 8'h40);
      ar_stalled_mask = '0;
      aw_stalled_mask = '0;

      for (int i = 0; i < NUM_REQ; i++) begin
        automatic int s = i;
        int unsigned cycles;

        env.mem.set_ready_pct(0);
        repeat (3) @(posedge cfg.vif.clk);

        ar_seq[s] = qos_ar_stream_seq::type_id::create($sformatf("ar_backpressure_%0d", s));
        ar_seq[s].src      = s;
        ar_seq[s].n_txn    = STALL_TXN_COUNT;
        ar_seq[s].idle_max = 0;
        ar_seq[s].same_id  = 1'b1;
        ar_seq[s].fixed_id = s;

        fork
          ar_seq[s].start(env.src_agent[s].seqr);

          begin
            cycles = 0;

            while (!(cfg.vif.source_mon_cb.S_AXI_ARVALID[s] &&
                     !cfg.vif.source_mon_cb.S_AXI_ARREADY[s]) &&
                   cycles < 200) begin
              @(cfg.vif.source_mon_cb);
              cycles++;
            end

            if (cfg.vif.source_mon_cb.S_AXI_ARVALID[s] &&
                !cfg.vif.source_mon_cb.S_AXI_ARREADY[s]) begin
              ar_stalled_mask[s] = 1'b1;
              repeat (6) @(cfg.vif.source_mon_cb);
            end else begin
              `uvm_error("SRC_AR_BACKPRESSURE",
                $sformatf("source %0d did not reach AR backpressure", s))
            end

            env.mem.set_ready_pct(100);
          end
        join

        wait_scoreboard_drain(3000);
      end

      for (int i = 0; i < NUM_REQ; i++) begin
        automatic int s = i;
        int unsigned cycles;

        env.mem.set_ready_pct(0);
        repeat (3) @(posedge cfg.vif.clk);

        aw_seq[s] = qos_aw_only_seq::type_id::create($sformatf("aw_backpressure_%0d", s));
        aw_seq[s].src       = s;
        aw_seq[s].n_txn     = STALL_TXN_COUNT;
        aw_seq[s].same_id   = 1'b1;
        aw_seq[s].fixed_id  = s;
        aw_seq[s].fixed_len = 0;

        fork
          aw_seq[s].start(env.src_agent[s].seqr);

          begin
            cycles = 0;

            while (!(cfg.vif.source_mon_cb.S_AXI_AWVALID[s] &&
                     !cfg.vif.source_mon_cb.S_AXI_AWREADY[s]) &&
                   cycles < 200) begin
              @(cfg.vif.source_mon_cb);
              cycles++;
            end

            if (cfg.vif.source_mon_cb.S_AXI_AWVALID[s] &&
                !cfg.vif.source_mon_cb.S_AXI_AWREADY[s]) begin
              aw_stalled_mask[s] = 1'b1;
              repeat (6) @(cfg.vif.source_mon_cb);
            end else begin
              `uvm_error("SRC_AW_BACKPRESSURE",
                $sformatf("source %0d did not reach AW backpressure", s))
            end

            env.mem.set_ready_pct(100);
          end
        join

        w_seq[s] = qos_w_only_seq::type_id::create($sformatf("w_recovery_%0d", s));
        w_seq[s].src       = s;
        w_seq[s].n_txn     = STALL_TXN_COUNT;
        w_seq[s].fixed_len = 0;
        w_seq[s].start(env.src_agent[s].seqr);

        wait_scoreboard_drain(3000);
      end

      if (ar_stalled_mask != {NUM_REQ{1'b1}})
        `uvm_error("SRC_AR_BACKPRESSURE",
          $sformatf("not every source stalled: mask=0x%0h", ar_stalled_mask))

      if (aw_stalled_mask != {NUM_REQ{1'b1}})
        `uvm_error("SRC_AW_BACKPRESSURE",
          $sformatf("not every source stalled: mask=0x%0h", aw_stalled_mask))

      phase.drop_objection(this);
    endtask
  endclass
