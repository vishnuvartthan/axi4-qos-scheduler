  class qos_aw_order_full_recovery_test extends qos_base_test;
    `uvm_component_utils(qos_aw_order_full_recovery_test)

    localparam int unsigned AW_ORDER_DEPTH = 16;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      cfg.ready_pct = 100;
    endfunction

    task run_phase(uvm_phase phase);
      qos_aw_only_seq fill_seq[NUM_REQ];
      qos_aw_only_seq extra_seq;
      qos_w_only_seq  drain_seq[NUM_REQ];
      int unsigned cycles;
      int unsigned aw_checks_at_full;

      phase.raise_objection(this);
      program_weights(1, 1, 1, 1, 8'h40);

      for (int i = 0; i < NUM_REQ; i++) begin
        automatic int s = i;

        fork
          begin
            fill_seq[s] = qos_aw_only_seq::type_id::create($sformatf("aw_order_fill_%0d", s));
            fill_seq[s].src       = s;
            fill_seq[s].n_txn     = AW_ORDER_DEPTH / NUM_REQ;
            fill_seq[s].same_id   = 1'b1;
            fill_seq[s].fixed_id  = 4'h6;
            fill_seq[s].fixed_len = 0;
            fill_seq[s].start(env.src_agent[s].seqr);
          end
        join_none
      end

      wait fork;

      cycles = 0;
      while ((env.sb.get_aw_checks() < AW_ORDER_DEPTH) && (cycles < 500)) begin
        @(posedge cfg.vif.clk);
        cycles++;
      end

      if (env.sb.get_aw_checks() != AW_ORDER_DEPTH)
        `uvm_error("AW_ORDER_FULL",
          $sformatf("accepted AW count=%0d expected=%0d",
                    env.sb.get_aw_checks(), AW_ORDER_DEPTH))

      if (env.sb.get_master_aw_pending() != AW_ORDER_DEPTH)
        `uvm_error("AW_ORDER_FULL",
          $sformatf("AW order occupancy=%0d expected=%0d",
                    env.sb.get_master_aw_pending(), AW_ORDER_DEPTH))

      aw_checks_at_full = env.sb.get_aw_checks();

      extra_seq = qos_aw_only_seq::type_id::create("aw_order_blocked_extra");
      extra_seq.src       = 0;
      extra_seq.n_txn     = 1;
      extra_seq.same_id   = 1'b1;
      extra_seq.fixed_id  = 4'h6;
      extra_seq.fixed_len = 0;
      extra_seq.start(env.src_agent[0].seqr);

      repeat (8) @(posedge cfg.vif.clk);

      if (env.sb.get_aw_checks() != aw_checks_at_full)
        `uvm_error("AW_ORDER_FULL", "extra AW issued while the AW order FIFO was full")

      if (env.sb.get_source_aw_pending(0) != 1)
        `uvm_error("AW_ORDER_FULL",
          $sformatf("blocked source AW queue size=%0d expected=1",
                    env.sb.get_source_aw_pending(0)))

      for (int i = 0; i < NUM_REQ; i++) begin
        automatic int s = i;

        fork
          begin
            drain_seq[s] = qos_w_only_seq::type_id::create($sformatf("aw_order_drain_%0d", s));
            drain_seq[s].src       = s;
            drain_seq[s].n_txn     = (AW_ORDER_DEPTH / NUM_REQ) + ((s == 0) ? 1 : 0);
            drain_seq[s].fixed_len = 0;
            drain_seq[s].start(env.src_agent[s].seqr);
          end
        join_none
      end

      wait fork;
      wait_scoreboard_drain(5000);

      if (env.sb.get_aw_checks() != (AW_ORDER_DEPTH + 1))
        `uvm_error("AW_ORDER_FULL",
          $sformatf("AW checks after recovery=%0d expected=%0d",
                    env.sb.get_aw_checks(), AW_ORDER_DEPTH + 1))

      if (env.sb.get_w_beat_checks() != (AW_ORDER_DEPTH + 1))
        `uvm_error("AW_ORDER_FULL",
          $sformatf("W beat checks after recovery=%0d expected=%0d",
                    env.sb.get_w_beat_checks(), AW_ORDER_DEPTH + 1))

      if (env.sb.get_b_route_checks() != (AW_ORDER_DEPTH + 1))
        `uvm_error("AW_ORDER_FULL",
          $sformatf("B route checks after recovery=%0d expected=%0d",
                    env.sb.get_b_route_checks(), AW_ORDER_DEPTH + 1))

      phase.drop_objection(this);
    endtask
  endclass
