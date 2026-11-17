  class qos_aging_override_test extends qos_base_test;
    `uvm_component_utils(qos_aging_override_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      cfg.ready_pct = 100;
    endfunction

    task run_phase(uvm_phase phase);
      qos_ar_stream_seq   ar_seq[NUM_REQ];
      qos_aw_w_stream_seq wr_seq[NUM_REQ];
      int unsigned ar_start[NUM_REQ];
      int unsigned aw_start[NUM_REQ];
      int unsigned ar_age_start[NUM_REQ];
      int unsigned aw_age_start[NUM_REQ];

      phase.raise_objection(this);
      program_weights(8, 0, 0, 0, 8);

      for (int i = 0; i < NUM_REQ; i++) begin
        ar_start[i]     = env.policy.get_ar_grants(i);
        ar_age_start[i] = env.policy.get_ar_age_grants(i);
      end

      for (int i = 0; i < NUM_REQ; i++) begin
        automatic int s = i;
        fork
          begin
            ar_seq[s] = qos_ar_stream_seq::type_id::create($sformatf("ar_aging_seq_%0d", s));
            ar_seq[s].src      = s;
            ar_seq[s].n_txn    = 96;
            ar_seq[s].idle_max = 0;
            ar_seq[s].start(env.src_agent[s].seqr);
          end
        join_none
      end

      wait fork;
      wait_scoreboard_drain(4000);

      for (int i = 0; i < NUM_REQ; i++) begin
        if ((env.policy.get_ar_grants(i) - ar_start[i]) != 96)
          `uvm_error("AGING",
            $sformatf("source %0d observed AR grants=%0d expected=96", i,
                      env.policy.get_ar_grants(i) - ar_start[i]))

        if ((i != 0) && (env.policy.get_ar_age_grants(i) == ar_age_start[i]))
          `uvm_error("AGING",
            $sformatf("zero weight source %0d had no observed AR aging grant", i))
      end

      for (int i = 0; i < NUM_REQ; i++) begin
        aw_start[i]     = env.policy.get_aw_grants(i);
        aw_age_start[i] = env.policy.get_aw_age_grants(i);
      end

      for (int i = 0; i < NUM_REQ; i++) begin
        automatic int s = i;
        fork
          begin
            wr_seq[s] = qos_aw_w_stream_seq::type_id::create($sformatf("aw_aging_seq_%0d", s));
            wr_seq[s].src      = s;
            wr_seq[s].n_txn    = 32;
            wr_seq[s].idle_max = 0;
            wr_seq[s].max_len  = 3;
            wr_seq[s].start(env.src_agent[s].seqr);
          end
        join_none
      end

      wait fork;
      wait_scoreboard_drain(6000);

      for (int i = 0; i < NUM_REQ; i++) begin
        if ((env.policy.get_aw_grants(i) - aw_start[i]) != 32)
          `uvm_error("AGING",
            $sformatf("source %0d observed AW grants=%0d expected=32", i,
                      env.policy.get_aw_grants(i) - aw_start[i]))

        if ((i != 0) && (env.policy.get_aw_age_grants(i) == aw_age_start[i]))
          `uvm_error("AGING",
            $sformatf("zero weight source %0d had no observed AW aging grant", i))
      end

      phase.drop_objection(this);
    endtask
  endclass
