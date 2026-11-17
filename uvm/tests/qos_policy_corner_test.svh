  class qos_policy_corner_test extends qos_base_test;
    `uvm_component_utils(qos_policy_corner_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_policy_case(string tag,
                         int unsigned w0,
                         int unsigned w1,
                         int unsigned w2,
                         int unsigned w3,
                         int unsigned aging,
                         int unsigned ready_pct,
                         int unsigned n_ar,
                         int unsigned n_wr);
      qos_ar_stream_seq   ar_seq[NUM_REQ];
      qos_aw_w_stream_seq wr_seq[NUM_REQ];
      int unsigned ar_age_start;
      int unsigned aw_age_start;
      int unsigned ar_age_end;
      int unsigned aw_age_end;

      env.mem.set_ready_pct(ready_pct);

      program_weights(w0, w1, w2, w3, aging);
      check_programmed_policy(tag, w0, w1, w2, w3, aging);
      ar_age_start = 0;
      aw_age_start = 0;

      for (int i = 0; i < NUM_REQ; i++) begin
        ar_age_start += env.policy.get_ar_age_grants(i);
        aw_age_start += env.policy.get_aw_age_grants(i);
      end

      for (int i = 0; i < NUM_REQ; i++) begin
        automatic int s = i;

        fork
          begin
            ar_seq[s] = qos_ar_stream_seq::type_id::create($sformatf("%s_ar_%0d", tag, s));
            ar_seq[s].src      = s;
            ar_seq[s].n_txn    = n_ar;
            ar_seq[s].idle_max = 1;
            ar_seq[s].same_id  = 1'b1;
            ar_seq[s].fixed_id = s[3:0];
            ar_seq[s].start(env.src_agent[s].seqr);
          end

          begin
            wr_seq[s] = qos_aw_w_stream_seq::type_id::create($sformatf("%s_wr_%0d", tag, s));
            wr_seq[s].src      = s;
            wr_seq[s].n_txn    = n_wr;
            wr_seq[s].idle_max = 1;
            wr_seq[s].max_len  = 7;
            wr_seq[s].same_id  = 1'b1;
            wr_seq[s].fixed_id = s[3:0];
            wr_seq[s].start(env.src_agent[s].seqr);
          end
        join_none
      end

      wait fork;
      wait_scoreboard_drain(8000);

      ar_age_end = 0;
      aw_age_end = 0;

      for (int i = 0; i < NUM_REQ; i++) begin
        ar_age_end += env.policy.get_ar_age_grants(i);
        aw_age_end += env.policy.get_aw_age_grants(i);
      end

      if (ar_age_end == ar_age_start)
        `uvm_error("POLICY_CORNER",
          $sformatf("%s had no observed zero weight AR aging grant", tag))

      if (aw_age_end == aw_age_start)
        `uvm_error("POLICY_CORNER",
          $sformatf("%s had no observed zero weight AW aging grant", tag))
    endtask

    task run_aging_zero_case();
      qos_ar_stream_seq ar_seq;
      int unsigned grant_start;
      int unsigned age_start;
      int unsigned cycles;

      env.mem.set_ready_pct(100);
      program_weights(8, 0, 0, 0, 0);
      check_programmed_policy("zero_weight_age0", 8, 0, 0, 0, 0);

      grant_start = env.policy.get_ar_grants(1);
      age_start   = env.policy.get_ar_age_grants(1);

      ar_seq = qos_ar_stream_seq::type_id::create("zero_weight_age0_ar");
      ar_seq.src          = 1;
      ar_seq.n_txn        = 1;
      ar_seq.idle_max     = 0;
      ar_seq.same_id      = 1'b1;
      ar_seq.fixed_id     = 4'h1;
      ar_seq.fixed_len_en = 1'b1;
      ar_seq.fixed_len    = 0;
      ar_seq.start(env.src_agent[1].seqr);

      cycles = 0;
      while ((env.policy.get_ar_age_grants(1) == age_start) &&
             (cycles < 8)) begin
        @(posedge cfg.vif.clk);
        cycles++;
      end

      if (env.policy.get_ar_age_grants(1) == age_start)
        `uvm_error("POLICY_CORNER",
          "zero weight source was not served promptly with aging threshold zero")

      wait_scoreboard_drain(1000);

      if ((env.policy.get_ar_grants(1) - grant_start) != 1)
        `uvm_error("POLICY_CORNER", "aging threshold zero AR grant count mismatch")
    endtask

    task run_phase(uvm_phase phase);
      phase.raise_objection(this);

      run_aging_zero_case();
      run_policy_case("zero_weight_age1_r30", 0, 0, 0, 1,  1,  30, 96, 24);
      run_policy_case("zero_weight_age64",    8, 0, 0, 0, 64, 100,  4,  4);

      phase.drop_objection(this);
    endtask
  endclass
