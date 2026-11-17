  class qos_mem_model extends uvm_component;
    `uvm_component_utils(qos_mem_model)

    typedef struct {
      bit [M_AXI_ID_W-1:0] id;
      bit [AXI_LEN_W-1:0] len;
      bit                 lock;
    } read_req_t;

    typedef struct {
      bit [M_AXI_ID_W-1:0] id;
      bit                 lock;
    } write_req_t;

    virtual qos_axi_if.master_responder_mp vif;
    int unsigned ready_pct = 80;
    bit response_enable = 1'b1;
    bit response_reorder_enable = 1'b0;
    bit inject_error_responses = 1'b0;
    int unsigned response_collect_cycles = 8;
    int unsigned response_reorder_depth = 4;
    int unsigned response_error_period = 3;

    read_req_t r_q[$];
    write_req_t aw_q[$];
    write_req_t b_q[$];

    int unsigned r_response_count;
    int unsigned b_response_count;
    int unsigned r_reorder_count;
    int unsigned b_reorder_count;
    int unsigned r_slverr_count;
    int unsigned r_decerr_count;
    int unsigned b_slverr_count;
    int unsigned b_decerr_count;
    int unsigned reset_discarded_count;
    bit [NUM_REQ-1:0] r_exokay_src_seen;
    bit [NUM_REQ-1:0] b_exokay_src_seen;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      r_response_count      = 0;
      b_response_count      = 0;
      r_reorder_count       = 0;
      b_reorder_count       = 0;
      r_slverr_count        = 0;
      r_decerr_count        = 0;
      b_slverr_count        = 0;
      b_decerr_count        = 0;
      reset_discarded_count = 0;
      r_exokay_src_seen     = '0;
      b_exokay_src_seen     = '0;
    endfunction

    function void build_phase(uvm_phase phase);
      qos_cfg cfg;
      super.build_phase(phase);
      if (!uvm_config_db#(qos_cfg)::get(this, "", "cfg", cfg)) `uvm_fatal("CFG", "qos_cfg missing")
      vif = cfg.vif;
      ready_pct = cfg.ready_pct;
    endfunction

    function void set_ready_pct(int unsigned value);
      if (value > 100)
        `uvm_error("MEM_CFG", $sformatf("ready percentage %0d is greater than 100", value))
      else
        ready_pct = value;
    endfunction

    function void set_response_enable(bit enable);
      response_enable = enable;
    endfunction

    function void set_response_reorder_enable(bit enable);
      response_reorder_enable = enable;
    endfunction

    function void set_error_injection_enable(bit enable);
      inject_error_responses = enable;
    endfunction

    function void set_response_collect_cycles(int unsigned cycles);
      response_collect_cycles = cycles;
    endfunction

    function void set_response_reorder_depth(int unsigned depth);
      response_reorder_depth = depth;
    endfunction

    function void set_response_error_period(int unsigned period);
      response_error_period = period;
    endfunction

    function int unsigned get_read_pending_count(); return r_q.size(); endfunction
    function int unsigned get_write_address_pending_count(); return aw_q.size(); endfunction
    function int unsigned get_write_response_pending_count(); return b_q.size(); endfunction
    function int unsigned get_response_reorder_depth(); return response_reorder_depth; endfunction
    function int unsigned get_read_response_count(); return r_response_count; endfunction
    function int unsigned get_write_response_count(); return b_response_count; endfunction
    function int unsigned get_read_reorder_count(); return r_reorder_count; endfunction
    function int unsigned get_write_reorder_count(); return b_reorder_count; endfunction
    function int unsigned get_read_slverr_count(); return r_slverr_count; endfunction
    function int unsigned get_read_decerr_count(); return r_decerr_count; endfunction
    function int unsigned get_write_slverr_count(); return b_slverr_count; endfunction
    function int unsigned get_write_decerr_count(); return b_decerr_count; endfunction
    function int unsigned get_reset_discarded_count(); return reset_discarded_count; endfunction
    function bit [NUM_REQ-1:0] get_read_exokay_sources(); return r_exokay_src_seen; endfunction
    function bit [NUM_REQ-1:0] get_write_exokay_sources(); return b_exokay_src_seen; endfunction

    task reset_state();
      reset_discarded_count += r_q.size() + aw_q.size() + b_q.size();
      r_q.delete();
      aw_q.delete();
      b_q.delete();

      vif.master_rsp_cb.M_AXI_ARREADY <= 1'b0;
      vif.master_rsp_cb.M_AXI_AWREADY <= 1'b0;
      vif.master_rsp_cb.M_AXI_WREADY  <= 1'b0;
      vif.master_rsp_cb.M_AXI_RVALID  <= 1'b0;
      vif.master_rsp_cb.M_AXI_BVALID  <= 1'b0;
      vif.master_rsp_cb.M_AXI_RID     <= '0;
      vif.master_rsp_cb.M_AXI_RDATA   <= '0;
      vif.master_rsp_cb.M_AXI_RRESP   <= 2'b00;
      vif.master_rsp_cb.M_AXI_RLAST   <= 1'b0;
      vif.master_rsp_cb.M_AXI_BID     <= '0;
      vif.master_rsp_cb.M_AXI_BRESP   <= 2'b00;
    endtask

    task run_phase(uvm_phase phase);
      reset_state();

      forever begin
        wait(vif.rst_n === 1'b1);

        fork : mem_epoch
          accept_loop();
          read_resp_loop();
          write_resp_loop();
          begin
            wait(vif.rst_n === 1'b0);
          end
        join_any

        disable mem_epoch;
        reset_state();
      end
    endtask

    function int select_read_index();
      int candidates[$];
      bit earlier_same_id;

      if (!response_reorder_enable || (r_q.size() < 2))
        return 0;

      for (int i = 0; i < r_q.size(); i++) begin
        earlier_same_id = 1'b0;

        for (int j = 0; j < i; j++) begin
          if (r_q[j].id == r_q[i].id)
            earlier_same_id = 1'b1;
        end

        if (!earlier_same_id)
          candidates.push_back(i);
      end

      if (candidates.size() < 2)
        return candidates[0];

      if (r_reorder_count == 0)
        return candidates[candidates.size() - 1];

      return candidates[$urandom_range(candidates.size() - 1, 0)];
    endfunction

    function int select_write_index();
      int candidates[$];
      bit earlier_same_id;

      if (!response_reorder_enable || (b_q.size() < 2))
        return 0;

      for (int i = 0; i < b_q.size(); i++) begin
        earlier_same_id = 1'b0;

        for (int j = 0; j < i; j++) begin
          if (b_q[j].id == b_q[i].id)
            earlier_same_id = 1'b1;
        end

        if (!earlier_same_id)
          candidates.push_back(i);
      end

      if (candidates.size() < 2)
        return candidates[0];

      if (b_reorder_count == 0)
        return candidates[candidates.size() - 1];

      return candidates[$urandom_range(candidates.size() - 1, 0)];
    endfunction

    function bit [1:0] next_read_resp(read_req_t req);
      bit [1:0] resp;
      int unsigned src;

      resp = 2'b00;
      src  = req.id[M_AXI_ID_W-1:AXI_ID_W];

      if (req.lock) begin
        resp = 2'b01;

        if (src < NUM_REQ)
          r_exokay_src_seen[src] = 1'b1;
      end else if (inject_error_responses &&
          (response_error_period != 0) &&
          ((r_response_count % response_error_period) == 0)) begin
        if (r_response_count[0]) begin
          resp = 2'b11;
          r_decerr_count++;
        end else begin
          resp = 2'b10;
          r_slverr_count++;
        end
      end

      r_response_count++;
      return resp;
    endfunction

    function bit [1:0] next_write_resp(write_req_t req);
      bit [1:0] resp;
      int unsigned src;

      resp = 2'b00;
      src  = req.id[M_AXI_ID_W-1:AXI_ID_W];

      if (req.lock) begin
        resp = 2'b01;

        if (src < NUM_REQ)
          b_exokay_src_seen[src] = 1'b1;
      end else if (inject_error_responses &&
          (response_error_period != 0) &&
          ((b_response_count % response_error_period) == 0)) begin
        if (b_response_count[0]) begin
          resp = 2'b11;
          b_decerr_count++;
        end else begin
          resp = 2'b10;
          b_slverr_count++;
        end
      end

      b_response_count++;
      return resp;
    endfunction

    task accept_loop();
      read_req_t read_req;
      write_req_t write_req;
      bit arready_q;
      bit awready_q;
      bit wready_q;

      arready_q = 1'b0;
      awready_q = 1'b0;
      wready_q  = 1'b0;

      forever begin
        @(vif.master_rsp_cb);

        if (vif.master_rsp_cb.M_AXI_ARVALID && arready_q) begin
          read_req.id   = vif.master_rsp_cb.M_AXI_ARID;
          read_req.len  = vif.master_rsp_cb.M_AXI_ARLEN;
          read_req.lock = vif.master_rsp_cb.M_AXI_ARLOCK;
          r_q.push_back(read_req);
        end

        if (vif.master_rsp_cb.M_AXI_AWVALID && awready_q) begin
          write_req.id   = vif.master_rsp_cb.M_AXI_AWID;
          write_req.lock = vif.master_rsp_cb.M_AXI_AWLOCK;
          aw_q.push_back(write_req);
        end

        if (vif.master_rsp_cb.M_AXI_WVALID &&
            wready_q &&
            vif.master_rsp_cb.M_AXI_WLAST) begin
          if (aw_q.size() == 0) `uvm_error("MEM", "WLAST without accepted AW")
          else b_q.push_back(aw_q.pop_front());
        end

        arready_q = ($urandom_range(0,99) < ready_pct);
        awready_q = ($urandom_range(0,99) < ready_pct);
        wready_q  = ($urandom_range(0,99) < ready_pct);
        vif.master_rsp_cb.M_AXI_ARREADY <= arready_q;
        vif.master_rsp_cb.M_AXI_AWREADY <= awready_q;
        vif.master_rsp_cb.M_AXI_WREADY  <= wready_q;
      end
    endtask

    task read_resp_loop();
      read_req_t read_req;
      bit [1:0] resp;
      int selected;

      forever begin
        wait(response_enable && (r_q.size() > 0));

        if (response_reorder_enable) begin
          for (int i = 0; i < response_collect_cycles; i++) begin
            if (r_q.size() >= response_reorder_depth)
              break;
            @(vif.master_rsp_cb);
          end
        end

        wait(response_enable && (r_q.size() > 0));
        selected = select_read_index();

        if (selected != 0)
          r_reorder_count++;

        read_req = r_q[selected];
        r_q.delete(selected);
        resp = next_read_resp(read_req);
        repeat ($urandom_range(1,8)) @(vif.master_rsp_cb);

        for (int unsigned beat = 0; beat <= read_req.len; beat++) begin
          vif.master_rsp_cb.M_AXI_RID    <= read_req.id;
          vif.master_rsp_cb.M_AXI_RDATA  <= $urandom;
          vif.master_rsp_cb.M_AXI_RRESP  <= resp;
          vif.master_rsp_cb.M_AXI_RLAST  <= (beat == read_req.len);
          vif.master_rsp_cb.M_AXI_RVALID <= 1'b1;
          do @(vif.master_rsp_cb); while (!vif.master_rsp_cb.M_AXI_RREADY);
        end

        vif.master_rsp_cb.M_AXI_RVALID <= 1'b0;
        vif.master_rsp_cb.M_AXI_RLAST  <= 1'b0;
        vif.master_rsp_cb.M_AXI_RRESP  <= 2'b00;
      end
    endtask

    task write_resp_loop();
      write_req_t write_req;
      bit [1:0] resp;
      int selected;

      forever begin
        wait(response_enable && (b_q.size() > 0));

        if (response_reorder_enable) begin
          for (int i = 0; i < response_collect_cycles; i++) begin
            if (b_q.size() >= response_reorder_depth)
              break;
            @(vif.master_rsp_cb);
          end
        end

        wait(response_enable && (b_q.size() > 0));
        selected = select_write_index();

        if (selected != 0)
          b_reorder_count++;

        write_req = b_q[selected];
        b_q.delete(selected);
        resp = next_write_resp(write_req);
        repeat ($urandom_range(1,8)) @(vif.master_rsp_cb);
        vif.master_rsp_cb.M_AXI_BID    <= write_req.id;
        vif.master_rsp_cb.M_AXI_BRESP  <= resp;
        vif.master_rsp_cb.M_AXI_BVALID <= 1'b1;
        do @(vif.master_rsp_cb); while (!vif.master_rsp_cb.M_AXI_BREADY);
        vif.master_rsp_cb.M_AXI_BVALID <= 1'b0;
        vif.master_rsp_cb.M_AXI_BRESP  <= 2'b00;
      end
    endtask
  endclass
