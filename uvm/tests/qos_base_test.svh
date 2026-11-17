  class qos_base_test extends uvm_test;
    `uvm_component_utils(qos_base_test)
    qos_env env;
    qos_cfg cfg;

    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      cfg = qos_cfg::type_id::create("cfg");
      if (!uvm_config_db#(virtual qos_axi_if)::get(this, "", "vif", cfg.vif)) `uvm_fatal("VIF", "virtual interface missing")
      cfg.ready_pct = 75;
      uvm_config_db#(qos_cfg)::set(this, "env", "cfg", cfg);
      env = qos_env::type_id::create("env", this);
    endfunction

    task csr_wr(bit [7:0] addr, bit [31:0] data, bit [3:0] strb = 4'hf);
      qos_csr_access_seq seq;
      seq = qos_csr_access_seq::type_id::create("csr_wr_seq");
      seq.write = 1'b1;
      seq.addr  = addr;
      seq.data  = data;
      seq.strb  = strb;
      seq.start(env.csr_agent.seqr);
    endtask

    task csr_rd(bit [7:0] addr, output bit [31:0] data);
      qos_csr_access_seq seq;
      seq = qos_csr_access_seq::type_id::create("csr_rd_seq");
      seq.write = 1'b0;
      seq.addr  = addr;
      seq.data  = '0;
      seq.start(env.csr_agent.seqr);
      data = seq.rdata;
    endtask

    task wait_scoreboard_drain(int unsigned max_cycles = 3000);
      int unsigned cycles;

      cycles = 0;

      // A sequence can return in the same clock slot that its final transfer
      // is observed. Give the monitors one clock to publish that transfer.
      @(posedge cfg.vif.clk);

      while ((!env.events.is_empty() || !env.sb.is_drained()) &&
             cycles < max_cycles) begin
        @(posedge cfg.vif.clk);
        cycles++;
      end

      if (!env.events.is_empty() || !env.sb.is_drained())
        `uvm_error("TEST_DRAIN", $sformatf("scoreboard did not drain after %0d cycles", max_cycles))
    endtask

    task program_weights(input int unsigned w0,
                         input int unsigned w1,
                         input int unsigned w2,
                         input int unsigned w3,
                         input int unsigned aging);
      csr_wr(8'h00, w0);
      csr_wr(8'h04, w1);
      csr_wr(8'h08, w2);
      csr_wr(8'h0c, w3);
      csr_wr(8'h10, aging);
    endtask

    task check_programmed_policy(input string tag,
                                 input int unsigned w0,
                                 input int unsigned w1,
                                 input int unsigned w2,
                                 input int unsigned w3,
                                 input int unsigned aging);
      bit [31:0] rdata;
      int unsigned expected_weight[NUM_REQ];

      expected_weight = '{w0, w1, w2, w3};

      for (int i = 0; i < NUM_REQ; i++) begin
        csr_rd(8'(i * 4), rdata);

        if (rdata[3:0] != expected_weight[i][3:0])
          `uvm_error("POLICY_READBACK",
            $sformatf("%s weight%0d readback=0x%0h expected=0x%0h",
                      tag, i, rdata[3:0], expected_weight[i][3:0]))
      end

      csr_rd(8'h10, rdata);

      if (rdata[7:0] != aging[7:0])
        `uvm_error("POLICY_READBACK",
          $sformatf("%s aging readback=0x%0h expected=0x%0h",
                    tag, rdata[7:0], aging[7:0]))
    endtask

  endclass
