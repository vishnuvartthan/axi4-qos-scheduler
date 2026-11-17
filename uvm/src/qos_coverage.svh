  class qos_cov extends uvm_subscriber #(qos_axi_item);
    `uvm_component_utils(qos_cov)

    localparam int unsigned AW_ORDER_DEPTH = 16;

    virtual qos_axi_if vif;

    int unsigned cur_weight[NUM_REQ];
    int unsigned cur_aging;

    int unsigned aw_txn_pending;
    int unsigned ar_resp_pending;
    int unsigned wr_resp_pending;
    int unsigned weight_version[NUM_REQ];
    int unsigned ar_weight_version_q[NUM_REQ][$];
    int unsigned aw_weight_version_q[NUM_REQ][$];

    bit [M_AXI_ID_W-1:0] ar_order_q[$];
    bit [M_AXI_ID_W-1:0] b_order_q[$];

    bit reset_sampled;

    covergroup axi_event_cg with function sample(int kind, int side, int src, int id, int len, bit last);
      option.per_instance = 1;
      option.name = "axi_event_cg";

      cp_kind : coverpoint kind {
        bins ar = {QOS_AR};
        bins aw = {QOS_AW};
        bins w  = {QOS_W};
        bins r  = {QOS_R};
        bins b  = {QOS_B};
      }

      cp_side : coverpoint side {
        bins source = {QOS_SIDE_SRC};
        bins master = {QOS_SIDE_MST};
      }

      cp_src : coverpoint src {
        bins s0 = {0};
        bins s1 = {1};
        bins s2 = {2};
        bins s3 = {3};
      }

      cp_len : coverpoint len iff (kind == QOS_AR || kind == QOS_AW) {
        bins single    = {0};
        bins short_len = {[1:3]};
        bins mid_len   = {[4:7]};
        bins long_len  = {[8:15]};
      }

      cp_last : coverpoint last iff (kind == QOS_W || kind == QOS_R) {
        bins not_last  = {0};
        bins last_beat = {1};
      }

      cp_id : coverpoint id iff (kind == QOS_AR || kind == QOS_AW ||
                                 kind == QOS_R  || kind == QOS_B) {
        bins id0    = {0};
        bins low[]  = {[1:3]};
        bins high[] = {[4:15]};
      }

      cross cp_kind, cp_side;
      cross cp_kind, cp_src;
      cross cp_kind, cp_src, cp_len {
        ignore_bins non_address =
          binsof(cp_kind) intersect {QOS_W, QOS_R, QOS_B};
      }
    endgroup

    covergroup axi_sideband_cg with function sample(int kind, int size, int burst,
                                                    int lock, int cache, int prot, int qos);
      option.per_instance = 1;
      option.name = "axi_sideband_cg";

      cp_kind : coverpoint kind {
        bins ar = {QOS_AR};
        bins aw = {QOS_AW};
      }

      cp_size : coverpoint size {
        bins byte_transfer = {0};
        bins halfword       = {1};
        bins word           = {2};
        illegal_bins unsupported = default;
      }

      cp_burst : coverpoint burst {
        bins fixed = {0};
        bins incr  = {1};
        bins wrap  = {2};
        illegal_bins reserved = {3};
      }

      cp_lock : coverpoint lock {
        bins normal    = {0};
        bins exclusive = {1};
      }

      cp_cache : coverpoint cache {
        bins zero    = {0};
        bins nonzero = {[1:15]};
      }

      cp_prot : coverpoint prot {
        bins value[] = {[0:7]};
      }

      cp_qos : coverpoint qos {
        bins zero = {0};
        bins low  = {[1:7]};
        bins high = {[8:15]};
      }

      cross cp_kind, cp_size;
      cross cp_kind, cp_burst;
      cross cp_kind, cp_lock;
    endgroup

    covergroup axi_backpressure_cg with function sample(bit ar_bp, bit aw_bp, bit w_bp, bit r_bp, bit b_bp);
      option.per_instance = 1;
      option.name = "axi_backpressure_cg";

      cp_ar_bp : coverpoint ar_bp { bins no = {0}; bins yes = {1}; }
      cp_aw_bp : coverpoint aw_bp { bins no = {0}; bins yes = {1}; }
      cp_w_bp  : coverpoint w_bp  { bins no = {0}; bins yes = {1}; }
      cp_r_bp  : coverpoint r_bp  { bins no = {0}; bins yes = {1}; }
      cp_b_bp  : coverpoint b_bp  { bins no = {0}; bins yes = {1}; }
    endgroup

    covergroup csr_policy_cg with function sample(int kind, int addr, int data,
                                                  bit policy_write, bit active_traffic);
      option.per_instance = 1;
      option.name = "csr_policy_cg";

      cp_kind : coverpoint kind {
        bins wr = {QOS_CSR_WR};
        bins rd = {QOS_CSR_RD};
      }

      cp_addr : coverpoint addr {
        bins weight0     = {8'h00};
        bins weight1     = {8'h04};
        bins weight2     = {8'h08};
        bins weight3     = {8'h0c};
        bins aging       = {8'h10};
        bins fifo_stat   = {8'h20};
        bins grant_cnt[] = {8'h30, 8'h34, 8'h38, 8'h3c};
        bins stall_cnt   = {8'h40};
        bins starve_cnt  = {8'h44};
      }

      cp_policy_addr : coverpoint addr iff (policy_write) {
        bins weight0 = {8'h00};
        bins weight1 = {8'h04};
        bins weight2 = {8'h08};
        bins weight3 = {8'h0c};
        bins aging   = {8'h10};
      }

      cp_data : coverpoint data iff (policy_write) {
        bins zero = {0};
        bins one  = {1};
        bins low  = {[2:7]};
        bins age8 = {8};
        bins high = {[9:255]};
      }

      cp_active_traffic : coverpoint active_traffic iff (policy_write) {
        bins no  = {0};
        bins yes = {1};
      }

      cross cp_kind, cp_addr {
        ignore_bins wr_read_only =
          binsof(cp_kind.wr) &&
          binsof(cp_addr) intersect {8'h20, 8'h30, 8'h34, 8'h38, 8'h3c, 8'h40, 8'h44};
      }

      cross cp_policy_addr, cp_active_traffic;
    endgroup

    covergroup grant_policy_cg with function sample(int kind, int src, int src_weight,
                                                    int weight_pattern, int aging, int contenders);
      option.per_instance = 1;
      option.name = "grant_policy_cg";

      cp_kind : coverpoint kind {
        bins ar = {QOS_AR};
        bins aw = {QOS_AW};
      }

      cp_src : coverpoint src {
        bins s0 = {0};
        bins s1 = {1};
        bins s2 = {2};
        bins s3 = {3};
      }

      cp_src_weight : coverpoint src_weight {
        bins zero = {0};
        bins one  = {1};
        bins low  = {[2:7]};
        bins high = {[8:15]};
      }

      cp_weight_pattern : coverpoint weight_pattern {
        bins equal_nonzero = {0};
        bins ascending     = {1};
        bins descending    = {2};
        bins has_zero      = {3};
        bins mixed         = {4};
      }

      cp_aging : coverpoint aging {
        bins low  = {[0:8]};
        bins mid  = {[9:63]};
        bins high = {[64:255]};
      }

      cp_contenders : coverpoint contenders iff (contenders >= 2) {
        bins two   = {2};
        bins three = {3};
        bins four  = {4};
      }

      cross cp_kind, cp_src;
      cross cp_src, cp_src_weight;
      cross cp_kind, cp_weight_pattern;
      cross cp_kind, cp_contenders;
    endgroup

    covergroup response_cg with function sample(int kind, int src, int resp, bit reordered);
      option.per_instance = 1;
      option.name = "response_cg";

      cp_kind : coverpoint kind {
        bins r = {QOS_R};
        bins b = {QOS_B};
      }

      cp_src : coverpoint src {
        bins s0 = {0};
        bins s1 = {1};
        bins s2 = {2};
        bins s3 = {3};
      }

      cp_resp : coverpoint resp {
        bins okay   = {0};
        bins exokay = {1};
        bins slverr = {2};
        bins decerr = {3};
      }

      cp_reordered : coverpoint reordered {
        bins no  = {0};
        bins yes = {1};
      }

      cross cp_kind, cp_src, cp_resp;
      cross cp_kind, cp_resp, cp_reordered;
    endgroup

    covergroup aging_override_cg with function sample(int kind, int src, int aging);
      option.per_instance = 1;
      option.name = "aging_override_cg";

      cp_kind : coverpoint kind {
        bins ar = {QOS_AR};
        bins aw = {QOS_AW};
      }

      cp_src : coverpoint src {
        bins s0 = {0};
        bins s1 = {1};
        bins s2 = {2};
        bins s3 = {3};
      }

      cp_aging : coverpoint aging {
        bins low  = {[1:8]};
        bins mid  = {[9:63]};
        bins high = {[64:255]};
      }

      cross cp_kind, cp_src;
      cross cp_kind, cp_aging;
    endgroup

    covergroup aw_order_depth_cg with function sample(int depth);
      option.per_instance = 1;
      option.name = "aw_order_depth_cg";

      cp_depth : coverpoint depth {
        bins empty     = {0};
        bins partial   = {[1:AW_ORDER_DEPTH-1]};
        bins full      = {AW_ORDER_DEPTH};
        bins recovered = (AW_ORDER_DEPTH => [1:AW_ORDER_DEPTH-1]);
      }
    endgroup

    covergroup reset_outstanding_cg with function sample(bit read_pending, bit write_pending);
      option.per_instance = 1;
      option.name = "reset_outstanding_cg";

      cp_read_pending : coverpoint read_pending {
        bins yes = {1};
      }

      cp_write_pending : coverpoint write_pending {
        bins yes = {1};
      }
    endgroup

    function new(string name, uvm_component parent);
      super.new(name, parent);

      axi_event_cg         = new();
      axi_sideband_cg      = new();
      axi_backpressure_cg  = new();
      csr_policy_cg        = new();
      grant_policy_cg      = new();
      response_cg          = new();
      aging_override_cg    = new();
      aw_order_depth_cg    = new();
      reset_outstanding_cg = new();

      for (int i = 0; i < NUM_REQ; i++) begin
        cur_weight[i] = 1;
        weight_version[i] = 0;
      end

      cur_aging           = 8'h10;
      aw_txn_pending      = 0;
      ar_resp_pending     = 0;
      wr_resp_pending     = 0;
      reset_sampled       = 1'b0;
    endfunction

    function void build_phase(uvm_phase phase);
      qos_cfg cfg;
      super.build_phase(phase);

      if (!uvm_config_db#(qos_cfg)::get(this, "", "cfg", cfg))
        `uvm_fatal("CFG", "qos_cov cfg missing")

      vif = cfg.vif;
    endfunction

    function int unsigned current_weight(int unsigned src);
      if (src < NUM_REQ)
        return cur_weight[src];
      return 0;
    endfunction

    function bit source_weight_zero(int unsigned src);
      return ((src < NUM_REQ) && (cur_weight[src] == 0));
    endfunction

    function bit traffic_active();
      return ((aw_txn_pending != 0) ||
              (ar_resp_pending != 0) ||
              (wr_resp_pending != 0) ||
              (|vif.source_mon_cb.S_AXI_ARVALID) ||
              (|vif.source_mon_cb.S_AXI_AWVALID) ||
              (|vif.source_mon_cb.S_AXI_WVALID));
    endfunction

    function int unsigned weight_pattern_id();
      bit has_zero;

      has_zero = 1'b0;

      for (int i = 0; i < NUM_REQ; i++) begin
        if (cur_weight[i] == 0)
          has_zero = 1'b1;
      end

      if (has_zero)
        return 3;

      if ((cur_weight[0] == cur_weight[1]) &&
          (cur_weight[1] == cur_weight[2]) &&
          (cur_weight[2] == cur_weight[3]))
        return 0;

      if ((cur_weight[0] < cur_weight[1]) &&
          (cur_weight[1] < cur_weight[2]) &&
          (cur_weight[2] < cur_weight[3]))
        return 1;

      if ((cur_weight[0] > cur_weight[1]) &&
          (cur_weight[1] > cur_weight[2]) &&
          (cur_weight[2] > cur_weight[3]))
        return 2;

      return 4;
    endfunction

    function void update_policy_mirror(qos_axi_item t);
      if (t.kind != QOS_CSR_WR)
        return;

      if (t.strb[0]) begin
        case (t.addr[7:0])
          8'h00: begin cur_weight[0] = t.data[3:0]; weight_version[0]++; end
          8'h04: begin cur_weight[1] = t.data[3:0]; weight_version[1]++; end
          8'h08: begin cur_weight[2] = t.data[3:0]; weight_version[2]++; end
          8'h0c: begin cur_weight[3] = t.data[3:0]; weight_version[3]++; end
          8'h10: cur_aging    = t.data[7:0];
          default: ;
        endcase
      end
    endfunction

    function void sample_observed_arbitration(qos_axi_item t);
      int unsigned contenders;
      int unsigned accepted_weight_version;
      bit accepted_request;

      if ((t.side == QOS_SIDE_SRC) && (t.src < NUM_REQ)) begin
        if (t.kind == QOS_AR)
          ar_weight_version_q[t.src].push_back(weight_version[t.src]);
        else if (t.kind == QOS_AW)
          aw_weight_version_q[t.src].push_back(weight_version[t.src]);

        return;
      end

      if ((t.side != QOS_SIDE_MST) || (t.src >= NUM_REQ) ||
          ((t.kind != QOS_AR) && (t.kind != QOS_AW)))
        return;

      contenders = 0;
      for (int i = 0; i < NUM_REQ; i++) begin
        if ((t.kind == QOS_AR) && (ar_weight_version_q[i].size() != 0))
          contenders++;
        else if ((t.kind == QOS_AW) && (aw_weight_version_q[i].size() != 0))
          contenders++;
      end

      accepted_request = 1'b0;
      if ((t.kind == QOS_AR) && (ar_weight_version_q[t.src].size() != 0)) begin
        accepted_weight_version = ar_weight_version_q[t.src].pop_front();
        accepted_request = 1'b1;
      end else if ((t.kind == QOS_AW) && (aw_weight_version_q[t.src].size() != 0)) begin
        accepted_weight_version = aw_weight_version_q[t.src].pop_front();
        accepted_request = 1'b1;
      end

      if (accepted_request)
        grant_policy_cg.sample(
          t.kind,
          t.src,
          current_weight(t.src),
          weight_pattern_id(),
          cur_aging,
          contenders
        );

      // Stable zero weight means this grant came from aging
      if (accepted_request && source_weight_zero(t.src) &&
          (accepted_weight_version == weight_version[t.src]))
        aging_override_cg.sample(t.kind, t.src, cur_aging);
    endfunction

    function bit response_reordered(qos_axi_item t);
      case (t.kind)
        QOS_R: return ((ar_order_q.size() != 0) && (t.mid != ar_order_q[0]));
        QOS_B: return ((b_order_q.size() != 0) && (t.mid != b_order_q[0]));
        default: return 1'b0;
      endcase
    endfunction

    function void retire_ar_response(bit [M_AXI_ID_W-1:0] mid);
      for (int i = 0; i < ar_order_q.size(); i++) begin
        if (ar_order_q[i] == mid) begin
          ar_order_q.delete(i);
          return;
        end
      end
    endfunction

    function void retire_b_response(bit [M_AXI_ID_W-1:0] mid);
      for (int i = 0; i < b_order_q.size(); i++) begin
        if (b_order_q[i] == mid) begin
          b_order_q.delete(i);
          return;
        end
      end
    endfunction

    function void sample_response(qos_axi_item t);
      bit reordered;

      if (t.side != QOS_SIDE_MST)
        return;

      case (t.kind)
        QOS_R: begin
          reordered = response_reordered(t);
          response_cg.sample(t.kind, t.src, t.resp, reordered);

          if (t.last)
            retire_ar_response(t.mid);
        end

        QOS_B: begin
          reordered = response_reordered(t);
          response_cg.sample(t.kind, t.src, t.resp, reordered);
          retire_b_response(t.mid);
        end

        default: ;
      endcase
    endfunction

    task run_phase(uvm_phase phase);
      int unsigned next_aw_txn;
      int unsigned next_ar_resp;
      int unsigned next_wr_resp;

      wait(vif.rst_n === 1'b1);

      forever begin
        @(vif.master_mon_cb);

        if (!vif.rst_n) begin
          if (!reset_sampled) begin
            reset_outstanding_cg.sample(
              (ar_resp_pending != 0),
              (wr_resp_pending != 0)
            );

            reset_sampled = 1'b1;
          end

          for (int i = 0; i < NUM_REQ; i++) begin
            cur_weight[i] = 1;
            weight_version[i] = 0;
            ar_weight_version_q[i].delete();
            aw_weight_version_q[i].delete();
          end

          cur_aging       = 8'h10;
          aw_txn_pending  = 0;
          ar_resp_pending = 0;
          wr_resp_pending = 0;
          ar_order_q.delete();
          b_order_q.delete();
          continue;
        end

        reset_sampled = 1'b0;

        axi_backpressure_cg.sample(
          vif.master_mon_cb.M_AXI_ARVALID && !vif.master_mon_cb.M_AXI_ARREADY,
          vif.master_mon_cb.M_AXI_AWVALID && !vif.master_mon_cb.M_AXI_AWREADY,
          vif.master_mon_cb.M_AXI_WVALID  && !vif.master_mon_cb.M_AXI_WREADY,
          vif.master_mon_cb.M_AXI_RVALID  && !vif.master_mon_cb.M_AXI_RREADY,
          vif.master_mon_cb.M_AXI_BVALID  && !vif.master_mon_cb.M_AXI_BREADY
        );

        next_aw_txn  = aw_txn_pending;
        next_ar_resp = ar_resp_pending;
        next_wr_resp = wr_resp_pending;

        if (vif.master_mon_cb.M_AXI_AWVALID && vif.master_mon_cb.M_AXI_AWREADY) begin
          next_aw_txn++;
          next_wr_resp++;
        end

        if (vif.master_mon_cb.M_AXI_WVALID &&
            vif.master_mon_cb.M_AXI_WREADY &&
            vif.master_mon_cb.M_AXI_WLAST &&
            (next_aw_txn != 0))
          next_aw_txn--;

        if (vif.master_mon_cb.M_AXI_ARVALID && vif.master_mon_cb.M_AXI_ARREADY)
          next_ar_resp++;

        if (vif.master_mon_cb.M_AXI_RVALID &&
            vif.master_mon_cb.M_AXI_RREADY &&
            vif.master_mon_cb.M_AXI_RLAST &&
            (next_ar_resp != 0))
          next_ar_resp--;

        if (vif.master_mon_cb.M_AXI_BVALID &&
            vif.master_mon_cb.M_AXI_BREADY &&
            (next_wr_resp != 0))
          next_wr_resp--;

        aw_txn_pending  = next_aw_txn;
        ar_resp_pending = next_ar_resp;
        wr_resp_pending = next_wr_resp;

        aw_order_depth_cg.sample(aw_txn_pending);
      end
    endtask

    function void write(qos_axi_item t);
      if (t.side == QOS_SIDE_CSR) begin
        csr_policy_cg.sample(
          t.kind,
          t.addr[7:0],
          t.data,
          (t.kind == QOS_CSR_WR) && t.strb[0] &&
            (t.addr[7:0] inside {8'h00, 8'h04, 8'h08, 8'h0c, 8'h10}),
          traffic_active()
        );

        update_policy_mirror(t);
      end else begin
        axi_event_cg.sample(t.kind, t.side, t.src, t.id, t.len, t.last);

        if ((t.side == QOS_SIDE_MST) &&
            ((t.kind == QOS_AR) || (t.kind == QOS_AW)))
          axi_sideband_cg.sample(t.kind, t.size, t.burst, t.lock, t.cache, t.prot, t.qos);

        if ((t.side == QOS_SIDE_MST) && (t.kind == QOS_AR))
          ar_order_q.push_back(t.mid);

        if ((t.side == QOS_SIDE_MST) && (t.kind == QOS_AW))
          b_order_q.push_back(t.mid);

        sample_observed_arbitration(t);
        sample_response(t);
      end
    endfunction

    function void report_phase(uvm_phase phase);
      super.report_phase(phase);

      `uvm_info("COV_SUMMARY",
                $sformatf({"axi_event_cov=%0.2f sideband_cov=%0.2f ",
                           "backpressure_cov=%0.2f csr_policy_cov=%0.2f ",
                           "grant_policy_cov=%0.2f response_cov=%0.2f ",
                           "aging_override_cov=%0.2f aw_order_depth_cov=%0.2f ",
                           "reset_outstanding_cov=%0.2f"},
                          axi_event_cg.get_inst_coverage(),
                          axi_sideband_cg.get_inst_coverage(),
                          axi_backpressure_cg.get_inst_coverage(),
                          csr_policy_cg.get_inst_coverage(),
                          grant_policy_cg.get_inst_coverage(),
                          response_cg.get_inst_coverage(),
                          aging_override_cg.get_inst_coverage(),
                          aw_order_depth_cg.get_inst_coverage(),
                          reset_outstanding_cg.get_inst_coverage()),
                UVM_LOW)
    endfunction
  endclass
