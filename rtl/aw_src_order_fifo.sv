`timescale 1ns/1ps


module aw_src_order_fifo #(
  parameter int unsigned REQ_IDX_W = 2,
  parameter int unsigned DEPTH     = 16
) (
  input  logic                     clk,
  input  logic                     rst_n,

  input  logic                     push_i,
  input  logic [REQ_IDX_W-1:0]     push_src_i,
  input  logic                     pop_i,

  output logic [REQ_IDX_W-1:0]     head_src_o,
  output logic                     full_o,
  output logic                     empty_o
);

  req_fifo #(
    .WIDTH (REQ_IDX_W),
    .DEPTH (DEPTH)
  ) u_fifo (
    .clk       (clk),
    .rst_n     (rst_n),
    .push      (push_i),
    .push_data (push_src_i),
    .pop       (pop_i),
    .pop_data  (head_src_o),
    .full      (full_o),
    .empty     (empty_o)
  );

endmodule : aw_src_order_fifo
