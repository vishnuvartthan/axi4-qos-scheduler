`timescale 1ns/1ps

module age_tracker #(
  parameter int unsigned NUM_REQ          = 4,
  parameter int unsigned AGE_W            = 8,
  parameter bit          REGISTER_STARVED = 1'b0
) (
  input  logic                        clk,
  input  logic                        rst_n,
  input  logic [NUM_REQ-1:0]          pending_i,
  input  logic [NUM_REQ-1:0]          serve_i,
  input  logic [AGE_W-1:0]            aging_threshold_i,
  output logic [AGE_W-1:0]            age_o [NUM_REQ],
  output logic [NUM_REQ-1:0]          starved_o
);

  logic [AGE_W-1:0]   age_q [NUM_REQ];
  logic [AGE_W-1:0]   age_n [NUM_REQ];
  logic [NUM_REQ-1:0] starved_n;
  logic [NUM_REQ-1:0] starved_q;

  always_comb begin : age_next_comb
    starved_n = '0;

    for (int i = 0; i < NUM_REQ; i++) begin
      age_n[i] = age_q[i];

      unique case ({pending_i[i], serve_i[i]})
        2'b00: age_n[i] = '0;
        2'b01: age_n[i] = '0;
        2'b10: begin
          if (age_q[i] == {AGE_W{1'b1}})
            age_n[i] = age_q[i];
          else
            age_n[i] = age_q[i] + 1'b1;
        end
        2'b11: age_n[i] = '0;
        default: age_n[i] = age_q[i];
      endcase

      starved_n[i] = pending_i[i] && !serve_i[i] && (age_n[i] >= aging_threshold_i);
    end
  end

  genvar g;
  generate
    for (g = 0; g < NUM_REQ; g++) begin : gen_age_out
      assign age_o[g] = age_q[g];
    end

    if (REGISTER_STARVED) begin : gen_registered_starved
      assign starved_o = starved_q;
    end else begin : gen_comb_starved
      for (g = 0; g < NUM_REQ; g++) begin : gen_starved_comb
        assign starved_o[g] = pending_i[g] && (age_q[g] >= aging_threshold_i);
      end
    end
  endgenerate

  always_ff @(posedge clk or negedge rst_n) begin : age_seq
    if (!rst_n) begin
      starved_q <= '0;
      for (int i = 0; i < NUM_REQ; i++) begin
        age_q[i] <= '0;
      end
    end else begin
      starved_q <= starved_n;
      for (int i = 0; i < NUM_REQ; i++) begin
        age_q[i] <= age_n[i];
      end
    end
  end

endmodule : age_tracker
