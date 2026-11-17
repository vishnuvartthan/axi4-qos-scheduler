`timescale 1ns/1ps

// AXI4-Lite to CSR adapter. One access per cycle; writes win simultaneous requests.
module axi4lite_csr_if #(
  parameter int unsigned ADDR_W = 8,
  parameter int unsigned DATA_W = 32
) (
  input  logic                  clk,
  input  logic                  rst_n,

  input  logic [ADDR_W-1:0]     S_AXIL_AWADDR,
  input  logic                  S_AXIL_AWVALID,
  output logic                  S_AXIL_AWREADY,

  input  logic [DATA_W-1:0]     S_AXIL_WDATA,
  input  logic [(DATA_W/8)-1:0] S_AXIL_WSTRB,
  input  logic                  S_AXIL_WVALID,
  output logic                  S_AXIL_WREADY,

  output logic [1:0]            S_AXIL_BRESP,
  output logic                  S_AXIL_BVALID,
  input  logic                  S_AXIL_BREADY,

  input  logic [ADDR_W-1:0]     S_AXIL_ARADDR,
  input  logic                  S_AXIL_ARVALID,
  output logic                  S_AXIL_ARREADY,

  output logic [DATA_W-1:0]     S_AXIL_RDATA,
  output logic [1:0]            S_AXIL_RRESP,
  output logic                  S_AXIL_RVALID,
  input  logic                  S_AXIL_RREADY,

  output logic                  csr_write_o,
  output logic                  csr_read_o,
  output logic [ADDR_W-1:0]     csr_addr_o,
  output logic [DATA_W-1:0]     csr_wdata_o,
  output logic [(DATA_W/8)-1:0] csr_wstrb_o,
  input  logic [DATA_W-1:0]     csr_rdata_i,
  input  logic                  csr_ready_i
);

  localparam logic [1:0] AXI_RESP_OKAY = 2'b00;

  logic                  aw_hold_q;
  logic [ADDR_W-1:0]     awaddr_q;
  logic                  w_hold_q;
  logic [DATA_W-1:0]     wdata_q;
  logic [(DATA_W/8)-1:0] wstrb_q;
  logic                  ar_hold_q;
  logic [ADDR_W-1:0]     araddr_q;

  logic                  write_do;
  logic                  read_do;
  logic                  aw_fire;
  logic                  w_fire;
  logic                  ar_fire;

  assign S_AXIL_AWREADY = !aw_hold_q && !S_AXIL_BVALID;
  assign S_AXIL_WREADY  = !w_hold_q  && !S_AXIL_BVALID;
  assign S_AXIL_ARREADY = !ar_hold_q && !S_AXIL_RVALID;

  assign aw_fire = S_AXIL_AWVALID && S_AXIL_AWREADY;
  assign w_fire  = S_AXIL_WVALID  && S_AXIL_WREADY;
  assign ar_fire = S_AXIL_ARVALID && S_AXIL_ARREADY;

  assign write_do = aw_hold_q && w_hold_q && !S_AXIL_BVALID && csr_ready_i;
  assign read_do  = ar_hold_q && !S_AXIL_RVALID && !write_do && csr_ready_i;

  assign csr_write_o = write_do;
  assign csr_read_o  = read_do;
  assign csr_addr_o  = write_do ? awaddr_q : araddr_q;
  assign csr_wdata_o = wdata_q;
  assign csr_wstrb_o = wstrb_q;

  always_ff @(posedge clk or negedge rst_n) begin : axil_ff
    if (!rst_n) begin
      aw_hold_q     <= 1'b0;
      awaddr_q      <= '0;
      w_hold_q      <= 1'b0;
      wdata_q       <= '0;
      wstrb_q       <= '0;
      ar_hold_q     <= 1'b0;
      araddr_q      <= '0;
      S_AXIL_BVALID <= 1'b0;
      S_AXIL_BRESP  <= AXI_RESP_OKAY;
      S_AXIL_RVALID <= 1'b0;
      S_AXIL_RRESP  <= AXI_RESP_OKAY;
      S_AXIL_RDATA  <= '0;
    end else begin
      if (write_do) begin
        aw_hold_q     <= 1'b0;
        w_hold_q      <= 1'b0;
        S_AXIL_BVALID <= 1'b1;
        S_AXIL_BRESP  <= AXI_RESP_OKAY;
      end else begin
        if (aw_fire) begin
          aw_hold_q <= 1'b1;
          awaddr_q  <= S_AXIL_AWADDR;
        end

        if (w_fire) begin
          w_hold_q <= 1'b1;
          wdata_q  <= S_AXIL_WDATA;
          wstrb_q  <= S_AXIL_WSTRB;
        end

        if (S_AXIL_BVALID && S_AXIL_BREADY)
          S_AXIL_BVALID <= 1'b0;
      end

      if (read_do) begin
        ar_hold_q     <= 1'b0;
        S_AXIL_RVALID <= 1'b1;
        S_AXIL_RRESP  <= AXI_RESP_OKAY;
        S_AXIL_RDATA  <= csr_rdata_i;
      end else begin
        if (ar_fire) begin
          ar_hold_q <= 1'b1;
          araddr_q  <= S_AXIL_ARADDR;
        end

        if (S_AXIL_RVALID && S_AXIL_RREADY)
          S_AXIL_RVALID <= 1'b0;
      end
    end
  end

endmodule : axi4lite_csr_if
