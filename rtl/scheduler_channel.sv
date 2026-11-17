`timescale 1ns/1ps

// Descriptor scheduler lane without CSR block.
module scheduler_channel #(
  parameter int unsigned NUM_REQ       = 4,
  parameter int unsigned REQ_W         = 32,
  parameter int unsigned FIFO_DEPTH    = 4,
  parameter int unsigned WEIGHT_W      = 4,
  parameter int unsigned AGE_W         = 8,
  parameter int unsigned REQ_IDX_W     = (NUM_REQ <= 1) ? 1 : $clog2(NUM_REQ)
) (
  input  logic                         clk,
  input  logic                         rst_n,

  input  logic [NUM_REQ-1:0]           in_valid_i,
  input  logic [REQ_W-1:0]             in_data_i [NUM_REQ],
  output logic [NUM_REQ-1:0]           in_ready_o,

  output logic                         out_valid_o,
  output logic [REQ_W-1:0]             out_data_o,
  output logic [REQ_IDX_W-1:0]         out_src_idx_o,
  input  logic                         out_ready_i,

  input  logic [WEIGHT_W-1:0]          weight_i [NUM_REQ],
  input  logic [AGE_W-1:0]             aging_threshold_i,

  output logic [NUM_REQ-1:0]           fifo_full_o,
  output logic [NUM_REQ-1:0]           fifo_empty_o,

  // Event taps keep shared counters outside channel datapath
  output logic                         fire_o,
  output logic [NUM_REQ-1:0]           serve_o,
  output logic                         stall_fire_o,
  output logic                         age_override_fire_o
);

  logic [NUM_REQ-1:0]           fifo_push;
  logic [NUM_REQ-1:0]           fifo_pop;
  logic [REQ_W-1:0]             fifo_head_data [NUM_REQ];
  logic [NUM_REQ-1:0]           fifo_full;
  logic [NUM_REQ-1:0]           fifo_empty;
  logic [NUM_REQ-1:0]           fifo_valid;

  logic [AGE_W-1:0]             age [NUM_REQ];
  logic [NUM_REQ-1:0]           starved;
  logic                         wrr_grant_valid;
  logic [REQ_IDX_W-1:0]         wrr_grant_idx;
  logic [NUM_REQ-1:0]           wrr_grant_onehot;

  logic [NUM_REQ-1:0]           pending;
  logic [NUM_REQ-1:0]           serve;
  logic [NUM_REQ-1:0]           wrr_eligible;
  logic                         wrr_advance;
  logic                         selected_from_age_override;

  logic                         core_out_valid;
  logic [REQ_W-1:0]             core_out_data;
  logic [REQ_IDX_W-1:0]         core_out_src_idx;
  logic                         core_out_ready;

  logic                         pipe_valid_q;
  logic [REQ_W-1:0]             pipe_data_q;
  logic [REQ_IDX_W-1:0]         pipe_src_idx_q;
  logic                         pipe_age_override_q;

  logic                         fire;
  logic [NUM_REQ-1:0]           out_serve;
  logic                         age_override_fire;

  for (genvar g = 0; g < NUM_REQ; g++) begin : gen_input_side
    assign in_ready_o[g] = !fifo_full[g];
    assign fifo_push[g]  = in_valid_i[g] && in_ready_o[g];
    assign fifo_valid[g] = !fifo_empty[g];
  end

  for (genvar g = 0; g < NUM_REQ; g++) begin : gen_req_fifo
    req_fifo #(
      .WIDTH (REQ_W),
      .DEPTH (FIFO_DEPTH)
    ) u_req_fifo (
      .clk       (clk),
      .rst_n     (rst_n),
      .push      (fifo_push[g]),
      .push_data (in_data_i[g]),
      .pop       (fifo_pop[g]),
      .pop_data  (fifo_head_data[g]),
      .full      (fifo_full[g]),
      .empty     (fifo_empty[g])
    );
  end

  age_tracker #(
    .NUM_REQ          (NUM_REQ),
    .AGE_W            (AGE_W),
    .REGISTER_STARVED (1'b1)
  ) u_age_tracker (
    .clk                (clk),
    .rst_n              (rst_n),
    .pending_i          (pending),
    .serve_i            (serve),
    .aging_threshold_i  (aging_threshold_i),
    .age_o              (age),
    .starved_o          (starved)
  );

  wrr_arbiter #(
    .NUM_REQ   (NUM_REQ),
    .WEIGHT_W  (WEIGHT_W),
    .REQ_IDX_W (REQ_IDX_W)
  ) u_wrr_arbiter (
    .clk            (clk),
    .rst_n          (rst_n),
    .eligible_i     (wrr_eligible),
    .weight_i       (weight_i),
    .advance_i      (wrr_advance),
    .grant_valid_o  (wrr_grant_valid),
    .grant_idx_o    (wrr_grant_idx),
    .grant_onehot_o (wrr_grant_onehot)
  );

  scheduler_core #(
    .NUM_REQ   (NUM_REQ),
    .REQ_W     (REQ_W),
    .AGE_W     (AGE_W),
    .REQ_IDX_W (REQ_IDX_W)
  ) u_scheduler_core (
    .fifo_valid_i       (fifo_valid),
    .fifo_data_i        (fifo_head_data),
    .starved_i          (starved),
    .age_i              (age),
    .wrr_grant_valid_i  (wrr_grant_valid),
    .wrr_grant_idx_i    (wrr_grant_idx),
    .wrr_grant_onehot_i (wrr_grant_onehot),
    .out_ready_i        (core_out_ready),
    .out_valid_o        (core_out_valid),
    .out_data_o         (core_out_data),
    .out_src_idx_o      (core_out_src_idx),
    .fifo_pop_o         (fifo_pop),
    .serve_o            (serve),
    .pending_o          (pending),
    .wrr_eligible_o     (wrr_eligible),
    .wrr_advance_o      (wrr_advance),
    .selected_from_age_override_o (selected_from_age_override)
  );

  // Output register breaks FIFO, aging, and arbitration timing path
  assign core_out_ready = !pipe_valid_q || out_ready_i;

  always_ff @(posedge clk or negedge rst_n) begin : output_pipe_ff
    if (!rst_n) begin
      pipe_valid_q        <= 1'b0;
      pipe_data_q         <= '0;
      pipe_src_idx_q      <= '0;
      pipe_age_override_q <= 1'b0;
    end else if (core_out_ready) begin
      pipe_valid_q <= core_out_valid;
      if (core_out_valid) begin
        pipe_data_q         <= core_out_data;
        pipe_src_idx_q      <= core_out_src_idx;
        pipe_age_override_q <= selected_from_age_override;
      end
    end
  end

  assign out_valid_o   = pipe_valid_q;
  assign out_data_o    = pipe_data_q;
  assign out_src_idx_o = pipe_src_idx_q;

  assign fire              = out_valid_o && out_ready_i;
  assign age_override_fire = fire && pipe_age_override_q;

  always_comb begin : out_serve_comb
    out_serve = '0;
    if (fire) begin
      out_serve[pipe_src_idx_q] = 1'b1;
    end
  end

  assign fire_o              = fire;
  assign serve_o             = out_serve;
  assign stall_fire_o        = out_valid_o && !out_ready_i;
  assign age_override_fire_o = age_override_fire;

  assign fifo_full_o  = fifo_full;
  assign fifo_empty_o = fifo_empty;

endmodule : scheduler_channel
