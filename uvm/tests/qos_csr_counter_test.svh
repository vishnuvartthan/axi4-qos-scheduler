  class qos_csr_counter_test extends qos_base_test;
    `uvm_component_utils(qos_csr_counter_test)

    localparam int unsigned TXNS_PER_SOURCE = 260;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      cfg.ready_pct = 45;
    endfunction

    task run_phase(uvm_phase phase);
      qos_ar_stream_seq seq[NUM_REQ];
      bit [31:0] g[NUM_REQ];
      bit [31:0] stall;
      bit [31:0] invalid;
      bit [31:0] partial;
      int unsigned observed;

      phase.raise_objection(this);
      program_weights(1, 2, 4, 8, 8'h40);

      for (int i = 0; i < NUM_REQ; i++) begin
        automatic int s = i;
        fork
          begin
            seq[s] = qos_ar_stream_seq::type_id::create($sformatf("ar_counter_seq_%0d", s));
            seq[s].src      = s;
            seq[s].n_txn    = TXNS_PER_SOURCE;
            seq[s].idle_max = 1;
            seq[s].start(env.src_agent[s].seqr);
          end
        join_none
      end

      wait fork;
      wait_scoreboard_drain(12000);

      csr_rd(8'h30, g[0]);
      csr_rd(8'h34, g[1]);
      csr_rd(8'h38, g[2]);
      csr_rd(8'h3c, g[3]);
      csr_rd(8'h40, stall);

      for (int i = 0; i < NUM_REQ; i++) begin
        observed = env.policy.get_total_grants(i);

        if (g[i] != observed)
          `uvm_error("CSR_COUNTER",
            $sformatf("grant counter src%0d=%0d observed=%0d", i, g[i], observed))

        if (g[i] != TXNS_PER_SOURCE)
          `uvm_error("CSR_COUNTER_BOUNDARY",
            $sformatf("grant counter src%0d=%0d expected=%0d",
                      i, g[i], TXNS_PER_SOURCE))
      end

      if (stall == 0)
        `uvm_error("CSR_COUNTER", "stall counter stayed zero under low ready_pct")

      csr_wr(8'hfc, 32'hdead_beef);
      csr_rd(8'hfc, invalid);

      if (invalid != 0)
        `uvm_error("CSR_INVALID",
          $sformatf("invalid CSR read returned 0x%0h expected zero", invalid))

      csr_wr(8'h00, 32'h0000_000a, 4'b0010);
      csr_rd(8'h00, partial);

      if (partial[3:0] != 4'h1)
        `uvm_error("CSR_WSTRB",
          $sformatf("upper byte strobe changed weight0 to 0x%0h", partial[3:0]))

      csr_wr(8'h00, 32'h0000_000a, 4'b0001);
      csr_rd(8'h00, partial);

      if (partial[3:0] != 4'ha)
        `uvm_error("CSR_WSTRB",
          $sformatf("low byte strobe left weight0 at 0x%0h expected 0xa", partial[3:0]))

      csr_wr(8'h00, 32'h0000_0001, 4'b0001);
      check_programmed_policy("invalid_csr_write", 1, 2, 4, 8, 8'h40);

      phase.drop_objection(this);
    endtask
  endclass
