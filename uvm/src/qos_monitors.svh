  class qos_monitor_base extends uvm_component;
    `uvm_component_utils(qos_monitor_base)

    uvm_analysis_port #(qos_axi_item) ap;
    longint unsigned sample_cycle;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
      sample_cycle = 0;
    endfunction

    function void publish(qos_kind_e kind,
                          qos_side_e side,
                          int unsigned src,
                          bit [AXI_ID_W-1:0] id,
                          bit [M_AXI_ID_W-1:0] mid,
                          bit [AXI_ADDR_W-1:0] addr,
                          bit [AXI_LEN_W-1:0] len,
                          bit [AXI_DATA_W-1:0] data,
                          bit [AXI_STRB_W-1:0] strb,
                          bit last,
                          bit [1:0] resp);
      qos_axi_item tr;

      tr = qos_axi_item::type_id::create("tr");
      tr.kind         = kind;
      tr.side         = side;
      tr.src          = src;
      tr.id           = id;
      tr.mid          = mid;
      tr.addr         = addr;
      tr.len          = len;
      tr.data         = data;
      tr.strb         = strb;
      tr.last         = last;
      tr.resp         = resp;
      tr.sample_cycle = sample_cycle;
      ap.write(tr);
    endfunction

    function void publish_addr(qos_kind_e kind,
                               qos_side_e side,
                               int unsigned src,
                               bit [AXI_ID_W-1:0] id,
                               bit [M_AXI_ID_W-1:0] mid,
                               bit [AXI_ADDR_W-1:0] addr,
                               bit [AXI_LEN_W-1:0] len,
                               bit [AXI_SIZE_W-1:0] size,
                               bit [AXI_BURST_W-1:0] burst,
                               bit [AXI_LOCK_W-1:0] lock,
                               bit [AXI_CACHE_W-1:0] cache,
                               bit [AXI_PROT_W-1:0] prot,
                               bit [AXI_QOS_W-1:0] qos);
      qos_axi_item tr;

      tr = qos_axi_item::type_id::create("addr_tr");
      tr.kind         = kind;
      tr.side         = side;
      tr.src          = src;
      tr.id           = id;
      tr.mid          = mid;
      tr.addr         = addr;
      tr.len          = len;
      tr.size         = size;
      tr.burst        = burst;
      tr.lock         = lock;
      tr.cache        = cache;
      tr.prot         = prot;
      tr.qos          = qos;
      tr.sample_cycle = sample_cycle;
      ap.write(tr);
    endfunction
  endclass

  class qos_source_monitor extends qos_monitor_base;
    `uvm_component_utils(qos_source_monitor)

    virtual qos_axi_if.source_monitor_mp vif;
    int unsigned src_index;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      qos_cfg cfg;

      super.build_phase(phase);
      if (!uvm_config_db#(qos_cfg)::get(this, "", "cfg", cfg))
        `uvm_fatal("CFG", "qos_source_monitor cfg missing")

      vif       = cfg.vif;
      src_index = cfg.src_index;
    endfunction

    task run_phase(uvm_phase phase);
      forever begin
        @(vif.source_mon_cb);
        sample_cycle++;

        if (!vif.rst_n)
          continue;

        if (vif.source_mon_cb.S_AXI_ARVALID[src_index] &&
            vif.source_mon_cb.S_AXI_ARREADY[src_index])
          publish_addr(QOS_AR, QOS_SIDE_SRC, src_index,
                       vif.source_mon_cb.S_AXI_ARID[src_index], '0,
                       vif.source_mon_cb.S_AXI_ARADDR[src_index],
                       vif.source_mon_cb.S_AXI_ARLEN[src_index],
                       vif.source_mon_cb.S_AXI_ARSIZE[src_index],
                       vif.source_mon_cb.S_AXI_ARBURST[src_index],
                       vif.source_mon_cb.S_AXI_ARLOCK[src_index],
                       vif.source_mon_cb.S_AXI_ARCACHE[src_index],
                       vif.source_mon_cb.S_AXI_ARPROT[src_index],
                       vif.source_mon_cb.S_AXI_ARQOS[src_index]);

        if (vif.source_mon_cb.S_AXI_AWVALID[src_index] &&
            vif.source_mon_cb.S_AXI_AWREADY[src_index])
          publish_addr(QOS_AW, QOS_SIDE_SRC, src_index,
                       vif.source_mon_cb.S_AXI_AWID[src_index], '0,
                       vif.source_mon_cb.S_AXI_AWADDR[src_index],
                       vif.source_mon_cb.S_AXI_AWLEN[src_index],
                       vif.source_mon_cb.S_AXI_AWSIZE[src_index],
                       vif.source_mon_cb.S_AXI_AWBURST[src_index],
                       vif.source_mon_cb.S_AXI_AWLOCK[src_index],
                       vif.source_mon_cb.S_AXI_AWCACHE[src_index],
                       vif.source_mon_cb.S_AXI_AWPROT[src_index],
                       vif.source_mon_cb.S_AXI_AWQOS[src_index]);

        if (vif.source_mon_cb.S_AXI_WVALID[src_index] &&
            vif.source_mon_cb.S_AXI_WREADY[src_index])
          publish(QOS_W, QOS_SIDE_SRC, src_index, '0, '0, '0, '0,
                  vif.source_mon_cb.S_AXI_WDATA[src_index],
                  vif.source_mon_cb.S_AXI_WSTRB[src_index],
                  vif.source_mon_cb.S_AXI_WLAST[src_index], 2'b00);

        if (vif.source_mon_cb.S_AXI_RVALID[src_index] &&
            vif.source_mon_cb.S_AXI_RREADY[src_index])
          publish(QOS_R, QOS_SIDE_SRC, src_index,
                  vif.source_mon_cb.S_AXI_RID[src_index], '0, '0, '0,
                  vif.source_mon_cb.S_AXI_RDATA[src_index], '0,
                  vif.source_mon_cb.S_AXI_RLAST[src_index],
                  vif.source_mon_cb.S_AXI_RRESP[src_index]);

        if (vif.source_mon_cb.S_AXI_BVALID[src_index] &&
            vif.source_mon_cb.S_AXI_BREADY[src_index])
          publish(QOS_B, QOS_SIDE_SRC, src_index,
                  vif.source_mon_cb.S_AXI_BID[src_index], '0, '0, '0,
                  '0, '0, 1'b0,
                  vif.source_mon_cb.S_AXI_BRESP[src_index]);
      end
    endtask
  endclass

  class qos_csr_monitor extends qos_monitor_base;
    `uvm_component_utils(qos_csr_monitor)

    typedef struct {
      bit [31:0] data;
      bit [AXI_STRB_W-1:0] strb;
    } csr_write_data_t;

    typedef struct {
      bit [7:0] addr;
      bit [31:0] data;
      bit [AXI_STRB_W-1:0] strb;
    } csr_write_t;

    virtual qos_axi_if.csr_monitor_mp vif;
    bit [7:0] wr_addr_q[$];
    csr_write_data_t wr_data_q[$];
    csr_write_t wr_pending_q[$];
    bit [7:0] rd_addr_q[$];

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      qos_cfg cfg;

      super.build_phase(phase);
      if (!uvm_config_db#(qos_cfg)::get(this, "", "cfg", cfg))
        `uvm_fatal("CFG", "qos_csr_monitor cfg missing")

      vif = cfg.vif;
    endfunction

    function void clear_state();
      wr_addr_q.delete();
      wr_data_q.delete();
      wr_pending_q.delete();
      rd_addr_q.delete();
    endfunction

    task run_phase(uvm_phase phase);
      clear_state();

      forever begin
        bit [7:0] rd_addr;
        csr_write_data_t wr_data;
        csr_write_t wr;

        @(vif.csr_mon_cb);
        sample_cycle++;

        if (!vif.rst_n) begin
          clear_state();
          continue;
        end

        if (vif.csr_mon_cb.S_AXIL_AWVALID && vif.csr_mon_cb.S_AXIL_AWREADY)
          wr_addr_q.push_back(vif.csr_mon_cb.S_AXIL_AWADDR);

        if (vif.csr_mon_cb.S_AXIL_WVALID && vif.csr_mon_cb.S_AXIL_WREADY) begin
          wr_data.data = vif.csr_mon_cb.S_AXIL_WDATA;
          wr_data.strb = vif.csr_mon_cb.S_AXIL_WSTRB;
          wr_data_q.push_back(wr_data);
        end

        while ((wr_addr_q.size() != 0) && (wr_data_q.size() != 0)) begin
          wr.addr = wr_addr_q.pop_front();
          wr_data = wr_data_q.pop_front();
          wr.data = wr_data.data;
          wr.strb = wr_data.strb;
          wr_pending_q.push_back(wr);
        end

        // Publish a register write only after its ordered AXI-Lite response.
        if (vif.csr_mon_cb.S_AXIL_BVALID && vif.csr_mon_cb.S_AXIL_BREADY) begin
          if (wr_pending_q.size() == 0) begin
            `uvm_error("CSR_MON", "write response observed without an accepted write")
          end else begin
            wr = wr_pending_q.pop_front();
            publish(QOS_CSR_WR, QOS_SIDE_CSR, 0, '0, '0,
                    wr.addr, '0, wr.data, wr.strb, 1'b0,
                    vif.csr_mon_cb.S_AXIL_BRESP);
          end
        end

        if (vif.csr_mon_cb.S_AXIL_ARVALID && vif.csr_mon_cb.S_AXIL_ARREADY)
          rd_addr_q.push_back(vif.csr_mon_cb.S_AXIL_ARADDR);

        if (vif.csr_mon_cb.S_AXIL_RVALID && vif.csr_mon_cb.S_AXIL_RREADY) begin
          if (rd_addr_q.size() == 0) begin
            `uvm_error("CSR_MON", "read response observed without an accepted read")
          end else begin
            rd_addr = rd_addr_q.pop_front();
            publish(QOS_CSR_RD, QOS_SIDE_CSR, 0, '0, '0,
                    rd_addr, '0, vif.csr_mon_cb.S_AXIL_RDATA,
                    '0, 1'b0, vif.csr_mon_cb.S_AXIL_RRESP);
          end
        end
      end
    endtask
  endclass

  class qos_master_monitor extends qos_monitor_base;
    `uvm_component_utils(qos_master_monitor)

    virtual qos_axi_if.master_monitor_mp vif;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      qos_cfg cfg;

      super.build_phase(phase);
      if (!uvm_config_db#(qos_cfg)::get(this, "", "cfg", cfg))
        `uvm_fatal("CFG", "qos_master_monitor cfg missing")

      vif = cfg.vif;
    endfunction

    task run_phase(uvm_phase phase);
      int unsigned src;

      forever begin
        @(vif.master_mon_cb);
        sample_cycle++;

        if (!vif.rst_n)
          continue;

        if (vif.master_mon_cb.M_AXI_ARVALID && vif.master_mon_cb.M_AXI_ARREADY) begin
          src = vif.master_mon_cb.M_AXI_ARID[M_AXI_ID_W-1:AXI_ID_W];
          publish_addr(QOS_AR, QOS_SIDE_MST, src,
                       vif.master_mon_cb.M_AXI_ARID[AXI_ID_W-1:0],
                       vif.master_mon_cb.M_AXI_ARID,
                       vif.master_mon_cb.M_AXI_ARADDR,
                       vif.master_mon_cb.M_AXI_ARLEN,
                       vif.master_mon_cb.M_AXI_ARSIZE,
                       vif.master_mon_cb.M_AXI_ARBURST,
                       vif.master_mon_cb.M_AXI_ARLOCK,
                       vif.master_mon_cb.M_AXI_ARCACHE,
                       vif.master_mon_cb.M_AXI_ARPROT,
                       vif.master_mon_cb.M_AXI_ARQOS);
        end

        if (vif.master_mon_cb.M_AXI_AWVALID && vif.master_mon_cb.M_AXI_AWREADY) begin
          src = vif.master_mon_cb.M_AXI_AWID[M_AXI_ID_W-1:AXI_ID_W];
          publish_addr(QOS_AW, QOS_SIDE_MST, src,
                       vif.master_mon_cb.M_AXI_AWID[AXI_ID_W-1:0],
                       vif.master_mon_cb.M_AXI_AWID,
                       vif.master_mon_cb.M_AXI_AWADDR,
                       vif.master_mon_cb.M_AXI_AWLEN,
                       vif.master_mon_cb.M_AXI_AWSIZE,
                       vif.master_mon_cb.M_AXI_AWBURST,
                       vif.master_mon_cb.M_AXI_AWLOCK,
                       vif.master_mon_cb.M_AXI_AWCACHE,
                       vif.master_mon_cb.M_AXI_AWPROT,
                       vif.master_mon_cb.M_AXI_AWQOS);
        end

        if (vif.master_mon_cb.M_AXI_WVALID && vif.master_mon_cb.M_AXI_WREADY)
          publish(QOS_W, QOS_SIDE_MST, 0, '0, '0, '0, '0,
                  vif.master_mon_cb.M_AXI_WDATA,
                  vif.master_mon_cb.M_AXI_WSTRB,
                  vif.master_mon_cb.M_AXI_WLAST, 2'b00);

        if (vif.master_mon_cb.M_AXI_RVALID && vif.master_mon_cb.M_AXI_RREADY) begin
          src = vif.master_mon_cb.M_AXI_RID[M_AXI_ID_W-1:AXI_ID_W];
          publish(QOS_R, QOS_SIDE_MST, src,
                  vif.master_mon_cb.M_AXI_RID[AXI_ID_W-1:0],
                  vif.master_mon_cb.M_AXI_RID, '0, '0,
                  vif.master_mon_cb.M_AXI_RDATA, '0,
                  vif.master_mon_cb.M_AXI_RLAST,
                  vif.master_mon_cb.M_AXI_RRESP);
        end

        if (vif.master_mon_cb.M_AXI_BVALID && vif.master_mon_cb.M_AXI_BREADY) begin
          src = vif.master_mon_cb.M_AXI_BID[M_AXI_ID_W-1:AXI_ID_W];
          publish(QOS_B, QOS_SIDE_MST, src,
                  vif.master_mon_cb.M_AXI_BID[AXI_ID_W-1:0],
                  vif.master_mon_cb.M_AXI_BID, '0, '0,
                  '0, '0, 1'b0, vif.master_mon_cb.M_AXI_BRESP);
        end
      end
    endtask
  endclass

  // Analysis callbacks from separate monitors have no defined process order.
  // Buffering one clock lets the reference models see CSR updates first, then
  // source accepts, and finally the corresponding downstream transfers.
  class qos_event_collector extends uvm_component;
    `uvm_component_utils(qos_event_collector)

    virtual qos_axi_if vif;
    uvm_analysis_imp #(qos_axi_item, qos_event_collector) analysis_export;
    uvm_analysis_port #(qos_axi_item) ap;

    qos_axi_item pending_q[$];
    longint unsigned current_cycle;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      analysis_export = new("analysis_export", this);
      ap = new("ap", this);
      current_cycle = 0;
    endfunction

    function void build_phase(uvm_phase phase);
      qos_cfg cfg;

      super.build_phase(phase);
      if (!uvm_config_db#(qos_cfg)::get(this, "", "cfg", cfg))
        `uvm_fatal("CFG", "qos_event_collector cfg missing")

      vif = cfg.vif;
    endfunction

    function void write(qos_axi_item t);
      qos_axi_item copy;

      if (!$cast(copy, t.clone()))
        `uvm_fatal("EVENT_COPY", "failed to clone monitored transaction")

      pending_q.push_back(copy);
    endfunction

    function int side_rank(qos_side_e side);
      case (side)
        QOS_SIDE_CSR: return 0;
        QOS_SIDE_SRC: return 1;
        QOS_SIDE_MST: return 2;
        default:      return 3;
      endcase
    endfunction

    function bit comes_before(qos_axi_item lhs, qos_axi_item rhs);
      if (lhs.sample_cycle != rhs.sample_cycle)
        return (lhs.sample_cycle < rhs.sample_cycle);

      if (lhs.side != rhs.side)
        return (side_rank(lhs.side) < side_rank(rhs.side));

      if ((lhs.side == QOS_SIDE_SRC) && (lhs.src != rhs.src))
        return (lhs.src < rhs.src);

      return (lhs.kind < rhs.kind);
    endfunction

    function int next_ready_index();
      int selected;

      selected = -1;
      for (int i = 0; i < pending_q.size(); i++) begin
        if (pending_q[i].sample_cycle >= current_cycle)
          continue;

        if ((selected < 0) || comes_before(pending_q[i], pending_q[selected]))
          selected = i;
      end

      return selected;
    endfunction

    function void publish_ready();
      int selected;
      qos_axi_item tr;

      forever begin
        selected = next_ready_index();
        if (selected < 0)
          return;

        tr = pending_q[selected];
        pending_q.delete(selected);
        ap.write(tr);
      end
    endfunction

    function bit is_empty();
      return (pending_q.size() == 0);
    endfunction

    task run_phase(uvm_phase phase);
      forever begin
        @(posedge vif.clk);
        current_cycle++;

        if (!vif.rst_n)
          pending_q.delete();
        else
          publish_ready();
      end
    endtask
  endclass
