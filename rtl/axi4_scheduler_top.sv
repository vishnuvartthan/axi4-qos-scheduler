`timescale 1ns/1ps

module axi4_scheduler_top #(
  parameter int unsigned NUM_REQ        = 4,
  parameter int unsigned FIFO_DEPTH     = 4,
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
  parameter int unsigned M_AXI_ID_W     = AXI_ID_W + REQ_IDX_W,
  parameter int unsigned AXI_REQ_DESC_W = AXI_ID_W + AXI_ADDR_W + AXI_LEN_W +
                                          AXI_SIZE_W + AXI_BURST_W + AXI_LOCK_W +
                                          AXI_CACHE_W + AXI_PROT_W + AXI_QOS_W,
  parameter int unsigned AW_ORDER_DEPTH = 16
) (
  input  logic                         clk,
  input  logic                         rst_n,

  // AXI4-Lite CSR slave
  input  logic [CSR_ADDR_W-1:0]        S_AXIL_AWADDR,
  input  logic                         S_AXIL_AWVALID,
  output logic                         S_AXIL_AWREADY,
  input  logic [CSR_DATA_W-1:0]        S_AXIL_WDATA,
  input  logic [(CSR_DATA_W/8)-1:0]    S_AXIL_WSTRB,
  input  logic                         S_AXIL_WVALID,
  output logic                         S_AXIL_WREADY,
  output logic [1:0]                   S_AXIL_BRESP,
  output logic                         S_AXIL_BVALID,
  input  logic                         S_AXIL_BREADY,
  input  logic [CSR_ADDR_W-1:0]        S_AXIL_ARADDR,
  input  logic                         S_AXIL_ARVALID,
  output logic                         S_AXIL_ARREADY,
  output logic [CSR_DATA_W-1:0]        S_AXIL_RDATA,
  output logic [1:0]                   S_AXIL_RRESP,
  output logic                         S_AXIL_RVALID,
  input  logic                         S_AXIL_RREADY,

  // AXI4 slave read address
  input  logic [AXI_ID_W-1:0]          S_AXI_ARID     [NUM_REQ],
  input  logic [AXI_ADDR_W-1:0]        S_AXI_ARADDR   [NUM_REQ],
  input  logic [AXI_LEN_W-1:0]         S_AXI_ARLEN    [NUM_REQ],
  input  logic [AXI_SIZE_W-1:0]        S_AXI_ARSIZE   [NUM_REQ],
  input  logic [AXI_BURST_W-1:0]       S_AXI_ARBURST  [NUM_REQ],
  input  logic [AXI_LOCK_W-1:0]        S_AXI_ARLOCK   [NUM_REQ],
  input  logic [AXI_CACHE_W-1:0]       S_AXI_ARCACHE  [NUM_REQ],
  input  logic [AXI_PROT_W-1:0]        S_AXI_ARPROT   [NUM_REQ],
  input  logic [AXI_QOS_W-1:0]         S_AXI_ARQOS    [NUM_REQ],
  input  logic [NUM_REQ-1:0]           S_AXI_ARVALID,
  output logic [NUM_REQ-1:0]           S_AXI_ARREADY,

  // AXI4 slave read response
  output logic [AXI_ID_W-1:0]          S_AXI_RID      [NUM_REQ],
  output logic [AXI_DATA_W-1:0]        S_AXI_RDATA    [NUM_REQ],
  output logic [AXI_RESP_W-1:0]        S_AXI_RRESP    [NUM_REQ],
  output logic [NUM_REQ-1:0]           S_AXI_RLAST,
  output logic [NUM_REQ-1:0]           S_AXI_RVALID,
  input  logic [NUM_REQ-1:0]           S_AXI_RREADY,

  // AXI4 slave write address
  input  logic [AXI_ID_W-1:0]          S_AXI_AWID     [NUM_REQ],
  input  logic [AXI_ADDR_W-1:0]        S_AXI_AWADDR   [NUM_REQ],
  input  logic [AXI_LEN_W-1:0]         S_AXI_AWLEN    [NUM_REQ],
  input  logic [AXI_SIZE_W-1:0]        S_AXI_AWSIZE   [NUM_REQ],
  input  logic [AXI_BURST_W-1:0]       S_AXI_AWBURST  [NUM_REQ],
  input  logic [AXI_LOCK_W-1:0]        S_AXI_AWLOCK   [NUM_REQ],
  input  logic [AXI_CACHE_W-1:0]       S_AXI_AWCACHE  [NUM_REQ],
  input  logic [AXI_PROT_W-1:0]        S_AXI_AWPROT   [NUM_REQ],
  input  logic [AXI_QOS_W-1:0]         S_AXI_AWQOS    [NUM_REQ],
  input  logic [NUM_REQ-1:0]           S_AXI_AWVALID,
  output logic [NUM_REQ-1:0]           S_AXI_AWREADY,

  // AXI4 slave write data
  input  logic [AXI_DATA_W-1:0]        S_AXI_WDATA    [NUM_REQ],
  input  logic [AXI_STRB_W-1:0]        S_AXI_WSTRB    [NUM_REQ],
  input  logic [NUM_REQ-1:0]           S_AXI_WLAST,
  input  logic [NUM_REQ-1:0]           S_AXI_WVALID,
  output logic [NUM_REQ-1:0]           S_AXI_WREADY,

  // AXI4 slave write response
  output logic [AXI_ID_W-1:0]          S_AXI_BID      [NUM_REQ],
  output logic [AXI_RESP_W-1:0]        S_AXI_BRESP    [NUM_REQ],
  output logic [NUM_REQ-1:0]           S_AXI_BVALID,
  input  logic [NUM_REQ-1:0]           S_AXI_BREADY,

  // AXI4 master read address
  output logic [M_AXI_ID_W-1:0]        M_AXI_ARID,
  output logic [AXI_ADDR_W-1:0]        M_AXI_ARADDR,
  output logic [AXI_LEN_W-1:0]         M_AXI_ARLEN,
  output logic [AXI_SIZE_W-1:0]        M_AXI_ARSIZE,
  output logic [AXI_BURST_W-1:0]       M_AXI_ARBURST,
  output logic [AXI_LOCK_W-1:0]        M_AXI_ARLOCK,
  output logic [AXI_CACHE_W-1:0]       M_AXI_ARCACHE,
  output logic [AXI_PROT_W-1:0]        M_AXI_ARPROT,
  output logic [AXI_QOS_W-1:0]         M_AXI_ARQOS,
  output logic                         M_AXI_ARVALID,
  input  logic                         M_AXI_ARREADY,

  // AXI4 master read response
  input  logic [M_AXI_ID_W-1:0]        M_AXI_RID,
  input  logic [AXI_DATA_W-1:0]        M_AXI_RDATA,
  input  logic [AXI_RESP_W-1:0]        M_AXI_RRESP,
  input  logic                         M_AXI_RLAST,
  input  logic                         M_AXI_RVALID,
  output logic                         M_AXI_RREADY,

  // AXI4 master write address
  output logic [M_AXI_ID_W-1:0]        M_AXI_AWID,
  output logic [AXI_ADDR_W-1:0]        M_AXI_AWADDR,
  output logic [AXI_LEN_W-1:0]         M_AXI_AWLEN,
  output logic [AXI_SIZE_W-1:0]        M_AXI_AWSIZE,
  output logic [AXI_BURST_W-1:0]       M_AXI_AWBURST,
  output logic [AXI_LOCK_W-1:0]        M_AXI_AWLOCK,
  output logic [AXI_CACHE_W-1:0]       M_AXI_AWCACHE,
  output logic [AXI_PROT_W-1:0]        M_AXI_AWPROT,
  output logic [AXI_QOS_W-1:0]         M_AXI_AWQOS,
  output logic                         M_AXI_AWVALID,
  input  logic                         M_AXI_AWREADY,

  // AXI4 master write data
  output logic [AXI_DATA_W-1:0]        M_AXI_WDATA,
  output logic [AXI_STRB_W-1:0]        M_AXI_WSTRB,
  output logic                         M_AXI_WLAST,
  output logic                         M_AXI_WVALID,
  input  logic                         M_AXI_WREADY,

  // AXI4 master write response
  input  logic [M_AXI_ID_W-1:0]        M_AXI_BID,
  input  logic [AXI_RESP_W-1:0]        M_AXI_BRESP,
  input  logic                         M_AXI_BVALID,
  output logic                         M_AXI_BREADY
);

  typedef struct packed {
    logic [AXI_ID_W-1:0]     id;
    logic [AXI_ADDR_W-1:0]   addr;
    logic [AXI_LEN_W-1:0]    len;
    logic [AXI_SIZE_W-1:0]   size;
    logic [AXI_BURST_W-1:0]  burst;
    logic [AXI_LOCK_W-1:0]   lock;
    logic [AXI_CACHE_W-1:0]  cache;
    logic [AXI_PROT_W-1:0]   prot;
    logic [AXI_QOS_W-1:0]    qos;
  } axi_req_desc_t;

  logic                         csr_write;
  logic                         csr_read;
  logic [CSR_ADDR_W-1:0]        csr_addr;
  logic [CSR_DATA_W-1:0]        csr_wdata;
  logic [(CSR_DATA_W/8)-1:0]    csr_wstrb;
  logic [CSR_DATA_W-1:0]        csr_rdata;
  logic                         csr_ready;

  logic [WEIGHT_W-1:0]          weight [NUM_REQ];
  logic [AGE_W-1:0]             aging_threshold;
  logic [AGE_W-1:0]             ar_aging_threshold_q;
  logic [AGE_W-1:0]             aw_aging_threshold_q;
  logic [AXI_REQ_DESC_W-1:0]    ar_in_data [NUM_REQ];
  logic [AXI_REQ_DESC_W-1:0]    aw_in_data [NUM_REQ];
  axi_req_desc_t                ar_in_desc [NUM_REQ];
  axi_req_desc_t                aw_in_desc [NUM_REQ];

  logic [NUM_REQ-1:0]           ar_in_ready;
  logic [NUM_REQ-1:0]           aw_in_ready;
  logic                         ar_out_valid;
  logic                         aw_out_valid;
  logic [AXI_REQ_DESC_W-1:0]    ar_out_data;
  logic [AXI_REQ_DESC_W-1:0]    aw_out_data;
  logic [REQ_IDX_W-1:0]         ar_out_src_idx;
  logic [REQ_IDX_W-1:0]         aw_out_src_idx;
  logic                         ar_out_ready;
  logic                         aw_out_ready;
  axi_req_desc_t                ar_out_desc;
  axi_req_desc_t                aw_out_desc;

  logic [NUM_REQ-1:0]           ar_fifo_full;
  logic [NUM_REQ-1:0]           ar_fifo_empty;
  logic                         ar_fire;
  logic [NUM_REQ-1:0]           ar_serve;
  logic                         ar_stall_fire;
  logic                         ar_age_override_fire;
  logic                         ar_fire_q;
  logic [NUM_REQ-1:0]           ar_serve_q;
  logic                         ar_stall_fire_q;
  logic                         ar_age_override_fire_q;

  logic [NUM_REQ-1:0]           aw_fifo_full;
  logic [NUM_REQ-1:0]           aw_fifo_empty;
  logic                         aw_fire;
  logic [NUM_REQ-1:0]           aw_serve;
  logic                         aw_stall_fire;
  logic                         aw_age_override_fire;
  logic                         aw_fire_q;
  logic [NUM_REQ-1:0]           aw_serve_q;
  logic                         aw_stall_fire_q;
  logic                         aw_age_override_fire_q;

  localparam int unsigned COUNT_LO_W = 16;
  localparam int unsigned COUNT_HI_W = COUNTER_W - COUNT_LO_W;
  localparam logic [AGE_W-1:0] RESET_AGING_THRESHOLD_LOCAL = 8'd16;

  logic [NUM_REQ-1:0]           csr_fifo_full;
  logic [NUM_REQ-1:0]           csr_fifo_empty;
  logic [COUNTER_W-1:0]         csr_grant_count [NUM_REQ];
  logic [COUNTER_W-1:0]         csr_stall_count;
  logic [COUNTER_W-1:0]         csr_starve_hit_count;

  logic [COUNT_LO_W-1:0]        csr_grant_count_lo [NUM_REQ];
  logic [COUNT_HI_W-1:0]        csr_grant_count_hi [NUM_REQ];
  logic [COUNT_LO_W-1:0]        csr_stall_count_lo;
  logic [COUNT_HI_W-1:0]        csr_stall_count_hi;
  logic [COUNT_LO_W-1:0]        csr_starve_hit_count_lo;
  logic [COUNT_HI_W-1:0]        csr_starve_hit_count_hi;

  logic [1:0]                   csr_grant_inc [NUM_REQ];
  logic [COUNT_LO_W:0]          csr_grant_lo_sum [NUM_REQ];
  logic [1:0]                   csr_stall_inc;
  logic [COUNT_LO_W:0]          csr_stall_lo_sum;
  logic [1:0]                   csr_starve_hit_inc;
  logic [COUNT_LO_W:0]          csr_starve_hit_lo_sum;

  logic                         aw_order_push;
  logic                         aw_order_pop;
  logic [REQ_IDX_W-1:0]         aw_order_head_src;
  logic                         aw_order_full;
  logic                         aw_order_empty;
  logic                         aw_can_issue;

  logic [REQ_IDX_W-1:0]         r_src_idx;
  logic [REQ_IDX_W-1:0]         b_src_idx;

  logic                         ar_m_valid_q;
  axi_req_desc_t                ar_m_desc_q;
  logic [REQ_IDX_W-1:0]         ar_m_src_q;

  logic                         aw_m_valid_q;
  axi_req_desc_t                aw_m_desc_q;
  logic [REQ_IDX_W-1:0]         aw_m_src_q;

  axi4lite_csr_if #(
    .ADDR_W (CSR_ADDR_W),
    .DATA_W (CSR_DATA_W)
  ) u_axi4lite_csr_if (
    .clk             (clk),
    .rst_n           (rst_n),
    .S_AXIL_AWADDR   (S_AXIL_AWADDR),
    .S_AXIL_AWVALID  (S_AXIL_AWVALID),
    .S_AXIL_AWREADY  (S_AXIL_AWREADY),
    .S_AXIL_WDATA    (S_AXIL_WDATA),
    .S_AXIL_WSTRB    (S_AXIL_WSTRB),
    .S_AXIL_WVALID   (S_AXIL_WVALID),
    .S_AXIL_WREADY   (S_AXIL_WREADY),
    .S_AXIL_BRESP    (S_AXIL_BRESP),
    .S_AXIL_BVALID   (S_AXIL_BVALID),
    .S_AXIL_BREADY   (S_AXIL_BREADY),
    .S_AXIL_ARADDR   (S_AXIL_ARADDR),
    .S_AXIL_ARVALID  (S_AXIL_ARVALID),
    .S_AXIL_ARREADY  (S_AXIL_ARREADY),
    .S_AXIL_RDATA    (S_AXIL_RDATA),
    .S_AXIL_RRESP    (S_AXIL_RRESP),
    .S_AXIL_RVALID   (S_AXIL_RVALID),
    .S_AXIL_RREADY   (S_AXIL_RREADY),
    .csr_write_o     (csr_write),
    .csr_read_o      (csr_read),
    .csr_addr_o      (csr_addr),
    .csr_wdata_o     (csr_wdata),
    .csr_wstrb_o     (csr_wstrb),
    .csr_rdata_i     (csr_rdata),
    .csr_ready_i     (csr_ready)
  );

  csr_regs #(
    .NUM_REQ   (NUM_REQ),
    .WEIGHT_W  (WEIGHT_W),
    .AGE_W     (AGE_W),
    .COUNTER_W (COUNTER_W),
    .ADDR_W    (CSR_ADDR_W),
    .DATA_W    (CSR_DATA_W)
  ) u_csr_regs (
    .clk                 (clk),
    .rst_n               (rst_n),
    .csr_write_i         (csr_write),
    .csr_read_i          (csr_read),
    .csr_addr_i          (csr_addr),
    .csr_wdata_i         (csr_wdata),
    .csr_wstrb_i         (csr_wstrb),
    .fifo_full_i         (csr_fifo_full),
    .fifo_empty_i        (csr_fifo_empty),
    .grant_count_i       (csr_grant_count),
    .stall_count_i       (csr_stall_count),
    .starve_hit_count_i  (csr_starve_hit_count),
    .csr_rdata_o         (csr_rdata),
    .csr_ready_o         (csr_ready),
    .weight_o            (weight),
    .aging_threshold_o   (aging_threshold)
  );

  always_ff @(posedge clk or negedge rst_n) begin : aging_threshold_pipe_ff
    if (!rst_n) begin
      ar_aging_threshold_q <= RESET_AGING_THRESHOLD_LOCAL;
      aw_aging_threshold_q <= RESET_AGING_THRESHOLD_LOCAL;
    end else begin
      ar_aging_threshold_q <= aging_threshold;
      aw_aging_threshold_q <= aging_threshold;
    end
  end

  for (genvar g = 0; g < NUM_REQ; g++) begin : gen_desc_pack
    assign ar_in_desc[g].id    = S_AXI_ARID[g];
    assign ar_in_desc[g].addr  = S_AXI_ARADDR[g];
    assign ar_in_desc[g].len   = S_AXI_ARLEN[g];
    assign ar_in_desc[g].size  = S_AXI_ARSIZE[g];
    assign ar_in_desc[g].burst = S_AXI_ARBURST[g];
    assign ar_in_desc[g].lock  = S_AXI_ARLOCK[g];
    assign ar_in_desc[g].cache = S_AXI_ARCACHE[g];
    assign ar_in_desc[g].prot  = S_AXI_ARPROT[g];
    assign ar_in_desc[g].qos   = S_AXI_ARQOS[g];
    assign ar_in_data[g]       = ar_in_desc[g];

    assign aw_in_desc[g].id    = S_AXI_AWID[g];
    assign aw_in_desc[g].addr  = S_AXI_AWADDR[g];
    assign aw_in_desc[g].len   = S_AXI_AWLEN[g];
    assign aw_in_desc[g].size  = S_AXI_AWSIZE[g];
    assign aw_in_desc[g].burst = S_AXI_AWBURST[g];
    assign aw_in_desc[g].lock  = S_AXI_AWLOCK[g];
    assign aw_in_desc[g].cache = S_AXI_AWCACHE[g];
    assign aw_in_desc[g].prot  = S_AXI_AWPROT[g];
    assign aw_in_desc[g].qos   = S_AXI_AWQOS[g];
    assign aw_in_data[g]       = aw_in_desc[g];

    assign S_AXI_ARREADY[g]    = ar_in_ready[g];
    assign S_AXI_AWREADY[g]    = aw_in_ready[g];
  end

  scheduler_channel #(
    .NUM_REQ    (NUM_REQ),
    .REQ_W      (AXI_REQ_DESC_W),
    .FIFO_DEPTH (FIFO_DEPTH),
    .WEIGHT_W   (WEIGHT_W),
    .AGE_W      (AGE_W),
    .REQ_IDX_W  (REQ_IDX_W)
  ) u_ar_sched (
    .clk                  (clk),
    .rst_n                (rst_n),
    .in_valid_i           (S_AXI_ARVALID),
    .in_data_i            (ar_in_data),
    .in_ready_o           (ar_in_ready),
    .out_valid_o          (ar_out_valid),
    .out_data_o           (ar_out_data),
    .out_src_idx_o        (ar_out_src_idx),
    .out_ready_i          (ar_out_ready),
    .weight_i             (weight),
    .aging_threshold_i    (ar_aging_threshold_q),
    .fifo_full_o          (ar_fifo_full),
    .fifo_empty_o         (ar_fifo_empty),
    .fire_o               (ar_fire),
    .serve_o              (ar_serve),
    .stall_fire_o         (ar_stall_fire),
    .age_override_fire_o  (ar_age_override_fire)
  );

  scheduler_channel #(
    .NUM_REQ    (NUM_REQ),
    .REQ_W      (AXI_REQ_DESC_W),
    .FIFO_DEPTH (FIFO_DEPTH),
    .WEIGHT_W   (WEIGHT_W),
    .AGE_W      (AGE_W),
    .REQ_IDX_W  (REQ_IDX_W)
  ) u_aw_sched (
    .clk                  (clk),
    .rst_n                (rst_n),
    .in_valid_i           (S_AXI_AWVALID),
    .in_data_i            (aw_in_data),
    .in_ready_o           (aw_in_ready),
    .out_valid_o          (aw_out_valid),
    .out_data_o           (aw_out_data),
    .out_src_idx_o        (aw_out_src_idx),
    .out_ready_i          (aw_out_ready),
    .weight_i             (weight),
    .aging_threshold_i    (aw_aging_threshold_q),
    .fifo_full_o          (aw_fifo_full),
    .fifo_empty_o         (aw_fifo_empty),
    .fire_o               (aw_fire),
    .serve_o              (aw_serve),
    .stall_fire_o         (aw_stall_fire),
    .age_override_fire_o  (aw_age_override_fire)
  );

  assign ar_out_desc = axi_req_desc_t'(ar_out_data);
  assign aw_out_desc = axi_req_desc_t'(aw_out_data);

  // AR issue register cuts scheduler timing path to M_AXI_AR
  assign ar_out_ready = !ar_m_valid_q || M_AXI_ARREADY;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ar_m_valid_q <= 1'b0;
      ar_m_desc_q  <= '0;
      ar_m_src_q   <= '0;
    end else if (!ar_m_valid_q || M_AXI_ARREADY) begin
      ar_m_valid_q <= ar_out_valid;
      if (ar_out_valid) begin
        ar_m_desc_q <= ar_out_desc;
        ar_m_src_q  <= ar_out_src_idx;
      end
    end
  end

  assign M_AXI_ARVALID = ar_m_valid_q;
  assign M_AXI_ARID    = {ar_m_src_q, ar_m_desc_q.id};
  assign M_AXI_ARADDR  = ar_m_desc_q.addr;
  assign M_AXI_ARLEN   = ar_m_desc_q.len;
  assign M_AXI_ARSIZE  = ar_m_desc_q.size;
  assign M_AXI_ARBURST = ar_m_desc_q.burst;
  assign M_AXI_ARLOCK  = ar_m_desc_q.lock;
  assign M_AXI_ARCACHE = ar_m_desc_q.cache;
  assign M_AXI_ARPROT  = ar_m_desc_q.prot;
  assign M_AXI_ARQOS   = ar_m_desc_q.qos;

  // AW issue waits for space in source order FIFO
  assign aw_can_issue = !aw_order_full;
  assign aw_out_ready = !aw_m_valid_q || (M_AXI_AWREADY && aw_can_issue);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      aw_m_valid_q <= 1'b0;
      aw_m_desc_q  <= '0;
      aw_m_src_q   <= '0;
    end else if (!aw_m_valid_q || (M_AXI_AWREADY && aw_can_issue)) begin
      aw_m_valid_q <= aw_out_valid;
      if (aw_out_valid) begin
        aw_m_desc_q <= aw_out_desc;
        aw_m_src_q  <= aw_out_src_idx;
      end
    end
  end

  assign M_AXI_AWVALID = aw_m_valid_q && aw_can_issue;
  assign M_AXI_AWID    = {aw_m_src_q, aw_m_desc_q.id};
  assign M_AXI_AWADDR  = aw_m_desc_q.addr;
  assign M_AXI_AWLEN   = aw_m_desc_q.len;
  assign M_AXI_AWSIZE  = aw_m_desc_q.size;
  assign M_AXI_AWBURST = aw_m_desc_q.burst;
  assign M_AXI_AWLOCK  = aw_m_desc_q.lock;
  assign M_AXI_AWCACHE = aw_m_desc_q.cache;
  assign M_AXI_AWPROT  = aw_m_desc_q.prot;
  assign M_AXI_AWQOS   = aw_m_desc_q.qos;

  assign aw_order_push = M_AXI_AWVALID && M_AXI_AWREADY;

  aw_src_order_fifo #(
    .REQ_IDX_W (REQ_IDX_W),
    .DEPTH     (AW_ORDER_DEPTH)
  ) u_aw_src_order_fifo (
    .clk        (clk),
    .rst_n      (rst_n),
    .push_i     (aw_order_push),
    .push_src_i (aw_m_src_q),
    .pop_i      (aw_order_pop),
    .head_src_o (aw_order_head_src),
    .full_o     (aw_order_full),
    .empty_o    (aw_order_empty)
  );

  // W follows accepted AW order without independent arbitration
  always_comb begin : w_mux_comb
    M_AXI_WVALID = 1'b0;
    M_AXI_WDATA  = '0;
    M_AXI_WSTRB  = '0;
    M_AXI_WLAST  = 1'b0;
    S_AXI_WREADY = '0;

    if (!aw_order_empty) begin
      M_AXI_WVALID = S_AXI_WVALID[aw_order_head_src];
      M_AXI_WDATA  = S_AXI_WDATA [aw_order_head_src];
      M_AXI_WSTRB  = S_AXI_WSTRB [aw_order_head_src];
      M_AXI_WLAST  = S_AXI_WLAST [aw_order_head_src];
      S_AXI_WREADY[aw_order_head_src] = M_AXI_WREADY;
    end
  end

  assign aw_order_pop = M_AXI_WVALID && M_AXI_WREADY && M_AXI_WLAST;

  // Route responses using widened IDs
  assign r_src_idx = M_AXI_RID[M_AXI_ID_W-1 -: REQ_IDX_W];
  assign b_src_idx = M_AXI_BID[M_AXI_ID_W-1 -: REQ_IDX_W];

  always_comb begin : r_route_comb
    for (int i = 0; i < NUM_REQ; i++) begin
      S_AXI_RVALID[i] = 1'b0;
      S_AXI_RID[i]    = '0;
      S_AXI_RDATA[i]  = '0;
      S_AXI_RRESP[i]  = '0;
      S_AXI_RLAST[i]  = 1'b0;
    end

    M_AXI_RREADY = 1'b1;
    if (int'(r_src_idx) < NUM_REQ) begin
      S_AXI_RVALID[r_src_idx] = M_AXI_RVALID;
      S_AXI_RID[r_src_idx]    = M_AXI_RID[AXI_ID_W-1:0];
      S_AXI_RDATA[r_src_idx]  = M_AXI_RDATA;
      S_AXI_RRESP[r_src_idx]  = M_AXI_RRESP;
      S_AXI_RLAST[r_src_idx]  = M_AXI_RLAST;
      M_AXI_RREADY            = S_AXI_RREADY[r_src_idx];
    end
  end

  always_comb begin : b_route_comb
    for (int i = 0; i < NUM_REQ; i++) begin
      S_AXI_BVALID[i] = 1'b0;
      S_AXI_BID[i]    = '0;
      S_AXI_BRESP[i]  = '0;
    end

    M_AXI_BREADY = 1'b1;
    if (int'(b_src_idx) < NUM_REQ) begin
      S_AXI_BVALID[b_src_idx] = M_AXI_BVALID;
      S_AXI_BID[b_src_idx]    = M_AXI_BID[AXI_ID_W-1:0];
      S_AXI_BRESP[b_src_idx]  = M_AXI_BRESP;
      M_AXI_BREADY            = S_AXI_BREADY[b_src_idx];
    end
  end

  // Register counter events to isolate READY from counter path
  always_ff @(posedge clk or negedge rst_n) begin : csr_counter_event_ff
    if (!rst_n) begin
      ar_fire_q              <= 1'b0;
      ar_serve_q             <= '0;
      ar_stall_fire_q        <= 1'b0;
      ar_age_override_fire_q <= 1'b0;
      aw_fire_q              <= 1'b0;
      aw_serve_q             <= '0;
      aw_stall_fire_q        <= 1'b0;
      aw_age_override_fire_q <= 1'b0;
    end else begin
      ar_fire_q              <= ar_fire;
      ar_serve_q             <= ar_serve;
      ar_stall_fire_q        <= ar_stall_fire;
      ar_age_override_fire_q <= ar_age_override_fire;
      aw_fire_q              <= aw_fire;
      aw_serve_q             <= aw_serve;
      aw_stall_fire_q        <= aw_stall_fire;
      aw_age_override_fire_q <= aw_age_override_fire;
    end
  end

  for (genvar c = 0; c < NUM_REQ; c++) begin : gen_csr_status
    assign csr_fifo_full[c]  = ar_fifo_full[c]  | aw_fifo_full[c];
    assign csr_fifo_empty[c] = ar_fifo_empty[c] & aw_fifo_empty[c];
  end

  always_comb begin : csr_counter_inc_comb
    for (int i = 0; i < NUM_REQ; i++) begin
      csr_grant_inc[i]    = {1'b0, (ar_fire_q && ar_serve_q[i])} +
                            {1'b0, (aw_fire_q && aw_serve_q[i])};
      csr_grant_lo_sum[i] = {1'b0, csr_grant_count_lo[i]} + csr_grant_inc[i];
      csr_grant_count[i]  = {csr_grant_count_hi[i], csr_grant_count_lo[i]};
    end

    csr_stall_inc          = {1'b0, ar_stall_fire_q} + {1'b0, aw_stall_fire_q};
    csr_stall_lo_sum       = {1'b0, csr_stall_count_lo} + csr_stall_inc;
    csr_stall_count        = {csr_stall_count_hi, csr_stall_count_lo};

    csr_starve_hit_inc     = {1'b0, ar_age_override_fire_q} + {1'b0, aw_age_override_fire_q};
    csr_starve_hit_lo_sum  = {1'b0, csr_starve_hit_count_lo} + csr_starve_hit_inc;
    csr_starve_hit_count   = {csr_starve_hit_count_hi, csr_starve_hit_count_lo};
  end

  always_ff @(posedge clk or negedge rst_n) begin : csr_counter_total_ff
    if (!rst_n) begin
      for (int i = 0; i < NUM_REQ; i++) begin
        csr_grant_count_lo[i] <= '0;
        csr_grant_count_hi[i] <= '0;
      end
      csr_stall_count_lo      <= '0;
      csr_stall_count_hi      <= '0;
      csr_starve_hit_count_lo <= '0;
      csr_starve_hit_count_hi <= '0;
    end else begin
      for (int i = 0; i < NUM_REQ; i++) begin
        csr_grant_count_lo[i] <= csr_grant_lo_sum[i][COUNT_LO_W-1:0];
        csr_grant_count_hi[i] <= csr_grant_count_hi[i] +
                                 {{(COUNT_HI_W-1){1'b0}}, csr_grant_lo_sum[i][COUNT_LO_W]};
      end

      csr_stall_count_lo      <= csr_stall_lo_sum[COUNT_LO_W-1:0];
      csr_stall_count_hi      <= csr_stall_count_hi +
                                 {{(COUNT_HI_W-1){1'b0}}, csr_stall_lo_sum[COUNT_LO_W]};

      csr_starve_hit_count_lo <= csr_starve_hit_lo_sum[COUNT_LO_W-1:0];
      csr_starve_hit_count_hi <= csr_starve_hit_count_hi +
                                 {{(COUNT_HI_W-1){1'b0}}, csr_starve_hit_lo_sum[COUNT_LO_W]};
    end
  end
endmodule : axi4_scheduler_top
