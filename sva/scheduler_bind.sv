bind scheduler_channel scheduler_sva #(
  .NUM_REQ   (NUM_REQ),
  .REQ_W     (REQ_W),
  .REQ_IDX_W (REQ_IDX_W)
) u_scheduler_sva (
  .clk        (clk),
  .rst_n      (rst_n),
  .out_valid  (core_out_valid),
  .out_ready  (core_out_ready),
  .out_data   (core_out_data),
  .out_src_idx(core_out_src_idx),
  .fifo_pop   (fifo_pop),
  .serve      (serve)
);
