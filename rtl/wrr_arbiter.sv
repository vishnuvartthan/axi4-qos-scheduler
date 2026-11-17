`timescale 1ns/1ps

module wrr_arbiter #(
  parameter int unsigned NUM_REQ   = 4,
  parameter int unsigned WEIGHT_W  = 4,
  parameter int unsigned REQ_IDX_W = (NUM_REQ <= 1) ? 1 : $clog2(NUM_REQ)
) (
  input  logic                         clk,
  input  logic                         rst_n,
  input  logic [NUM_REQ-1:0]           eligible_i,
  input  logic [WEIGHT_W-1:0]          weight_i [NUM_REQ],
  input  logic                         advance_i,

  output logic                         grant_valid_o,
  output logic [REQ_IDX_W-1:0]         grant_idx_o,
  output logic [NUM_REQ-1:0]           grant_onehot_o
);

  logic [REQ_IDX_W-1:0] wrr_ptr_q, wrr_ptr_n;
  logic [WEIGHT_W-1:0]  quota_q [NUM_REQ];
  logic [WEIGHT_W-1:0]  quota_n [NUM_REQ];

  logic [NUM_REQ-1:0]   has_quota;
  logic [NUM_REQ-1:0]   effective_quota_mask;
  logic [NUM_REQ-1:0]   service_mask;

  logic                 reload_needed;
  logic                 sel_valid;
  logic [REQ_IDX_W-1:0] sel_idx;
  logic [NUM_REQ-1:0]   sel_onehot;

  logic [REQ_IDX_W-1:0] search_idx;
  logic                 found;

  always_comb begin : quota_mask_comb
    for (int i = 0; i < NUM_REQ; i++) begin
      has_quota[i] = (quota_q[i] != '0);
    end
  end

  assign effective_quota_mask = eligible_i & has_quota;
  assign reload_needed        = (effective_quota_mask == '0);

  always_comb begin : service_mask_comb
    service_mask = '0;

    if (reload_needed) begin
      for (int i = 0; i < NUM_REQ; i++) begin
        service_mask[i] = eligible_i[i] && (weight_i[i] != '0);
      end
    end else begin
      service_mask = effective_quota_mask;
    end
  end

  generate
    if (NUM_REQ == 4) begin : gen_select_num4
      always_comb begin : select_comb
        logic [3:0] rotated_mask;
        logic [3:0] rotated_grant;
        logic [3:0] grant_4;

        sel_valid  = 1'b0;
        sel_idx    = '0;
        sel_onehot = '0;

        unique case (wrr_ptr_q)
          2'd0: rotated_mask = service_mask[3:0];
          2'd1: rotated_mask = {service_mask[0],   service_mask[3:1]};
          2'd2: rotated_mask = {service_mask[1:0], service_mask[3:2]};
          2'd3: rotated_mask = {service_mask[2:0], service_mask[3]};
          default: rotated_mask = service_mask[3:0];
        endcase

        rotated_grant[0] = rotated_mask[0];
        rotated_grant[1] = ~rotated_mask[0]    && rotated_mask[1];
        rotated_grant[2] = ~|rotated_mask[1:0] && rotated_mask[2];
        rotated_grant[3] = ~|rotated_mask[2:0] && rotated_mask[3];

        unique case (wrr_ptr_q)
          2'd0: grant_4 = rotated_grant;
          2'd1: grant_4 = {rotated_grant[2:0], rotated_grant[3]};
          2'd2: grant_4 = {rotated_grant[1:0], rotated_grant[3:2]};
          2'd3: grant_4 = {rotated_grant[0],   rotated_grant[3:1]};
          default: grant_4 = rotated_grant;
        endcase

        sel_valid  = |grant_4;
        sel_onehot = grant_4;

        unique case (1'b1)
          grant_4[0]: sel_idx = REQ_IDX_W'(0);
          grant_4[1]: sel_idx = REQ_IDX_W'(1);
          grant_4[2]: sel_idx = REQ_IDX_W'(2);
          grant_4[3]: sel_idx = REQ_IDX_W'(3);
          default:    sel_idx = '0;
        endcase
      end
    end else begin : gen_select_generic
      always_comb begin : select_comb
        int unsigned tmp_idx;

        sel_valid  = 1'b0;
        sel_idx    = '0;
        sel_onehot = '0;
        found      = 1'b0;
        search_idx = '0;

        for (int offset = 0; offset < NUM_REQ; offset++) begin
          tmp_idx = wrr_ptr_q + offset;
          if (tmp_idx >= NUM_REQ)
            tmp_idx = tmp_idx - NUM_REQ;

          search_idx = REQ_IDX_W'(tmp_idx);

          if (!found && service_mask[search_idx]) begin
            sel_valid              = 1'b1;
            sel_idx                = search_idx;
            sel_onehot[search_idx] = 1'b1;
            found                  = 1'b1;
          end
        end
      end
    end
  endgenerate

  assign grant_valid_o  = sel_valid;
  assign grant_idx_o    = sel_idx;
  assign grant_onehot_o = sel_onehot;

  always_comb begin : next_state_comb
    wrr_ptr_n = wrr_ptr_q;

    for (int i = 0; i < NUM_REQ; i++) begin
      quota_n[i] = quota_q[i];
    end

    if (advance_i && sel_valid) begin
      if (reload_needed) begin
        for (int i = 0; i < NUM_REQ; i++) begin
          if (eligible_i[i] && (weight_i[i] != '0)) begin
            quota_n[i] = weight_i[i];
          end else begin
            quota_n[i] = '0;
          end
        end
      end

      if (reload_needed) begin
        quota_n[sel_idx] = weight_i[sel_idx] - 1'b1;
      end else begin
        quota_n[sel_idx] = quota_q[sel_idx] - 1'b1;
      end

      for (int i = 0; i < NUM_REQ; i++) begin
        if (!eligible_i[i]) begin
          quota_n[i] = '0;
        end
      end

      if (sel_idx == NUM_REQ-1) begin
        wrr_ptr_n = '0;
      end else begin
        wrr_ptr_n = sel_idx + 1'b1;
      end
    end else begin
      for (int i = 0; i < NUM_REQ; i++) begin
        if (!eligible_i[i]) begin
          quota_n[i] = '0;
        end
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin : state_ff
    if (!rst_n) begin
      wrr_ptr_q <= '0;
      for (int i = 0; i < NUM_REQ; i++) begin
        quota_q[i] <= '0;
      end
    end else begin
      wrr_ptr_q <= wrr_ptr_n;
      for (int i = 0; i < NUM_REQ; i++) begin
        quota_q[i] <= quota_n[i];
      end
    end
  end

endmodule : wrr_arbiter
