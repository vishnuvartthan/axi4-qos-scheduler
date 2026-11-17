  class qos_policy_checker extends uvm_subscriber #(qos_axi_item);
    `uvm_component_utils(qos_policy_checker)

    typedef struct {
      longint unsigned cycle;
      int unsigned weight_version;
      int unsigned aging_version;
    } accepted_req_t;

    virtual qos_axi_if vif;

    int unsigned weight[NUM_REQ];
    int unsigned aging_threshold;
    int unsigned weight_version[NUM_REQ];
    int unsigned aging_version;

    accepted_req_t ar_req_q[NUM_REQ][$];
    accepted_req_t aw_req_q[NUM_REQ][$];
    int unsigned ar_grant_count[NUM_REQ];
    int unsigned aw_grant_count[NUM_REQ];
    int unsigned ar_age_grant_count[NUM_REQ];
    int unsigned aw_age_grant_count[NUM_REQ];

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      qos_cfg cfg;

      super.build_phase(phase);
      if (!uvm_config_db#(qos_cfg)::get(this, "", "cfg", cfg))
        `uvm_fatal("CFG", "qos_cfg missing")

      vif = cfg.vif;
      reset_model();
    endfunction

    task run_phase(uvm_phase phase);
      forever begin
        @(negedge vif.rst_n);
        reset_model();
      end
    endtask

    function void reset_model();
      aging_threshold = 8'h10;
      aging_version   = 0;

      for (int i = 0; i < NUM_REQ; i++) begin
        weight[i]             = 1;
        weight_version[i]     = 0;
        ar_req_q[i].delete();
        aw_req_q[i].delete();
        ar_grant_count[i]     = 0;
        aw_grant_count[i]     = 0;
        ar_age_grant_count[i] = 0;
        aw_age_grant_count[i] = 0;
      end
    endfunction

    function void write(qos_axi_item t);
      if ((t.side == QOS_SIDE_CSR) && (t.kind == QOS_CSR_WR)) begin
        if (t.strb[0]) begin
          case (t.addr[7:0])
            8'h00: begin weight[0] = t.data[3:0]; weight_version[0]++; end
            8'h04: begin weight[1] = t.data[3:0]; weight_version[1]++; end
            8'h08: begin weight[2] = t.data[3:0]; weight_version[2]++; end
            8'h0c: begin weight[3] = t.data[3:0]; weight_version[3]++; end
            8'h10: begin aging_threshold = t.data[7:0]; aging_version++; end
            default: ;
          endcase
        end
        return;
      end

      if ((t.kind != QOS_AR) && (t.kind != QOS_AW))
        return;

      if (t.src >= NUM_REQ) begin
        `uvm_error("POLICY_SRC",
          $sformatf("observed %s with invalid source %0d",
                    t.kind.name(), t.src))
        return;
      end

      if (t.side == QOS_SIDE_SRC) begin
        accepted_req_t req;

        req.cycle          = t.sample_cycle;
        req.weight_version = weight_version[t.src];
        req.aging_version  = aging_version;

        if (t.kind == QOS_AR)
          ar_req_q[t.src].push_back(req);
        else
          aw_req_q[t.src].push_back(req);
        return;
      end

      if (t.side != QOS_SIDE_MST)
        return;

      if (t.kind == QOS_AR) begin
        accepted_req_t req;

        if (ar_req_q[t.src].size() == 0) begin
          `uvm_error("POLICY_AR",
            $sformatf("master AR grant for source %0d had no accepted source request", t.src))
        end else begin
          req = ar_req_q[t.src].pop_front();

          if ((weight[t.src] == 0) &&
              (req.weight_version == weight_version[t.src])) begin
            ar_age_grant_count[t.src]++;
            check_age_latency("AR", t.src, req, t.sample_cycle);
          end
        end

        ar_grant_count[t.src]++;
      end else begin
        accepted_req_t req;

        if (aw_req_q[t.src].size() == 0) begin
          `uvm_error("POLICY_AW",
            $sformatf("master AW grant for source %0d had no accepted source request", t.src))
        end else begin
          req = aw_req_q[t.src].pop_front();

          if ((weight[t.src] == 0) &&
              (req.weight_version == weight_version[t.src])) begin
            aw_age_grant_count[t.src]++;
            check_age_latency("AW", t.src, req, t.sample_cycle);
          end
        end

        aw_grant_count[t.src]++;
      end
    endfunction

    function void check_age_latency(string channel,
                                    int unsigned src,
                                    accepted_req_t req,
                                    longint unsigned grant_cycle);
      longint unsigned wait_cycles;

      // WRR excludes a source while its weight is zero, so this grant proves
      // that aging supplied the selection. A changing threshold is still a
      // valid aging grant, but it is not suitable for a threshold timing check.
      if (req.aging_version != aging_version)
        return;

      wait_cycles = grant_cycle - req.cycle;
      if (wait_cycles < aging_threshold)
        `uvm_error("POLICY_AGING",
          $sformatf("zero weight %s source %0d granted after %0d cycles, threshold=%0d",
                    channel, src, wait_cycles, aging_threshold))
    endfunction

    function int unsigned get_ar_grants(int unsigned src);
      return (src < NUM_REQ) ? ar_grant_count[src] : 0;
    endfunction

    function int unsigned get_aw_grants(int unsigned src);
      return (src < NUM_REQ) ? aw_grant_count[src] : 0;
    endfunction

    function int unsigned get_total_grants(int unsigned src);
      return get_ar_grants(src) + get_aw_grants(src);
    endfunction

    function int unsigned get_ar_age_grants(int unsigned src);
      return (src < NUM_REQ) ? ar_age_grant_count[src] : 0;
    endfunction

    function int unsigned get_aw_age_grants(int unsigned src);
      return (src < NUM_REQ) ? aw_age_grant_count[src] : 0;
    endfunction

    function int unsigned get_total_age_grants(int unsigned src);
      return get_ar_age_grants(src) + get_aw_age_grants(src);
    endfunction

    function void report_phase(uvm_phase phase);
      string summary;

      super.report_phase(phase);
      summary = $sformatf("policy=%0d:%0d:%0d:%0d aging=%0d; observed grants",
                          weight[0], weight[1], weight[2], weight[3],
                          aging_threshold);
      for (int i = 0; i < NUM_REQ; i++) begin
        summary = {summary,
          $sformatf(" src%0d=%0d(ar=%0d aw=%0d age=%0d)",
                    i, get_total_grants(i), get_ar_grants(i), get_aw_grants(i),
                    get_total_age_grants(i))};
      end

      `uvm_info("POLICY_SUMMARY", summary, UVM_LOW)
    endfunction
  endclass
