interface qos_axi_if #(
  parameter int unsigned NUM_REQ        = 4,
  parameter int unsigned FIFO_DEPTH     = 8,
  parameter int unsigned WEIGHT_W       = 4,
  parameter int unsigned AGE_W          = 8,
  parameter int unsigned COUNTER_W      = 32,
  parameter int unsigned CSR_ADDR_W     = 8,
  parameter int unsigned CSR_DATA_W     = 32,
  parameter int unsigned AXI_ADDR_W     = 32,
  parameter int unsigned AXI_DATA_W     = 32,
  parameter int unsigned AXI_ID_W       = 4,
  parameter int unsigned AXI_LEN_W      = 8,
  parameter int unsigned AXI_SIZE_W     = 3,
  parameter int unsigned AXI_BURST_W    = 2,
  parameter int unsigned AXI_LOCK_W     = 1,
  parameter int unsigned AXI_CACHE_W    = 4,
  parameter int unsigned AXI_PROT_W     = 3,
  parameter int unsigned AXI_QOS_W      = 4,
  parameter int unsigned AXI_RESP_W     = 2,
  parameter int unsigned REQ_IDX_W      = (NUM_REQ <= 1) ? 1 : $clog2(NUM_REQ),
  parameter int unsigned AXI_STRB_W     = AXI_DATA_W / 8,
  parameter int unsigned M_AXI_ID_W     = AXI_ID_W + REQ_IDX_W
)(
  input logic clk
);

  logic                         rst_n;

  logic [CSR_ADDR_W-1:0]        S_AXIL_AWADDR;
  logic                         S_AXIL_AWVALID;
  logic                         S_AXIL_AWREADY;
  logic [CSR_DATA_W-1:0]        S_AXIL_WDATA;
  logic [(CSR_DATA_W/8)-1:0]    S_AXIL_WSTRB;
  logic                         S_AXIL_WVALID;
  logic                         S_AXIL_WREADY;
  logic [1:0]                   S_AXIL_BRESP;
  logic                         S_AXIL_BVALID;
  logic                         S_AXIL_BREADY;
  logic [CSR_ADDR_W-1:0]        S_AXIL_ARADDR;
  logic                         S_AXIL_ARVALID;
  logic                         S_AXIL_ARREADY;
  logic [CSR_DATA_W-1:0]        S_AXIL_RDATA;
  logic [1:0]                   S_AXIL_RRESP;
  logic                         S_AXIL_RVALID;
  logic                         S_AXIL_RREADY;

  logic [AXI_ID_W-1:0]          S_AXI_ARID     [NUM_REQ];
  logic [AXI_ADDR_W-1:0]        S_AXI_ARADDR   [NUM_REQ];
  logic [AXI_LEN_W-1:0]         S_AXI_ARLEN    [NUM_REQ];
  logic [AXI_SIZE_W-1:0]        S_AXI_ARSIZE   [NUM_REQ];
  logic [AXI_BURST_W-1:0]       S_AXI_ARBURST  [NUM_REQ];
  logic [AXI_LOCK_W-1:0]        S_AXI_ARLOCK   [NUM_REQ];
  logic [AXI_CACHE_W-1:0]       S_AXI_ARCACHE  [NUM_REQ];
  logic [AXI_PROT_W-1:0]        S_AXI_ARPROT   [NUM_REQ];
  logic [AXI_QOS_W-1:0]         S_AXI_ARQOS    [NUM_REQ];
  logic [NUM_REQ-1:0]           S_AXI_ARVALID;
  logic [NUM_REQ-1:0]           S_AXI_ARREADY;

  logic [AXI_ID_W-1:0]          S_AXI_RID      [NUM_REQ];
  logic [AXI_DATA_W-1:0]        S_AXI_RDATA    [NUM_REQ];
  logic [AXI_RESP_W-1:0]        S_AXI_RRESP    [NUM_REQ];
  logic [NUM_REQ-1:0]           S_AXI_RLAST;
  logic [NUM_REQ-1:0]           S_AXI_RVALID;
  logic [NUM_REQ-1:0]           S_AXI_RREADY;

  logic [AXI_ID_W-1:0]          S_AXI_AWID     [NUM_REQ];
  logic [AXI_ADDR_W-1:0]        S_AXI_AWADDR   [NUM_REQ];
  logic [AXI_LEN_W-1:0]         S_AXI_AWLEN    [NUM_REQ];
  logic [AXI_SIZE_W-1:0]        S_AXI_AWSIZE   [NUM_REQ];
  logic [AXI_BURST_W-1:0]       S_AXI_AWBURST  [NUM_REQ];
  logic [AXI_LOCK_W-1:0]        S_AXI_AWLOCK   [NUM_REQ];
  logic [AXI_CACHE_W-1:0]       S_AXI_AWCACHE  [NUM_REQ];
  logic [AXI_PROT_W-1:0]        S_AXI_AWPROT   [NUM_REQ];
  logic [AXI_QOS_W-1:0]         S_AXI_AWQOS    [NUM_REQ];
  logic [NUM_REQ-1:0]           S_AXI_AWVALID;
  logic [NUM_REQ-1:0]           S_AXI_AWREADY;

  logic [AXI_DATA_W-1:0]        S_AXI_WDATA    [NUM_REQ];
  logic [AXI_STRB_W-1:0]        S_AXI_WSTRB    [NUM_REQ];
  logic [NUM_REQ-1:0]           S_AXI_WLAST;
  logic [NUM_REQ-1:0]           S_AXI_WVALID;
  logic [NUM_REQ-1:0]           S_AXI_WREADY;

  logic [AXI_ID_W-1:0]          S_AXI_BID      [NUM_REQ];
  logic [AXI_RESP_W-1:0]        S_AXI_BRESP    [NUM_REQ];
  logic [NUM_REQ-1:0]           S_AXI_BVALID;
  logic [NUM_REQ-1:0]           S_AXI_BREADY;

  logic [M_AXI_ID_W-1:0]        M_AXI_ARID;
  logic [AXI_ADDR_W-1:0]        M_AXI_ARADDR;
  logic [AXI_LEN_W-1:0]         M_AXI_ARLEN;
  logic [AXI_SIZE_W-1:0]        M_AXI_ARSIZE;
  logic [AXI_BURST_W-1:0]       M_AXI_ARBURST;
  logic [AXI_LOCK_W-1:0]        M_AXI_ARLOCK;
  logic [AXI_CACHE_W-1:0]       M_AXI_ARCACHE;
  logic [AXI_PROT_W-1:0]        M_AXI_ARPROT;
  logic [AXI_QOS_W-1:0]         M_AXI_ARQOS;
  logic                         M_AXI_ARVALID;
  logic                         M_AXI_ARREADY;

  logic [M_AXI_ID_W-1:0]        M_AXI_RID;
  logic [AXI_DATA_W-1:0]        M_AXI_RDATA;
  logic [AXI_RESP_W-1:0]        M_AXI_RRESP;
  logic                         M_AXI_RLAST;
  logic                         M_AXI_RVALID;
  logic                         M_AXI_RREADY;

  logic [M_AXI_ID_W-1:0]        M_AXI_AWID;
  logic [AXI_ADDR_W-1:0]        M_AXI_AWADDR;
  logic [AXI_LEN_W-1:0]         M_AXI_AWLEN;
  logic [AXI_SIZE_W-1:0]        M_AXI_AWSIZE;
  logic [AXI_BURST_W-1:0]       M_AXI_AWBURST;
  logic [AXI_LOCK_W-1:0]        M_AXI_AWLOCK;
  logic [AXI_CACHE_W-1:0]       M_AXI_AWCACHE;
  logic [AXI_PROT_W-1:0]        M_AXI_AWPROT;
  logic [AXI_QOS_W-1:0]         M_AXI_AWQOS;
  logic                         M_AXI_AWVALID;
  logic                         M_AXI_AWREADY;

  logic [AXI_DATA_W-1:0]        M_AXI_WDATA;
  logic [AXI_STRB_W-1:0]        M_AXI_WSTRB;
  logic                         M_AXI_WLAST;
  logic                         M_AXI_WVALID;
  logic                         M_AXI_WREADY;

  logic [M_AXI_ID_W-1:0]        M_AXI_BID;
  logic [AXI_RESP_W-1:0]        M_AXI_BRESP;
  logic                         M_AXI_BVALID;
  logic                         M_AXI_BREADY;

  clocking source_drv_cb @(posedge clk);
    default input #1step output #0;

    output S_AXI_ARID, S_AXI_ARADDR, S_AXI_ARLEN, S_AXI_ARSIZE;
    output S_AXI_ARBURST, S_AXI_ARLOCK, S_AXI_ARCACHE, S_AXI_ARPROT;
    output S_AXI_ARQOS, S_AXI_ARVALID;
    input  S_AXI_ARREADY;

    output S_AXI_AWID, S_AXI_AWADDR, S_AXI_AWLEN, S_AXI_AWSIZE;
    output S_AXI_AWBURST, S_AXI_AWLOCK, S_AXI_AWCACHE, S_AXI_AWPROT;
    output S_AXI_AWQOS, S_AXI_AWVALID;
    input  S_AXI_AWREADY;

    output S_AXI_WDATA, S_AXI_WSTRB, S_AXI_WLAST, S_AXI_WVALID;
    input  S_AXI_WREADY;

    input  S_AXI_RID, S_AXI_RDATA, S_AXI_RRESP, S_AXI_RLAST, S_AXI_RVALID;
    output S_AXI_RREADY;
    input  S_AXI_BID, S_AXI_BRESP, S_AXI_BVALID;
    output S_AXI_BREADY;
  endclocking

  clocking source_mon_cb @(posedge clk);
    default input #1step;

    input S_AXI_ARID, S_AXI_ARADDR, S_AXI_ARLEN, S_AXI_ARSIZE;
    input S_AXI_ARBURST, S_AXI_ARLOCK, S_AXI_ARCACHE, S_AXI_ARPROT;
    input S_AXI_ARQOS, S_AXI_ARVALID, S_AXI_ARREADY;

    input S_AXI_AWID, S_AXI_AWADDR, S_AXI_AWLEN, S_AXI_AWSIZE;
    input S_AXI_AWBURST, S_AXI_AWLOCK, S_AXI_AWCACHE, S_AXI_AWPROT;
    input S_AXI_AWQOS, S_AXI_AWVALID, S_AXI_AWREADY;

    input S_AXI_WDATA, S_AXI_WSTRB, S_AXI_WLAST, S_AXI_WVALID, S_AXI_WREADY;
    input S_AXI_RID, S_AXI_RDATA, S_AXI_RRESP, S_AXI_RLAST, S_AXI_RVALID, S_AXI_RREADY;
    input S_AXI_BID, S_AXI_BRESP, S_AXI_BVALID, S_AXI_BREADY;
  endclocking

  clocking csr_drv_cb @(posedge clk);
    default input #1step output #0;

    output S_AXIL_AWADDR, S_AXIL_AWVALID;
    input  S_AXIL_AWREADY;
    output S_AXIL_WDATA, S_AXIL_WSTRB, S_AXIL_WVALID;
    input  S_AXIL_WREADY;
    input  S_AXIL_BRESP, S_AXIL_BVALID;
    output S_AXIL_BREADY;

    output S_AXIL_ARADDR, S_AXIL_ARVALID;
    input  S_AXIL_ARREADY;
    input  S_AXIL_RDATA, S_AXIL_RRESP, S_AXIL_RVALID;
    output S_AXIL_RREADY;
  endclocking

  clocking csr_mon_cb @(posedge clk);
    default input #1step;

    input S_AXIL_AWADDR, S_AXIL_AWVALID, S_AXIL_AWREADY;
    input S_AXIL_WDATA, S_AXIL_WSTRB, S_AXIL_WVALID, S_AXIL_WREADY;
    input S_AXIL_BRESP, S_AXIL_BVALID, S_AXIL_BREADY;
    input S_AXIL_ARADDR, S_AXIL_ARVALID, S_AXIL_ARREADY;
    input S_AXIL_RDATA, S_AXIL_RRESP, S_AXIL_RVALID, S_AXIL_RREADY;
  endclocking

  clocking master_rsp_cb @(posedge clk);
    default input #1step output #0;

    input  M_AXI_ARID, M_AXI_ARADDR, M_AXI_ARLEN, M_AXI_ARSIZE;
    input  M_AXI_ARBURST, M_AXI_ARLOCK, M_AXI_ARCACHE, M_AXI_ARPROT;
    input  M_AXI_ARQOS, M_AXI_ARVALID;
    output M_AXI_ARREADY;

    output M_AXI_RID, M_AXI_RDATA, M_AXI_RRESP, M_AXI_RLAST, M_AXI_RVALID;
    input  M_AXI_RREADY;

    input  M_AXI_AWID, M_AXI_AWADDR, M_AXI_AWLEN, M_AXI_AWSIZE;
    input  M_AXI_AWBURST, M_AXI_AWLOCK, M_AXI_AWCACHE, M_AXI_AWPROT;
    input  M_AXI_AWQOS, M_AXI_AWVALID;
    output M_AXI_AWREADY;

    input  M_AXI_WDATA, M_AXI_WSTRB, M_AXI_WLAST, M_AXI_WVALID;
    output M_AXI_WREADY;

    output M_AXI_BID, M_AXI_BRESP, M_AXI_BVALID;
    input  M_AXI_BREADY;
  endclocking

  clocking master_mon_cb @(posedge clk);
    default input #1step;

    input M_AXI_ARID, M_AXI_ARADDR, M_AXI_ARLEN, M_AXI_ARSIZE;
    input M_AXI_ARBURST, M_AXI_ARLOCK, M_AXI_ARCACHE, M_AXI_ARPROT;
    input M_AXI_ARQOS, M_AXI_ARVALID, M_AXI_ARREADY;
    input M_AXI_RID, M_AXI_RDATA, M_AXI_RRESP, M_AXI_RLAST, M_AXI_RVALID, M_AXI_RREADY;

    input M_AXI_AWID, M_AXI_AWADDR, M_AXI_AWLEN, M_AXI_AWSIZE;
    input M_AXI_AWBURST, M_AXI_AWLOCK, M_AXI_AWCACHE, M_AXI_AWPROT;
    input M_AXI_AWQOS, M_AXI_AWVALID, M_AXI_AWREADY;
    input M_AXI_WDATA, M_AXI_WSTRB, M_AXI_WLAST, M_AXI_WVALID, M_AXI_WREADY;
    input M_AXI_BID, M_AXI_BRESP, M_AXI_BVALID, M_AXI_BREADY;
  endclocking

  modport source_driver_mp  (clocking source_drv_cb, input rst_n);
  modport source_monitor_mp (clocking source_mon_cb, input rst_n);
  modport csr_driver_mp     (clocking csr_drv_cb, input rst_n);
  modport csr_monitor_mp    (clocking csr_mon_cb, input rst_n);
  modport master_responder_mp (clocking master_rsp_cb, input rst_n);
  modport master_monitor_mp (clocking master_mon_cb, input rst_n);
  modport reset_mp          (input clk, output rst_n);

endinterface : qos_axi_if
