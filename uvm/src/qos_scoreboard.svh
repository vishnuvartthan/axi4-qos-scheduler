  `uvm_analysis_imp_decl(_mon)

  class qos_scoreboard extends uvm_component;
    `uvm_component_utils(qos_scoreboard)

    uvm_analysis_imp_mon #(qos_axi_item, qos_scoreboard) mon_imp;
    virtual qos_axi_if vif;

    typedef struct {
      int unsigned src;
      bit [AXI_ID_W-1:0] id;
      bit [AXI_ADDR_W-1:0] addr;
      bit [AXI_LEN_W-1:0] len;
      bit [AXI_SIZE_W-1:0] size;
      bit [AXI_BURST_W-1:0] burst;
      bit [AXI_LOCK_W-1:0] lock;
      bit [AXI_CACHE_W-1:0] cache;
      bit [AXI_PROT_W-1:0] prot;
      bit [AXI_QOS_W-1:0] qos;
    } addr_track_t;

    typedef struct {
      int unsigned src;
      bit [AXI_ID_W-1:0] id;
      int unsigned beats_left;
    } aw_track_t;

    typedef struct {
      int unsigned beats_left;
    } ar_resp_track_t;

    typedef struct {
      bit [AXI_ID_W-1:0] id;
    } b_resp_track_t;

    typedef struct {
      bit [AXI_DATA_W-1:0] data;
      bit [AXI_STRB_W-1:0] strb;
      bit last;
    } w_track_t;

    typedef struct {
      bit [AXI_ID_W-1:0] id;
      bit [AXI_DATA_W-1:0] data;
      bit last;
      bit [1:0] resp;
    } r_track_t;

    typedef struct {
      bit [AXI_ID_W-1:0] id;
      bit [1:0] resp;
    } b_track_t;

    addr_track_t src_ar_q[NUM_REQ][$];
    addr_track_t src_aw_q[NUM_REQ][$];
    w_track_t    src_w_q [NUM_REQ][$];

    aw_track_t   mst_aw_order_q[$];
    ar_resp_track_t mst_ar_resp_q[1 << M_AXI_ID_W][$];
    b_resp_track_t mst_b_resp_q[1 << M_AXI_ID_W][$];

    r_track_t exp_r_q[NUM_REQ][$];
    r_track_t got_r_q[NUM_REQ][$];

    b_track_t exp_b_q[NUM_REQ][$];
    b_track_t got_b_q[NUM_REQ][$];

    int unsigned ar_checks;
    int unsigned aw_checks;
    int unsigned w_beat_checks;
    int unsigned r_route_checks;
    int unsigned r_burst_checks;
    int unsigned b_route_checks;
    int unsigned r_error_route_checks;
    int unsigned b_error_route_checks;
    int unsigned sideband_checks;
    int unsigned reset_flush_count;
    int unsigned reset_dropped_items;

    bit [7:0] sideband_size_seen;
    bit [3:0] sideband_burst_seen;
    bit [1:0] sideband_lock_seen;
    bit sideband_cache_zero_seen;
    bit sideband_cache_nonzero_seen;
    bit sideband_prot_zero_seen;
    bit sideband_prot_nonzero_seen;
    bit sideband_qos_zero_seen;
    bit sideband_qos_nonzero_seen;

    bit allow_pending_ar_at_end = 1'b0;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      mon_imp = new("mon_imp", this);
      ar_checks                  = 0;
      aw_checks                  = 0;
      w_beat_checks              = 0;
      r_route_checks             = 0;
      r_error_route_checks       = 0;
      r_burst_checks             = 0;
      b_route_checks             = 0;
      b_error_route_checks       = 0;
      sideband_checks            = 0;
      reset_flush_count          = 0;
      reset_dropped_items        = 0;
      sideband_size_seen         = '0;
      sideband_burst_seen        = '0;
      sideband_lock_seen         = '0;
      sideband_cache_zero_seen   = 1'b0;
      sideband_cache_nonzero_seen = 1'b0;
      sideband_prot_zero_seen    = 1'b0;
      sideband_prot_nonzero_seen = 1'b0;
      sideband_qos_zero_seen     = 1'b0;
      sideband_qos_nonzero_seen  = 1'b0;
    endfunction

    function void build_phase(uvm_phase phase);
      qos_cfg cfg;
      super.build_phase(phase);

      if (!uvm_config_db#(qos_cfg)::get(this, "", "cfg", cfg))
        `uvm_fatal("CFG", "qos_scoreboard cfg missing")

      vif = cfg.vif;
    endfunction

    function void set_allow_pending_ar(bit allow);
      allow_pending_ar_at_end = allow;
    endfunction

    function int unsigned get_ar_checks(); return ar_checks; endfunction
    function int unsigned get_aw_checks(); return aw_checks; endfunction
    function int unsigned get_w_beat_checks(); return w_beat_checks; endfunction
    function int unsigned get_r_route_checks(); return r_route_checks; endfunction
    function int unsigned get_r_burst_checks(); return r_burst_checks; endfunction
    function int unsigned get_b_route_checks(); return b_route_checks; endfunction
    function int unsigned get_r_error_route_checks(); return r_error_route_checks; endfunction
    function int unsigned get_b_error_route_checks(); return b_error_route_checks; endfunction
    function int unsigned get_sideband_checks(); return sideband_checks; endfunction
    function int unsigned get_reset_flush_count(); return reset_flush_count; endfunction
    function int unsigned get_reset_dropped_items(); return reset_dropped_items; endfunction

    function int unsigned get_master_aw_pending();
      return mst_aw_order_q.size();
    endfunction

    function int unsigned get_source_aw_pending(int unsigned src);
      if (src >= NUM_REQ) begin
        `uvm_error("SB_API", $sformatf("Illegal source index %0d", src))
        return 0;
      end

      return src_aw_q[src].size();
    endfunction

    function bit [7:0] get_sideband_size_seen(); return sideband_size_seen; endfunction
    function bit [3:0] get_sideband_burst_seen(); return sideband_burst_seen; endfunction
    function bit [1:0] get_sideband_lock_seen(); return sideband_lock_seen; endfunction
    function bit get_sideband_cache_zero_seen(); return sideband_cache_zero_seen; endfunction
    function bit get_sideband_cache_nonzero_seen(); return sideband_cache_nonzero_seen; endfunction
    function bit get_sideband_prot_zero_seen(); return sideband_prot_zero_seen; endfunction
    function bit get_sideband_prot_nonzero_seen(); return sideband_prot_nonzero_seen; endfunction
    function bit get_sideband_qos_zero_seen(); return sideband_qos_zero_seen; endfunction
    function bit get_sideband_qos_nonzero_seen(); return sideband_qos_nonzero_seen; endfunction

    task run_phase(uvm_phase phase);
      wait(vif.rst_n === 1'b1);

      forever begin
        @(negedge vif.rst_n);
        flush_on_reset();
        reset_flush_count++;
        wait(vif.rst_n === 1'b1);
      end
    endtask

    function void flush_on_reset();
      int unsigned dropped;

      dropped = mst_aw_order_q.size();

      for (int i = 0; i < NUM_REQ; i++) begin
        dropped += src_ar_q[i].size();
        dropped += src_aw_q[i].size();
        dropped += src_w_q[i].size();
        dropped += exp_r_q[i].size();
        dropped += got_r_q[i].size();
        dropped += exp_b_q[i].size();
        dropped += got_b_q[i].size();

        src_ar_q[i].delete();
        src_aw_q[i].delete();
        src_w_q[i].delete();
        exp_r_q[i].delete();
        got_r_q[i].delete();
        exp_b_q[i].delete();
        got_b_q[i].delete();
      end

      mst_aw_order_q.delete();

      for (int i = 0; i < (1 << M_AXI_ID_W); i++) begin
        dropped += mst_ar_resp_q[i].size();
        dropped += mst_b_resp_q[i].size();
        mst_ar_resp_q[i].delete();
        mst_b_resp_q[i].delete();
      end

      reset_dropped_items += dropped;
    endfunction

    function void check_src(int unsigned src, string tag);
      if (src >= NUM_REQ)
        `uvm_error(tag, $sformatf("Illegal source tag %0d", src))
    endfunction

    function void compare_addr(string tag, qos_axi_item tr, addr_track_t exp);
      if (tr.id !== exp.id)
        `uvm_error(tag, $sformatf("ID mismatch src%0d got 0x%0h expected 0x%0h",
                                  tr.src, tr.id, exp.id))

      if (tr.addr !== exp.addr)
        `uvm_error(tag, $sformatf("ADDR mismatch src%0d got 0x%0h expected 0x%0h",
                                  tr.src, tr.addr, exp.addr))

      if (tr.len !== exp.len)
        `uvm_error(tag, $sformatf("LEN mismatch src%0d got %0d expected %0d",
                                  tr.src, tr.len, exp.len))

      if (tr.size !== exp.size)
        `uvm_error(tag, $sformatf("SIZE mismatch src%0d got 0x%0h expected 0x%0h",
                                  tr.src, tr.size, exp.size))

      if (tr.burst !== exp.burst)
        `uvm_error(tag, $sformatf("BURST mismatch src%0d got 0x%0h expected 0x%0h",
                                  tr.src, tr.burst, exp.burst))

      if (tr.lock !== exp.lock)
        `uvm_error(tag, $sformatf("LOCK mismatch src%0d got 0x%0h expected 0x%0h",
                                  tr.src, tr.lock, exp.lock))

      if (tr.cache !== exp.cache)
        `uvm_error(tag, $sformatf("CACHE mismatch src%0d got 0x%0h expected 0x%0h",
                                  tr.src, tr.cache, exp.cache))

      if (tr.prot !== exp.prot)
        `uvm_error(tag, $sformatf("PROT mismatch src%0d got 0x%0h expected 0x%0h",
                                  tr.src, tr.prot, exp.prot))

      if (tr.qos !== exp.qos)
        `uvm_error(tag, $sformatf("QOS mismatch src%0d got 0x%0h expected 0x%0h",
                                  tr.src, tr.qos, exp.qos))

      sideband_checks++;
      sideband_size_seen[tr.size] = 1'b1;
      sideband_burst_seen[tr.burst] = 1'b1;
      sideband_lock_seen[tr.lock] = 1'b1;
      sideband_cache_zero_seen |= (tr.cache == 0);
      sideband_cache_nonzero_seen |= (tr.cache != 0);
      sideband_prot_zero_seen |= (tr.prot == 0);
      sideband_prot_nonzero_seen |= (tr.prot != 0);
      sideband_qos_zero_seen |= (tr.qos == 0);
      sideband_qos_nonzero_seen |= (tr.qos != 0);
    endfunction

    function void compare_r(int unsigned src);
      r_track_t exp;
      r_track_t got;

      while (exp_r_q[src].size() != 0 && got_r_q[src].size() != 0) begin
        exp = exp_r_q[src].pop_front();
        got = got_r_q[src].pop_front();

        if (got.id !== exp.id)
          `uvm_error("SB_R_ROUTE", $sformatf("RID mismatch src%0d got 0x%0h expected 0x%0h",
                                            src, got.id, exp.id))

        if (got.data !== exp.data)
          `uvm_error("SB_R_ROUTE", $sformatf("RDATA mismatch src%0d got 0x%0h expected 0x%0h",
                                            src, got.data, exp.data))

        if (got.last !== exp.last)
          `uvm_error("SB_R_ROUTE", $sformatf("RLAST mismatch src%0d got %0b expected %0b",
                                            src, got.last, exp.last))

        if (got.resp !== exp.resp)
          `uvm_error("SB_R_ROUTE", $sformatf("RRESP mismatch src%0d got 0x%0h expected 0x%0h",
                                            src, got.resp, exp.resp))

        if (exp.resp[1])
          r_error_route_checks++;

        r_route_checks++;
      end
    endfunction

    function void compare_b(int unsigned src);
      b_track_t exp;
      b_track_t got;

      while (exp_b_q[src].size() != 0 && got_b_q[src].size() != 0) begin
        exp = exp_b_q[src].pop_front();
        got = got_b_q[src].pop_front();

        if (got.id !== exp.id)
          `uvm_error("SB_B_ROUTE", $sformatf("BID mismatch src%0d got 0x%0h expected 0x%0h",
                                            src, got.id, exp.id))

        if (got.resp !== exp.resp)
          `uvm_error("SB_B_ROUTE", $sformatf("BRESP mismatch src%0d got 0x%0h expected 0x%0h",
                                            src, got.resp, exp.resp))

        if (exp.resp[1])
          b_error_route_checks++;

        b_route_checks++;
      end
    endfunction

    function void handle_source_event(qos_axi_item tr);
      addr_track_t addr_exp;
      w_track_t    w_exp;
      r_track_t    r_item;
      b_track_t    b_item;

      if (tr.side == QOS_SIDE_SRC) begin
        check_src(tr.src, "SB_SRC");

        case (tr.kind)
          QOS_AR: begin
            addr_exp.src  = tr.src;
            addr_exp.id   = tr.id;
            addr_exp.addr = tr.addr;
            addr_exp.len  = tr.len;
            addr_exp.size = tr.size;
            addr_exp.burst = tr.burst;
            addr_exp.lock = tr.lock;
            addr_exp.cache = tr.cache;
            addr_exp.prot = tr.prot;
            addr_exp.qos = tr.qos;
            src_ar_q[tr.src].push_back(addr_exp);
          end

          QOS_AW: begin
            addr_exp.src  = tr.src;
            addr_exp.id   = tr.id;
            addr_exp.addr = tr.addr;
            addr_exp.len  = tr.len;
            addr_exp.size = tr.size;
            addr_exp.burst = tr.burst;
            addr_exp.lock = tr.lock;
            addr_exp.cache = tr.cache;
            addr_exp.prot = tr.prot;
            addr_exp.qos = tr.qos;
            src_aw_q[tr.src].push_back(addr_exp);
          end

          QOS_W: begin
            w_exp.data = tr.data;
            w_exp.strb = tr.strb;
            w_exp.last = tr.last;
            src_w_q[tr.src].push_back(w_exp);
          end

          QOS_R: begin
            r_item.id   = tr.id;
            r_item.data = tr.data;
            r_item.last = tr.last;
            r_item.resp = tr.resp;
            got_r_q[tr.src].push_back(r_item);
            compare_r(tr.src);
          end

          QOS_B: begin
            b_item.id   = tr.id;
            b_item.resp = tr.resp;
            got_b_q[tr.src].push_back(b_item);
            compare_b(tr.src);
          end

          default: ;
        endcase
      end
    endfunction

    function void handle_master_event(qos_axi_item tr);
      addr_track_t addr_exp;
      aw_track_t   aw_exp;
      ar_resp_track_t ar_resp;
      b_resp_track_t b_resp;
      w_track_t    w_exp;
      r_track_t    r_item;
      b_track_t    b_item;
      bit          exp_last;

      if (tr.side == QOS_SIDE_MST) begin
        check_src(tr.src, "SB_MST_TAG");

        case (tr.kind)
          QOS_AR: begin
            if (src_ar_q[tr.src].size() == 0) begin
              `uvm_error("SB_AR", $sformatf("Master AR src%0d has no accepted source AR", tr.src))
            end else begin
              addr_exp = src_ar_q[tr.src].pop_front();
              compare_addr("SB_AR", tr, addr_exp);

              ar_resp.beats_left = tr.len + 1;
              mst_ar_resp_q[tr.mid].push_back(ar_resp);

              ar_checks++;
            end
          end

          QOS_AW: begin
            if (src_aw_q[tr.src].size() == 0) begin
              `uvm_error("SB_AW", $sformatf("Master AW src%0d has no accepted source AW", tr.src))
            end else begin
              addr_exp = src_aw_q[tr.src].pop_front();
              compare_addr("SB_AW", tr, addr_exp);

              aw_exp.src        = tr.src;
              aw_exp.id         = tr.id;
              aw_exp.beats_left = tr.len + 1;
              mst_aw_order_q.push_back(aw_exp);

              b_resp.id = tr.id;
              mst_b_resp_q[tr.mid].push_back(b_resp);

              aw_checks++;
            end
          end

          QOS_W: begin
            if (mst_aw_order_q.size() == 0) begin
              `uvm_error("SB_W_ORDER", "Master W accepted before any master AW")
            end else begin
              aw_exp = mst_aw_order_q[0];

              if (src_w_q[aw_exp.src].size() == 0) begin
                `uvm_error("SB_W_DATA", $sformatf("Master W has no source W beat for src%0d", aw_exp.src))
              end else begin
                w_exp = src_w_q[aw_exp.src].pop_front();

                if (tr.data !== w_exp.data)
                  `uvm_error("SB_W_DATA", $sformatf("WDATA mismatch src%0d got 0x%0h expected 0x%0h",
                                                    aw_exp.src, tr.data, w_exp.data))

                if (tr.strb !== w_exp.strb)
                  `uvm_error("SB_W_DATA", $sformatf("WSTRB mismatch src%0d got 0x%0h expected 0x%0h",
                                                    aw_exp.src, tr.strb, w_exp.strb))

                exp_last = (aw_exp.beats_left == 1);

                if (tr.last !== exp_last)
                  `uvm_error("SB_W_LAST", $sformatf("WLAST mismatch src%0d got %0b expected %0b",
                                                    aw_exp.src, tr.last, exp_last))

                if (w_exp.last !== exp_last)
                  `uvm_error("SB_W_LAST", $sformatf("Source WLAST mismatch src%0d got %0b expected %0b",
                                                    aw_exp.src, w_exp.last, exp_last))

                w_beat_checks++;

                mst_aw_order_q[0].beats_left--;

                if (mst_aw_order_q[0].beats_left == 0)
                  void'(mst_aw_order_q.pop_front());
              end
            end
          end

          QOS_R: begin
            if (mst_ar_resp_q[tr.mid].size() == 0) begin
              `uvm_error("SB_R_LAST",
                $sformatf("Master R ID 0x%0h has no accepted AR", tr.mid))
            end else begin
              exp_last = (mst_ar_resp_q[tr.mid][0].beats_left == 1);

              if (tr.last !== exp_last)
                `uvm_error("SB_R_LAST",
                  $sformatf("RLAST mismatch ID 0x%0h got %0b expected %0b",
                            tr.mid, tr.last, exp_last))

              mst_ar_resp_q[tr.mid][0].beats_left--;

              if (mst_ar_resp_q[tr.mid][0].beats_left == 0) begin
                void'(mst_ar_resp_q[tr.mid].pop_front());
                r_burst_checks++;
              end
            end

            r_item.id   = tr.id;
            r_item.data = tr.data;
            r_item.last = tr.last;
            r_item.resp = tr.resp;
            exp_r_q[tr.src].push_back(r_item);
            compare_r(tr.src);
          end

          QOS_B: begin
            if (mst_b_resp_q[tr.mid].size() == 0) begin
              `uvm_error("SB_B_RESP",
                $sformatf("Master B ID 0x%0h has no accepted AW", tr.mid))
            end else begin
              b_resp = mst_b_resp_q[tr.mid].pop_front();

              if (tr.id !== b_resp.id)
                `uvm_error("SB_B_RESP",
                  $sformatf("BID mismatch got 0x%0h expected 0x%0h",
                            tr.id, b_resp.id))
            end

            b_item.id   = tr.id;
            b_item.resp = tr.resp;
            exp_b_q[tr.src].push_back(b_item);
            compare_b(tr.src);
          end

          default: ;
        endcase
      end
    endfunction

    function void write_mon(qos_axi_item tr);
      handle_source_event(tr);
      handle_master_event(tr);
    endfunction

    function bit is_drained();
      for (int i = 0; i < NUM_REQ; i++) begin
        if (src_ar_q[i].size() != 0) return 1'b0;
        if (src_aw_q[i].size() != 0) return 1'b0;
        if (src_w_q[i].size()  != 0) return 1'b0;

        if (exp_r_q[i].size() != 0) return 1'b0;
        if (got_r_q[i].size() != 0) return 1'b0;
        if (exp_b_q[i].size() != 0) return 1'b0;
        if (got_b_q[i].size() != 0) return 1'b0;
      end

      if (mst_aw_order_q.size() != 0) return 1'b0;

      for (int i = 0; i < (1 << M_AXI_ID_W); i++) begin
        if (mst_ar_resp_q[i].size() != 0) return 1'b0;
        if (mst_b_resp_q[i].size() != 0) return 1'b0;
      end

      return 1'b1;
    endfunction

    function void check_phase(uvm_phase phase);
      int unsigned pending_src_ar;
      int unsigned pending_mst_ar;
      int unsigned pending_mst_ar_ids;

      pending_src_ar     = 0;
      pending_mst_ar     = 0;
      pending_mst_ar_ids = 0;

      for (int i = 0; i < NUM_REQ; i++) begin
        if (src_ar_q[i].size() != 0) begin
          if (!allow_pending_ar_at_end)
            `uvm_error("SB_DRAIN", $sformatf("src_ar_q[%0d] not drained: %0d", i, src_ar_q[i].size()))
          else
            pending_src_ar += src_ar_q[i].size();
        end

        if (src_aw_q[i].size() != 0)
          `uvm_error("SB_DRAIN", $sformatf("src_aw_q[%0d] not drained: %0d", i, src_aw_q[i].size()))

        if (src_w_q[i].size() != 0)
          `uvm_error("SB_DRAIN", $sformatf("src_w_q[%0d] not drained: %0d", i, src_w_q[i].size()))

        if (exp_r_q[i].size() != 0 || got_r_q[i].size() != 0)
          `uvm_error("SB_DRAIN", $sformatf("R route queues not drained src%0d exp=%0d got=%0d",
                                            i, exp_r_q[i].size(), got_r_q[i].size()))

        if (exp_b_q[i].size() != 0 || got_b_q[i].size() != 0)
          `uvm_error("SB_DRAIN", $sformatf("B route queues not drained src%0d exp=%0d got=%0d",
                                            i, exp_b_q[i].size(), got_b_q[i].size()))
      end

      if (mst_aw_order_q.size() != 0)
        `uvm_error("SB_DRAIN", $sformatf("Master AW/W order queue not drained: %0d",
                                          mst_aw_order_q.size()))

      for (int i = 0; i < (1 << M_AXI_ID_W); i++) begin
        if (mst_ar_resp_q[i].size() != 0) begin
          if (!allow_pending_ar_at_end)
            `uvm_error("SB_DRAIN",
              $sformatf("Master AR response queue ID 0x%0h not drained: %0d",
                        i, mst_ar_resp_q[i].size()))
          else begin
            pending_mst_ar += mst_ar_resp_q[i].size();
            pending_mst_ar_ids++;
          end
        end

        if (mst_b_resp_q[i].size() != 0)
          `uvm_error("SB_DRAIN",
            $sformatf("Master B response queue ID 0x%0h not drained: %0d",
                      i, mst_b_resp_q[i].size()))
      end

      if (allow_pending_ar_at_end && ((pending_src_ar != 0) || (pending_mst_ar != 0)))
        `uvm_info("SB_DRAIN",
          $sformatf({"Timed fairness window left %0d source AR entries and %0d ",
                     "master AR responses pending across %0d IDs"},
                    pending_src_ar, pending_mst_ar, pending_mst_ar_ids), UVM_LOW)
    endfunction

    function void report_phase(uvm_phase phase);
      super.report_phase(phase);

      `uvm_info("SB_SUMMARY",
                $sformatf({"AR=%0d AW=%0d W_BEATS=%0d R_ROUTE=%0d R_ERR=%0d ",
                           "R_BURSTS=%0d B_ROUTE=%0d B_ERR=%0d SIDEBAND=%0d ",
                           "RESET_FLUSH=%0d RESET_DROPPED=%0d"},
                          ar_checks,
                          aw_checks,
                          w_beat_checks,
                          r_route_checks,
                          r_error_route_checks,
                          r_burst_checks,
                          b_route_checks,
                          b_error_route_checks,
                          sideband_checks,
                          reset_flush_count,
                          reset_dropped_items),
                UVM_LOW)
    endfunction
  endclass
