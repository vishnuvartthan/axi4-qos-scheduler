  class qos_source_sequencer extends uvm_sequencer #(qos_axi_item);
    `uvm_component_utils(qos_source_sequencer)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
  endclass

  class qos_source_driver extends uvm_driver #(qos_axi_item);
    `uvm_component_utils(qos_source_driver)
    virtual qos_axi_if.source_driver_mp vif;
    int unsigned src_index;
    bit source_resp_ready_randomize;
    int unsigned rready_pct;
    int unsigned bready_pct;
    time drive_slot_time;
    bit drive_slot_valid;

    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    function void build_phase(uvm_phase phase);
      qos_cfg cfg;
      super.build_phase(phase);
      if (!uvm_config_db#(qos_cfg)::get(this, "", "cfg", cfg)) `uvm_fatal("CFG", "qos_cfg missing")
      vif = cfg.vif;
      src_index = cfg.src_index;
      source_resp_ready_randomize = cfg.source_resp_ready_randomize;
      rready_pct = cfg.rready_pct;
      bready_pct = cfg.bready_pct;
    endfunction

    task run_phase(uvm_phase phase);
      qos_axi_item tr;
      drive_idle();
      drive_slot_valid = 1'b0;
      wait(vif.rst_n === 1'b1);
      wait_drive_slot();

      fork
        response_ready_loop();
      join_none

      forever begin
        seq_item_port.get_next_item(tr);
        repeat (tr.idle_cycles) wait_drive_slot();
        case (tr.kind)
          QOS_AR: drive_ar(tr);
          QOS_AW: drive_aw(tr);
          QOS_W : drive_w(tr);
          default: `uvm_error("SRC_DRV", $sformatf("Unsupported source item kind %0d", tr.kind))
        endcase
        seq_item_port.item_done();
      end
    endtask

    task wait_drive_slot();
      @(vif.source_drv_cb);
      drive_slot_time  = $time;
      drive_slot_valid = 1'b1;
    endtask

    task align_to_drive_slot();
      if (!drive_slot_valid || ($time != drive_slot_time))
        wait_drive_slot();
    endtask

    task drive_idle();
      vif.source_drv_cb.S_AXI_ARVALID[src_index] <= 1'b0;
      vif.source_drv_cb.S_AXI_AWVALID[src_index] <= 1'b0;
      vif.source_drv_cb.S_AXI_WVALID[src_index]  <= 1'b0;
      vif.source_drv_cb.S_AXI_RREADY[src_index]  <= 1'b1;
      vif.source_drv_cb.S_AXI_BREADY[src_index]  <= 1'b1;
      vif.source_drv_cb.S_AXI_WLAST[src_index]   <= 1'b0;
    endtask

    task drive_ar(qos_axi_item tr);
      align_to_drive_slot();
      vif.source_drv_cb.S_AXI_ARID[src_index]    <= tr.id;
      vif.source_drv_cb.S_AXI_ARADDR[src_index]  <= tr.addr;
      vif.source_drv_cb.S_AXI_ARLEN[src_index]   <= tr.len;
      vif.source_drv_cb.S_AXI_ARSIZE[src_index]  <= tr.size;
      vif.source_drv_cb.S_AXI_ARBURST[src_index] <= tr.burst;
      vif.source_drv_cb.S_AXI_ARLOCK[src_index]  <= tr.lock;
      vif.source_drv_cb.S_AXI_ARCACHE[src_index] <= tr.cache;
      vif.source_drv_cb.S_AXI_ARPROT[src_index]  <= tr.prot;
      vif.source_drv_cb.S_AXI_ARQOS[src_index]   <= tr.qos;
      vif.source_drv_cb.S_AXI_ARVALID[src_index] <= 1'b1;
      do wait_drive_slot();
      while (vif.rst_n && !vif.source_drv_cb.S_AXI_ARREADY[src_index]);
      vif.source_drv_cb.S_AXI_ARVALID[src_index] <= 1'b0;
    endtask

    task drive_aw(qos_axi_item tr);
      align_to_drive_slot();
      vif.source_drv_cb.S_AXI_AWID[src_index]    <= tr.id;
      vif.source_drv_cb.S_AXI_AWADDR[src_index]  <= tr.addr;
      vif.source_drv_cb.S_AXI_AWLEN[src_index]   <= tr.len;
      vif.source_drv_cb.S_AXI_AWSIZE[src_index]  <= tr.size;
      vif.source_drv_cb.S_AXI_AWBURST[src_index] <= tr.burst;
      vif.source_drv_cb.S_AXI_AWLOCK[src_index]  <= tr.lock;
      vif.source_drv_cb.S_AXI_AWCACHE[src_index] <= tr.cache;
      vif.source_drv_cb.S_AXI_AWPROT[src_index]  <= tr.prot;
      vif.source_drv_cb.S_AXI_AWQOS[src_index]   <= tr.qos;
      vif.source_drv_cb.S_AXI_AWVALID[src_index] <= 1'b1;
      do wait_drive_slot();
      while (vif.rst_n && !vif.source_drv_cb.S_AXI_AWREADY[src_index]);
      vif.source_drv_cb.S_AXI_AWVALID[src_index] <= 1'b0;
    endtask

    task drive_w(qos_axi_item tr);
      align_to_drive_slot();
      vif.source_drv_cb.S_AXI_WDATA[src_index]   <= tr.data;
      vif.source_drv_cb.S_AXI_WSTRB[src_index]   <= tr.strb;
      vif.source_drv_cb.S_AXI_WLAST[src_index]   <= tr.last;
      vif.source_drv_cb.S_AXI_WVALID[src_index]  <= 1'b1;
      do wait_drive_slot();
      while (vif.rst_n && !vif.source_drv_cb.S_AXI_WREADY[src_index]);
      vif.source_drv_cb.S_AXI_WVALID[src_index]  <= 1'b0;
      vif.source_drv_cb.S_AXI_WLAST[src_index]   <= 1'b0;
    endtask

    task response_ready_loop();
      forever begin
        @(vif.source_drv_cb);

        if (!vif.rst_n) begin
          vif.source_drv_cb.S_AXI_RREADY[src_index] <= 1'b0;
          vif.source_drv_cb.S_AXI_BREADY[src_index] <= 1'b0;
        end else if (source_resp_ready_randomize) begin
          vif.source_drv_cb.S_AXI_RREADY[src_index] <= ($urandom_range(0,99) < rready_pct);
          vif.source_drv_cb.S_AXI_BREADY[src_index] <= ($urandom_range(0,99) < bready_pct);
        end else begin
          vif.source_drv_cb.S_AXI_RREADY[src_index] <= 1'b1;
          vif.source_drv_cb.S_AXI_BREADY[src_index] <= 1'b1;
        end
      end
    endtask

  endclass


  class qos_source_agent extends uvm_agent;
    `uvm_component_utils(qos_source_agent)
    qos_source_sequencer seqr;
    qos_source_driver drv;
    qos_source_monitor mon;
    uvm_analysis_port #(qos_axi_item) ap;
    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction
    function void build_phase(uvm_phase phase);
      qos_cfg cfg;

      super.build_phase(phase);
      if (!uvm_config_db#(qos_cfg)::get(this, "", "cfg", cfg))
        `uvm_fatal("CFG", "qos_source_agent cfg missing")

      is_active = cfg.is_active;
      uvm_config_db#(qos_cfg)::set(this, "mon", "cfg", cfg);
      mon = qos_source_monitor::type_id::create("mon", this);

      if (is_active == UVM_ACTIVE) begin
        uvm_config_db#(qos_cfg)::set(this, "drv", "cfg", cfg);
        seqr = qos_source_sequencer::type_id::create("seqr", this);
        drv  = qos_source_driver::type_id::create("drv", this);
      end
    endfunction
    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      mon.ap.connect(ap);

      if (is_active == UVM_ACTIVE)
        drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction
  endclass


  class qos_csr_sequencer extends uvm_sequencer #(qos_csr_item);
    `uvm_component_utils(qos_csr_sequencer)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
  endclass

  class qos_csr_driver extends uvm_driver #(qos_csr_item);
    `uvm_component_utils(qos_csr_driver)
    virtual qos_axi_if.csr_driver_mp vif;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    function void build_phase(uvm_phase phase);
      qos_cfg cfg;
      super.build_phase(phase);
      if (!uvm_config_db#(qos_cfg)::get(this, "", "cfg", cfg)) `uvm_fatal("CFG", "qos_cfg missing")
      vif = cfg.vif;
    endfunction

    task run_phase(uvm_phase phase);
      qos_csr_item tr;
      idle();
      wait(vif.rst_n === 1'b1);
      forever begin
        seq_item_port.get_next_item(tr);
        if (tr.write) axil_write(tr.addr, tr.data, tr.strb);
        else axil_read(tr.addr, tr.rdata);
        seq_item_port.item_done();
      end
    endtask

    task idle();
      vif.csr_drv_cb.S_AXIL_AWADDR  <= '0;
      vif.csr_drv_cb.S_AXIL_AWVALID <= 1'b0;
      vif.csr_drv_cb.S_AXIL_WDATA   <= '0;
      vif.csr_drv_cb.S_AXIL_WSTRB   <= '0;
      vif.csr_drv_cb.S_AXIL_WVALID  <= 1'b0;
      vif.csr_drv_cb.S_AXIL_BREADY  <= 1'b0;
      vif.csr_drv_cb.S_AXIL_ARADDR  <= '0;
      vif.csr_drv_cb.S_AXIL_ARVALID <= 1'b0;
      vif.csr_drv_cb.S_AXIL_RREADY  <= 1'b0;
    endtask

    task axil_write(bit [7:0] addr, bit [31:0] data, bit [3:0] strb);
      bit aw_done;
      bit w_done;

      aw_done = 1'b0;
      w_done  = 1'b0;

      @(vif.csr_drv_cb);
      vif.csr_drv_cb.S_AXIL_AWADDR  <= addr;
      vif.csr_drv_cb.S_AXIL_AWVALID <= 1'b1;
      vif.csr_drv_cb.S_AXIL_WDATA   <= data;
      vif.csr_drv_cb.S_AXIL_WSTRB   <= strb;
      vif.csr_drv_cb.S_AXIL_WVALID  <= 1'b1;

      while (!(aw_done && w_done)) begin
        @(vif.csr_drv_cb);

        if (!aw_done && vif.csr_drv_cb.S_AXIL_AWREADY) begin
          vif.csr_drv_cb.S_AXIL_AWVALID <= 1'b0;
          aw_done = 1'b1;
        end

        if (!w_done && vif.csr_drv_cb.S_AXIL_WREADY) begin
          vif.csr_drv_cb.S_AXIL_WVALID <= 1'b0;
          w_done = 1'b1;
        end
      end

      vif.csr_drv_cb.S_AXIL_BREADY <= 1'b1;
      while (!vif.csr_drv_cb.S_AXIL_BVALID) @(vif.csr_drv_cb);

      if (vif.csr_drv_cb.S_AXIL_BRESP != 2'b00)
        `uvm_error("CSR", "AXI-Lite write BRESP not OKAY")

      @(vif.csr_drv_cb);
      vif.csr_drv_cb.S_AXIL_BREADY <= 1'b0;
    endtask

    task axil_read(bit [7:0] addr, output bit [31:0] data);
      @(vif.csr_drv_cb);

      vif.csr_drv_cb.S_AXIL_ARADDR  <= addr;
      vif.csr_drv_cb.S_AXIL_ARVALID <= 1'b1;
      vif.csr_drv_cb.S_AXIL_RREADY  <= 1'b0;

      do @(vif.csr_drv_cb);
      while (!vif.csr_drv_cb.S_AXIL_ARREADY);

      vif.csr_drv_cb.S_AXIL_ARVALID <= 1'b0;
      vif.csr_drv_cb.S_AXIL_RREADY  <= 1'b1;

      do @(vif.csr_drv_cb);
      while (!vif.csr_drv_cb.S_AXIL_RVALID);

      data = vif.csr_drv_cb.S_AXIL_RDATA;

      if (vif.csr_drv_cb.S_AXIL_RRESP != 2'b00)
        `uvm_error("CSR", "AXI-Lite read RRESP not OKAY")

      @(vif.csr_drv_cb);
      vif.csr_drv_cb.S_AXIL_RREADY <= 1'b0;
    endtask
  endclass


  class qos_csr_agent extends uvm_agent;
    `uvm_component_utils(qos_csr_agent)
    qos_csr_sequencer seqr;
    qos_csr_driver drv;
    qos_csr_monitor mon;
    uvm_analysis_port #(qos_axi_item) ap;
    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction
    function void build_phase(uvm_phase phase);
      qos_cfg cfg;

      super.build_phase(phase);
      if (!uvm_config_db#(qos_cfg)::get(this, "", "cfg", cfg))
        `uvm_fatal("CFG", "qos_csr_agent cfg missing")

      is_active = cfg.is_active;
      uvm_config_db#(qos_cfg)::set(this, "mon", "cfg", cfg);
      mon = qos_csr_monitor::type_id::create("mon", this);

      if (is_active == UVM_ACTIVE) begin
        uvm_config_db#(qos_cfg)::set(this, "drv", "cfg", cfg);
        seqr = qos_csr_sequencer::type_id::create("seqr", this);
        drv  = qos_csr_driver::type_id::create("drv", this);
      end
    endfunction
    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      mon.ap.connect(ap);

      if (is_active == UVM_ACTIVE)
        drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction
  endclass

  class qos_master_agent extends uvm_agent;
    `uvm_component_utils(qos_master_agent)

    qos_master_monitor mon;
    uvm_analysis_port #(qos_axi_item) ap;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      qos_cfg cfg;

      super.build_phase(phase);
      if (!uvm_config_db#(qos_cfg)::get(this, "", "cfg", cfg))
        `uvm_fatal("CFG", "qos_master_agent cfg missing")

      is_active = UVM_PASSIVE;
      uvm_config_db#(qos_cfg)::set(this, "mon", "cfg", cfg);
      mon = qos_master_monitor::type_id::create("mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      mon.ap.connect(ap);
    endfunction
  endclass
