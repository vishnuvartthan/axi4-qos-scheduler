  class qos_env extends uvm_env;
    `uvm_component_utils(qos_env)
    qos_source_agent src_agent[NUM_REQ];
    qos_csr_agent csr_agent;
    qos_master_agent master_agent;
    qos_mem_model mem;
    qos_event_collector events;
    qos_scoreboard sb;
    qos_policy_checker policy;
    qos_cov cov;
    qos_cfg base_cfg;

    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(qos_cfg)::get(this, "", "cfg", base_cfg)) `uvm_fatal("CFG", "env cfg missing")

      for (int i = 0; i < NUM_REQ; i++) begin
        qos_cfg c = qos_cfg::type_id::create($sformatf("src_cfg_%0d", i));
        c.vif = base_cfg.vif;
        c.src_index = i;
        c.ready_pct = base_cfg.ready_pct;
        c.source_resp_ready_randomize = base_cfg.source_resp_ready_randomize;
        c.rready_pct = base_cfg.rready_pct;
        c.bready_pct = base_cfg.bready_pct;
        c.is_active = base_cfg.is_active;
        uvm_config_db#(qos_cfg)::set(this, $sformatf("src_agent[%0d]", i), "cfg", c);
        src_agent[i] = qos_source_agent::type_id::create($sformatf("src_agent[%0d]", i), this);
      end

      uvm_config_db#(qos_cfg)::set(this, "csr_agent", "cfg", base_cfg);
      uvm_config_db#(qos_cfg)::set(this, "master_agent", "cfg", base_cfg);
      uvm_config_db#(qos_cfg)::set(this, "mem", "cfg", base_cfg);
      uvm_config_db#(qos_cfg)::set(this, "events", "cfg", base_cfg);
      uvm_config_db#(qos_cfg)::set(this, "sb", "cfg", base_cfg);
      uvm_config_db#(qos_cfg)::set(this, "policy", "cfg", base_cfg);
      uvm_config_db#(qos_cfg)::set(this, "cov", "cfg", base_cfg);
      csr_agent = qos_csr_agent::type_id::create("csr_agent", this);
      master_agent = qos_master_agent::type_id::create("master_agent", this);
      mem = qos_mem_model::type_id::create("mem", this);
      events = qos_event_collector::type_id::create("events", this);
      sb  = qos_scoreboard::type_id::create("sb", this);
      policy = qos_policy_checker::type_id::create("policy", this);
      cov = qos_cov::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);

      for (int i = 0; i < NUM_REQ; i++)
        src_agent[i].ap.connect(events.analysis_export);

      csr_agent.ap.connect(events.analysis_export);
      master_agent.ap.connect(events.analysis_export);

      events.ap.connect(sb.mon_imp);
      events.ap.connect(policy.analysis_export);
      events.ap.connect(cov.analysis_export);
    endfunction
  endclass
