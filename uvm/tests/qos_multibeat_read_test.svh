  class qos_multibeat_read_test extends qos_base_test;
    `uvm_component_utils(qos_multibeat_read_test)

    localparam int unsigned TXNS_PER_SOURCE = 16;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      cfg.ready_pct = 65;
      cfg.source_resp_ready_randomize = 1'b1;
      cfg.rready_pct = 45;
    endfunction

    task run_phase(uvm_phase phase);
      qos_ar_stream_seq seq[NUM_REQ];
      int unsigned burst_len[NUM_REQ] = '{1, 3, 7, 15};
      int unsigned expected_bursts;
      int unsigned expected_beats;

      phase.raise_objection(this);
      program_weights(1, 2, 4, 8, 8'h40);

      expected_bursts = 0;
      expected_beats  = 0;

      for (int i = 0; i < NUM_REQ; i++) begin
        automatic int s = i;

        expected_bursts += TXNS_PER_SOURCE;
        expected_beats  += TXNS_PER_SOURCE * (burst_len[s] + 1);

        fork
          begin
            seq[s] = qos_ar_stream_seq::type_id::create($sformatf("multibeat_ar_%0d", s));
            seq[s].src          = s;
            seq[s].n_txn        = TXNS_PER_SOURCE;
            seq[s].idle_max     = 0;
            seq[s].same_id      = 1'b1;
            seq[s].fixed_id     = 4'h5;
            seq[s].fixed_len_en = 1'b1;
            seq[s].fixed_len    = burst_len[s];
            seq[s].start(env.src_agent[s].seqr);
          end
        join_none
      end

      wait fork;
      wait_scoreboard_drain(12000);

      if (env.sb.get_ar_checks() != expected_bursts)
        `uvm_error("MULTIBEAT_READ",
          $sformatf("AR checks=%0d expected=%0d", env.sb.get_ar_checks(), expected_bursts))

      if (env.sb.get_r_route_checks() != expected_beats)
        `uvm_error("MULTIBEAT_READ",
          $sformatf("R beat checks=%0d expected=%0d", env.sb.get_r_route_checks(), expected_beats))

      if (env.sb.get_r_burst_checks() != expected_bursts)
        `uvm_error("MULTIBEAT_READ",
          $sformatf("completed R bursts=%0d expected=%0d",
                    env.sb.get_r_burst_checks(), expected_bursts))

      phase.drop_objection(this);
    endtask
  endclass
