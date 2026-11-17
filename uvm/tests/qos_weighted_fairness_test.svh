  class qos_weighted_fairness_test extends qos_base_test;
    `uvm_component_utils(qos_weighted_fairness_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      cfg.ready_pct = 100;
    endfunction

    task run_phase(uvm_phase phase);
      qos_ar_stream_seq seq[NUM_REQ];
      int unsigned start_count[NUM_REQ];
      int unsigned g[NUM_REQ];
      int unsigned total;
      int unsigned exp;
      int unsigned diff;
      int unsigned weights[NUM_REQ] = '{1, 2, 4, 8};

      phase.raise_objection(this);
      program_weights(1, 2, 4, 8, 8'hff);
      env.sb.set_allow_pending_ar(1'b1);

      for (int i = 0; i < NUM_REQ; i++)
        start_count[i] = env.policy.get_ar_grants(i);

      for (int i = 0; i < NUM_REQ; i++) begin
        automatic int s = i;
        fork
          begin
            seq[s] = qos_ar_stream_seq::type_id::create($sformatf("ar_fair_seq_%0d", s));
            seq[s].src      = s;
            seq[s].n_txn    = 768;
            seq[s].idle_max = 0;
            seq[s].start(env.src_agent[s].seqr);
          end
        join_none
      end

      repeat (900) @(posedge cfg.vif.clk);

      for (int i = 0; i < NUM_REQ; i++)
        g[i] = env.policy.get_ar_grants(i) - start_count[i];

      total = g[0] + g[1] + g[2] + g[3];

      if (total < 200)
        `uvm_error("FAIRNESS", $sformatf("not enough grants sampled: total=%0d", total))

      for (int i = 0; i < NUM_REQ; i++) begin
        exp  = (total * weights[i]) / 15;
        diff = (g[i] > exp) ? (g[i] - exp) : (exp - g[i]);

        if (diff > ((total / 20) + 8))
          `uvm_error("FAIRNESS",
            $sformatf("src%0d grants=%0d expected_approx=%0d total=%0d", i, g[i], exp, total))
      end


      phase.drop_objection(this);
    endtask
  endclass
