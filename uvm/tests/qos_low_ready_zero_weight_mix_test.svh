  class qos_low_ready_zero_weight_mix_test extends qos_base_test;
    `uvm_component_utils(qos_low_ready_zero_weight_mix_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      cfg.ready_pct = 35;
      cfg.source_resp_ready_randomize = 1;
      cfg.rready_pct = 35;
      cfg.bready_pct = 30;
    endfunction

    task run_phase(uvm_phase phase);
      qos_ar_stream_seq   ar_seq[NUM_REQ];
      qos_aw_w_stream_seq wr_seq[NUM_REQ];

      bit [31:0] stall;
      int unsigned grant_start[NUM_REQ];
      int unsigned age_start[NUM_REQ];

      phase.raise_objection(this);

      program_weights(0, 3, 0, 12, 4);
      check_programmed_policy("low_ready", 0, 3, 0, 12, 4);

      for (int i = 0; i < NUM_REQ; i++) begin
        grant_start[i] = env.policy.get_total_grants(i);
        age_start[i]   = env.policy.get_total_age_grants(i);
      end

      for (int i = 0; i < NUM_REQ; i++) begin
        automatic int s = i;

        fork
          begin
            ar_seq[s] = qos_ar_stream_seq::type_id::create($sformatf("low_ready_ar_%0d", s));
            ar_seq[s].src      = s;
            ar_seq[s].n_txn    = 160;
            ar_seq[s].idle_max = 0;
            ar_seq[s].same_id  = 1'b1;
            ar_seq[s].fixed_id = s[3:0];
            ar_seq[s].start(env.src_agent[s].seqr);
          end

          begin
            wr_seq[s] = qos_aw_w_stream_seq::type_id::create($sformatf("low_ready_wr_%0d", s));
            wr_seq[s].src      = s;
            wr_seq[s].n_txn    = 48;
            wr_seq[s].idle_max = 0;
            wr_seq[s].max_len  = 15;
            wr_seq[s].same_id  = 1'b1;
            wr_seq[s].fixed_id = s[3:0];
            wr_seq[s].start(env.src_agent[s].seqr);
          end
        join_none
      end

      wait fork;
      wait_scoreboard_drain(12000);

      csr_rd(8'h40, stall);

      if (stall == 0)
        `uvm_error("LOW_READY_ZERO_WEIGHT", "stall counter stayed zero")

      for (int i = 0; i < NUM_REQ; i++) begin
        if ((env.policy.get_total_grants(i) - grant_start[i]) != 208)
          `uvm_error("LOW_READY_ZERO_WEIGHT",
            $sformatf("source %0d observed grants=%0d expected=208", i,
                      env.policy.get_total_grants(i) - grant_start[i]))

        if (((i == 0) || (i == 2)) &&
            (env.policy.get_total_age_grants(i) == age_start[i]))
          `uvm_error("LOW_READY_ZERO_WEIGHT",
            $sformatf("zero weight source %0d had no observed aging grant", i))
      end

      phase.drop_objection(this);
    endtask
  endclass
