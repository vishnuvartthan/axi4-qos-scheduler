`timescale 1ns/1ps

module scheduler_core #(
  parameter int unsigned NUM_REQ   = 4,
  parameter int unsigned REQ_W     = 32,
  parameter int unsigned AGE_W     = 8,
  parameter int unsigned REQ_IDX_W = (NUM_REQ <= 1) ? 1 : $clog2(NUM_REQ)
) (
  input  logic [NUM_REQ-1:0]           fifo_valid_i,
  input  logic [REQ_W-1:0]             fifo_data_i [NUM_REQ],
  input  logic [NUM_REQ-1:0]           starved_i,
  input  logic [AGE_W-1:0]             age_i [NUM_REQ],
  input  logic                         wrr_grant_valid_i,
  input  logic [REQ_IDX_W-1:0]         wrr_grant_idx_i,
  input  logic [NUM_REQ-1:0]           wrr_grant_onehot_i,
  input  logic                         out_ready_i,
  output logic                         out_valid_o,
  output logic [REQ_W-1:0]             out_data_o,
  output logic [REQ_IDX_W-1:0]         out_src_idx_o,
  output logic [NUM_REQ-1:0]           fifo_pop_o,
  output logic [NUM_REQ-1:0]           serve_o,
  output logic [NUM_REQ-1:0]           pending_o,
  output logic [NUM_REQ-1:0]           wrr_eligible_o,
  output logic                         wrr_advance_o,
  output logic                         selected_from_age_override_o
);

  logic                         sel_valid;
  logic [REQ_W-1:0]             sel_data;
  logic [REQ_IDX_W-1:0]         sel_idx;
  logic [NUM_REQ-1:0]           sel_onehot;
  logic                         sel_from_wrr;
  logic                         age_override_valid;
  logic [REQ_IDX_W-1:0]         age_override_idx;
  logic [NUM_REQ-1:0]           age_override_onehot;
  logic [REQ_W-1:0]             age_override_data;
  logic [AGE_W-1:0]             age_override_best_age;
  logic                         fire;

  assign pending_o      = fifo_valid_i;
  assign wrr_eligible_o = fifo_valid_i;

  function automatic logic [REQ_W-1:0] mux_onehot_data(
    input logic [NUM_REQ-1:0] onehot,
    input logic [REQ_W-1:0]   data [NUM_REQ]
  );
    logic [REQ_W-1:0] result;

    result = '0;
    for (int m = 0; m < NUM_REQ; m++) begin
      result |= ({REQ_W{onehot[m]}} & data[m]);
    end

    return result;
  endfunction

  always_comb begin : age_override_comb
    age_override_valid    = 1'b0;
    age_override_idx      = '0;
    age_override_onehot   = '0;
    age_override_data     = '0;
    age_override_best_age = '0;

    for (int i = 0; i < NUM_REQ; i++) begin
      if (fifo_valid_i[i] && starved_i[i]) begin
        if (!age_override_valid || (age_i[i] > age_override_best_age)) begin
          age_override_valid          = 1'b1;
          age_override_idx            = REQ_IDX_W'(i);
          age_override_onehot         = '0;
          age_override_onehot[i]      = 1'b1;
          age_override_best_age       = age_i[i];
        end
      end
    end

    age_override_data = mux_onehot_data(age_override_onehot, fifo_data_i);
  end

  always_comb begin : select_comb
    sel_valid    = 1'b0;
    sel_data     = '0;
    sel_idx      = '0;
    sel_onehot   = '0;
    sel_from_wrr = 1'b0;

    if (age_override_valid) begin
      sel_valid    = 1'b1;
      sel_data     = age_override_data;
      sel_idx      = age_override_idx;
      sel_onehot   = age_override_onehot;
      sel_from_wrr = 1'b0;
    end else if (wrr_grant_valid_i) begin
      sel_valid    = 1'b1;
      sel_data     = mux_onehot_data(wrr_grant_onehot_i, fifo_data_i);
      sel_idx      = wrr_grant_idx_i;
      sel_onehot   = wrr_grant_onehot_i;
      sel_from_wrr = 1'b1;
    end
  end
  assign fire = out_valid_o && out_ready_i;

  assign out_valid_o                  = sel_valid;
  assign out_data_o                   = sel_data;
  assign out_src_idx_o                = sel_idx;
  assign selected_from_age_override_o = sel_valid && !sel_from_wrr;

  always_comb begin : handshake_comb
    fifo_pop_o    = '0;
    serve_o       = '0;
    wrr_advance_o = 1'b0;

    if (fire) begin
      fifo_pop_o    = sel_onehot;
      serve_o       = sel_onehot;
      wrr_advance_o = sel_valid && sel_from_wrr;
    end
  end

endmodule : scheduler_core
