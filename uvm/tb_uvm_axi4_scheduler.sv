`timescale 1ns/1ps

module tb_uvm_axi4_scheduler;
  import uvm_pkg::*;
  import qos_uvm_pkg::*;

  localparam int unsigned NUM_REQ_TB        = 4;
  localparam int unsigned FIFO_DEPTH_TB     = 8;
  localparam int unsigned WEIGHT_W_TB       = 4;
  localparam int unsigned AGE_W_TB          = 8;
  localparam int unsigned COUNTER_W_TB      = 32;
  localparam int unsigned CSR_ADDR_W_TB     = 8;
  localparam int unsigned CSR_DATA_W_TB     = 32;
  localparam int unsigned AXI_ADDR_W_TB     = 32;
  localparam int unsigned AXI_DATA_W_TB     = 32;
  localparam int unsigned AXI_ID_W_TB       = 4;
  localparam int unsigned AXI_LEN_W_TB      = 8;
  localparam int unsigned AXI_SIZE_W_TB     = 3;
  localparam int unsigned AXI_BURST_W_TB    = 2;
  localparam int unsigned AXI_LOCK_W_TB     = 1;
  localparam int unsigned AXI_CACHE_W_TB    = 4;
  localparam int unsigned AXI_PROT_W_TB     = 3;
  localparam int unsigned AXI_QOS_W_TB      = 4;
  localparam int unsigned AXI_RESP_W_TB     = 2;
  localparam int unsigned REQ_IDX_W_TB      = 2;
  localparam int unsigned AXI_STRB_W_TB     = AXI_DATA_W_TB / 8;
  localparam int unsigned M_AXI_ID_W_TB     = AXI_ID_W_TB + REQ_IDX_W_TB;
  localparam int unsigned AW_ORDER_DEPTH_TB = 16;

  logic clk;

  qos_axi_if #(
    .NUM_REQ(NUM_REQ_TB), .FIFO_DEPTH(FIFO_DEPTH_TB), .WEIGHT_W(WEIGHT_W_TB), .AGE_W(AGE_W_TB),
    .COUNTER_W(COUNTER_W_TB), .CSR_ADDR_W(CSR_ADDR_W_TB), .CSR_DATA_W(CSR_DATA_W_TB),
    .AXI_ADDR_W(AXI_ADDR_W_TB), .AXI_DATA_W(AXI_DATA_W_TB), .AXI_ID_W(AXI_ID_W_TB),
    .AXI_LEN_W(AXI_LEN_W_TB), .AXI_SIZE_W(AXI_SIZE_W_TB), .AXI_BURST_W(AXI_BURST_W_TB),
    .AXI_LOCK_W(AXI_LOCK_W_TB), .AXI_CACHE_W(AXI_CACHE_W_TB), .AXI_PROT_W(AXI_PROT_W_TB),
    .AXI_QOS_W(AXI_QOS_W_TB), .AXI_RESP_W(AXI_RESP_W_TB), .REQ_IDX_W(REQ_IDX_W_TB),
    .AXI_STRB_W(AXI_STRB_W_TB), .M_AXI_ID_W(M_AXI_ID_W_TB)
  ) vif (.clk(clk));

  initial begin
    clk = 1'b0;
    forever #4 clk = ~clk;
  end

  initial begin
    vif.rst_n = 1'b0;
    repeat (8) @(posedge clk);
    vif.rst_n = 1'b1;
  end

  axi4_scheduler_top #(
    .NUM_REQ(NUM_REQ_TB),
    .FIFO_DEPTH(FIFO_DEPTH_TB),
    .WEIGHT_W(WEIGHT_W_TB),
    .AGE_W(AGE_W_TB),
    .COUNTER_W(COUNTER_W_TB),
    .CSR_ADDR_W(CSR_ADDR_W_TB),
    .CSR_DATA_W(CSR_DATA_W_TB),
    .AXI_ADDR_W(AXI_ADDR_W_TB),
    .AXI_DATA_W(AXI_DATA_W_TB),
    .AXI_ID_W(AXI_ID_W_TB),
    .AXI_LEN_W(AXI_LEN_W_TB),
    .AXI_SIZE_W(AXI_SIZE_W_TB),
    .AXI_BURST_W(AXI_BURST_W_TB),
    .AXI_LOCK_W(AXI_LOCK_W_TB),
    .AXI_CACHE_W(AXI_CACHE_W_TB),
    .AXI_PROT_W(AXI_PROT_W_TB),
    .AXI_QOS_W(AXI_QOS_W_TB),
    .AXI_RESP_W(AXI_RESP_W_TB),
    .REQ_IDX_W(REQ_IDX_W_TB),
    .AXI_STRB_W(AXI_STRB_W_TB),
    .M_AXI_ID_W(M_AXI_ID_W_TB),
    .AW_ORDER_DEPTH(AW_ORDER_DEPTH_TB)
  ) dut (
    .clk(clk), .rst_n(vif.rst_n),
    .S_AXIL_AWADDR(vif.S_AXIL_AWADDR), .S_AXIL_AWVALID(vif.S_AXIL_AWVALID), .S_AXIL_AWREADY(vif.S_AXIL_AWREADY),
    .S_AXIL_WDATA(vif.S_AXIL_WDATA), .S_AXIL_WSTRB(vif.S_AXIL_WSTRB), .S_AXIL_WVALID(vif.S_AXIL_WVALID), .S_AXIL_WREADY(vif.S_AXIL_WREADY),
    .S_AXIL_BRESP(vif.S_AXIL_BRESP), .S_AXIL_BVALID(vif.S_AXIL_BVALID), .S_AXIL_BREADY(vif.S_AXIL_BREADY),
    .S_AXIL_ARADDR(vif.S_AXIL_ARADDR), .S_AXIL_ARVALID(vif.S_AXIL_ARVALID), .S_AXIL_ARREADY(vif.S_AXIL_ARREADY),
    .S_AXIL_RDATA(vif.S_AXIL_RDATA), .S_AXIL_RRESP(vif.S_AXIL_RRESP), .S_AXIL_RVALID(vif.S_AXIL_RVALID), .S_AXIL_RREADY(vif.S_AXIL_RREADY),
    .S_AXI_ARID(vif.S_AXI_ARID), .S_AXI_ARADDR(vif.S_AXI_ARADDR), .S_AXI_ARLEN(vif.S_AXI_ARLEN), .S_AXI_ARSIZE(vif.S_AXI_ARSIZE),
    .S_AXI_ARBURST(vif.S_AXI_ARBURST), .S_AXI_ARLOCK(vif.S_AXI_ARLOCK), .S_AXI_ARCACHE(vif.S_AXI_ARCACHE), .S_AXI_ARPROT(vif.S_AXI_ARPROT),
    .S_AXI_ARQOS(vif.S_AXI_ARQOS), .S_AXI_ARVALID(vif.S_AXI_ARVALID), .S_AXI_ARREADY(vif.S_AXI_ARREADY),
    .S_AXI_RID(vif.S_AXI_RID), .S_AXI_RDATA(vif.S_AXI_RDATA), .S_AXI_RRESP(vif.S_AXI_RRESP), .S_AXI_RLAST(vif.S_AXI_RLAST),
    .S_AXI_RVALID(vif.S_AXI_RVALID), .S_AXI_RREADY(vif.S_AXI_RREADY),
    .S_AXI_AWID(vif.S_AXI_AWID), .S_AXI_AWADDR(vif.S_AXI_AWADDR), .S_AXI_AWLEN(vif.S_AXI_AWLEN), .S_AXI_AWSIZE(vif.S_AXI_AWSIZE),
    .S_AXI_AWBURST(vif.S_AXI_AWBURST), .S_AXI_AWLOCK(vif.S_AXI_AWLOCK), .S_AXI_AWCACHE(vif.S_AXI_AWCACHE), .S_AXI_AWPROT(vif.S_AXI_AWPROT),
    .S_AXI_AWQOS(vif.S_AXI_AWQOS), .S_AXI_AWVALID(vif.S_AXI_AWVALID), .S_AXI_AWREADY(vif.S_AXI_AWREADY),
    .S_AXI_WDATA(vif.S_AXI_WDATA), .S_AXI_WSTRB(vif.S_AXI_WSTRB), .S_AXI_WLAST(vif.S_AXI_WLAST), .S_AXI_WVALID(vif.S_AXI_WVALID), .S_AXI_WREADY(vif.S_AXI_WREADY),
    .S_AXI_BID(vif.S_AXI_BID), .S_AXI_BRESP(vif.S_AXI_BRESP), .S_AXI_BVALID(vif.S_AXI_BVALID), .S_AXI_BREADY(vif.S_AXI_BREADY),
    .M_AXI_ARID(vif.M_AXI_ARID), .M_AXI_ARADDR(vif.M_AXI_ARADDR), .M_AXI_ARLEN(vif.M_AXI_ARLEN), .M_AXI_ARSIZE(vif.M_AXI_ARSIZE),
    .M_AXI_ARBURST(vif.M_AXI_ARBURST), .M_AXI_ARLOCK(vif.M_AXI_ARLOCK), .M_AXI_ARCACHE(vif.M_AXI_ARCACHE), .M_AXI_ARPROT(vif.M_AXI_ARPROT),
    .M_AXI_ARQOS(vif.M_AXI_ARQOS), .M_AXI_ARVALID(vif.M_AXI_ARVALID), .M_AXI_ARREADY(vif.M_AXI_ARREADY),
    .M_AXI_RID(vif.M_AXI_RID), .M_AXI_RDATA(vif.M_AXI_RDATA), .M_AXI_RRESP(vif.M_AXI_RRESP), .M_AXI_RLAST(vif.M_AXI_RLAST),
    .M_AXI_RVALID(vif.M_AXI_RVALID), .M_AXI_RREADY(vif.M_AXI_RREADY),
    .M_AXI_AWID(vif.M_AXI_AWID), .M_AXI_AWADDR(vif.M_AXI_AWADDR), .M_AXI_AWLEN(vif.M_AXI_AWLEN), .M_AXI_AWSIZE(vif.M_AXI_AWSIZE),
    .M_AXI_AWBURST(vif.M_AXI_AWBURST), .M_AXI_AWLOCK(vif.M_AXI_AWLOCK), .M_AXI_AWCACHE(vif.M_AXI_AWCACHE), .M_AXI_AWPROT(vif.M_AXI_AWPROT),
    .M_AXI_AWQOS(vif.M_AXI_AWQOS), .M_AXI_AWVALID(vif.M_AXI_AWVALID), .M_AXI_AWREADY(vif.M_AXI_AWREADY),
    .M_AXI_WDATA(vif.M_AXI_WDATA), .M_AXI_WSTRB(vif.M_AXI_WSTRB), .M_AXI_WLAST(vif.M_AXI_WLAST), .M_AXI_WVALID(vif.M_AXI_WVALID), .M_AXI_WREADY(vif.M_AXI_WREADY),
    .M_AXI_BID(vif.M_AXI_BID), .M_AXI_BRESP(vif.M_AXI_BRESP), .M_AXI_BVALID(vif.M_AXI_BVALID), .M_AXI_BREADY(vif.M_AXI_BREADY)
  );

  qos_axi_hold_sva u_qos_axi_hold_sva (
    .vif(vif)
  );

  initial begin
    uvm_config_db#(virtual qos_axi_if)::set(null, "uvm_test_top", "vif", vif);
    run_test();
  end

endmodule
