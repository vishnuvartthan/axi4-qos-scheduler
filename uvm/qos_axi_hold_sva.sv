module qos_axi_hold_sva #(
  parameter int unsigned NUM_REQ     = 4,
  parameter int unsigned CSR_ADDR_W  = 8,
  parameter int unsigned CSR_DATA_W  = 32,
  parameter int unsigned AXI_ADDR_W  = 32,
  parameter int unsigned AXI_DATA_W  = 32,
  parameter int unsigned AXI_ID_W    = 4,
  parameter int unsigned AXI_LEN_W   = 8,
  parameter int unsigned AXI_SIZE_W  = 3,
  parameter int unsigned AXI_BURST_W = 2,
  parameter int unsigned AXI_LOCK_W  = 1,
  parameter int unsigned AXI_CACHE_W = 4,
  parameter int unsigned AXI_PROT_W  = 3,
  parameter int unsigned AXI_QOS_W   = 4,
  parameter int unsigned AXI_RESP_W  = 2,
  parameter int unsigned REQ_IDX_W   = 2,
  parameter int unsigned AXI_STRB_W  = AXI_DATA_W / 8,
  parameter int unsigned M_AXI_ID_W  = AXI_ID_W + REQ_IDX_W
)(
  qos_axi_if vif
);

  generate
    for (genvar i = 0; i < NUM_REQ; i++) begin : g_src_hold

      a_src_ar_hold: assert property (@(posedge vif.clk) disable iff (!vif.rst_n)
        (vif.S_AXI_ARVALID[i] && !vif.S_AXI_ARREADY[i])
        |=> vif.S_AXI_ARVALID[i] &&
            $stable({vif.S_AXI_ARID[i], vif.S_AXI_ARADDR[i], vif.S_AXI_ARLEN[i],
                     vif.S_AXI_ARSIZE[i], vif.S_AXI_ARBURST[i], vif.S_AXI_ARLOCK[i],
                     vif.S_AXI_ARCACHE[i], vif.S_AXI_ARPROT[i], vif.S_AXI_ARQOS[i]}))
      else $error("S_AXI_AR changed while stalled src=%0d", i);

      a_src_aw_hold: assert property (@(posedge vif.clk) disable iff (!vif.rst_n)
        (vif.S_AXI_AWVALID[i] && !vif.S_AXI_AWREADY[i])
        |=> vif.S_AXI_AWVALID[i] &&
            $stable({vif.S_AXI_AWID[i], vif.S_AXI_AWADDR[i], vif.S_AXI_AWLEN[i],
                     vif.S_AXI_AWSIZE[i], vif.S_AXI_AWBURST[i], vif.S_AXI_AWLOCK[i],
                     vif.S_AXI_AWCACHE[i], vif.S_AXI_AWPROT[i], vif.S_AXI_AWQOS[i]}))
      else $error("S_AXI_AW changed while stalled src=%0d", i);

      a_src_w_hold: assert property (@(posedge vif.clk) disable iff (!vif.rst_n)
        (vif.S_AXI_WVALID[i] && !vif.S_AXI_WREADY[i])
        |=> vif.S_AXI_WVALID[i] &&
            $stable({vif.S_AXI_WDATA[i], vif.S_AXI_WSTRB[i], vif.S_AXI_WLAST[i]}))
      else $error("S_AXI_W changed while stalled src=%0d", i);

      a_src_r_hold: assert property (@(posedge vif.clk) disable iff (!vif.rst_n)
        (vif.S_AXI_RVALID[i] && !vif.S_AXI_RREADY[i])
        |=> vif.S_AXI_RVALID[i] &&
            $stable({vif.S_AXI_RID[i], vif.S_AXI_RDATA[i], vif.S_AXI_RRESP[i], vif.S_AXI_RLAST[i]}))
      else $error("S_AXI_R changed while stalled src=%0d", i);

      a_src_b_hold: assert property (@(posedge vif.clk) disable iff (!vif.rst_n)
        (vif.S_AXI_BVALID[i] && !vif.S_AXI_BREADY[i])
        |=> vif.S_AXI_BVALID[i] &&
            $stable({vif.S_AXI_BID[i], vif.S_AXI_BRESP[i]}))
      else $error("S_AXI_B changed while stalled src=%0d", i);

    end
  endgenerate

  a_mst_ar_hold: assert property (@(posedge vif.clk) disable iff (!vif.rst_n)
    (vif.M_AXI_ARVALID && !vif.M_AXI_ARREADY)
    |=> vif.M_AXI_ARVALID &&
        $stable({vif.M_AXI_ARID, vif.M_AXI_ARADDR, vif.M_AXI_ARLEN,
                 vif.M_AXI_ARSIZE, vif.M_AXI_ARBURST, vif.M_AXI_ARLOCK,
                 vif.M_AXI_ARCACHE, vif.M_AXI_ARPROT, vif.M_AXI_ARQOS}))
  else $error("M_AXI_AR changed while stalled");

  a_mst_aw_hold: assert property (@(posedge vif.clk) disable iff (!vif.rst_n)
    (vif.M_AXI_AWVALID && !vif.M_AXI_AWREADY)
    |=> vif.M_AXI_AWVALID &&
        $stable({vif.M_AXI_AWID, vif.M_AXI_AWADDR, vif.M_AXI_AWLEN,
                 vif.M_AXI_AWSIZE, vif.M_AXI_AWBURST, vif.M_AXI_AWLOCK,
                 vif.M_AXI_AWCACHE, vif.M_AXI_AWPROT, vif.M_AXI_AWQOS}))
  else $error("M_AXI_AW changed while stalled");

  a_mst_w_hold: assert property (@(posedge vif.clk) disable iff (!vif.rst_n)
    (vif.M_AXI_WVALID && !vif.M_AXI_WREADY)
    |=> vif.M_AXI_WVALID &&
        $stable({vif.M_AXI_WDATA, vif.M_AXI_WSTRB, vif.M_AXI_WLAST}))
  else $error("M_AXI_W changed while stalled");

  a_mst_r_hold: assert property (@(posedge vif.clk) disable iff (!vif.rst_n)
    (vif.M_AXI_RVALID && !vif.M_AXI_RREADY)
    |=> vif.M_AXI_RVALID &&
        $stable({vif.M_AXI_RID, vif.M_AXI_RDATA, vif.M_AXI_RRESP, vif.M_AXI_RLAST}))
  else $error("M_AXI_R changed while stalled");

  a_mst_b_hold: assert property (@(posedge vif.clk) disable iff (!vif.rst_n)
    (vif.M_AXI_BVALID && !vif.M_AXI_BREADY)
    |=> vif.M_AXI_BVALID &&
        $stable({vif.M_AXI_BID, vif.M_AXI_BRESP}))
  else $error("M_AXI_B changed while stalled");

endmodule
