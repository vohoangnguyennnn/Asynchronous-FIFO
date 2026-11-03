module reset_sync #(
  parameter int unsigned STAGES = 2
)(
  input logic clk,
  input logic arst_n,
  output logic srst_n
);

  // Intentional reset synchronizer: asynchronous assertion enters the chain,
  // while each subsequent stage is sampled synchronously by clk.
  /* verilator lint_off SYNCASYNCNET */
`ifdef ALTERA_RESERVED_QIS
  (* altera_attribute = {
    "-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW; ",
    "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS; ",
    "-name DONT_MERGE_REGISTER ON; ",
    "-name PRESERVE_REGISTER ON"
  } *)
`else
  (* ASYNC_REG = "TRUE" *)
`endif
  logic [STAGES-1:0] sync_ff;

  initial begin
    if (STAGES < 2)
      $fatal(1, "reset_sync requires STAGES >= 2");
  end

  always_ff @(posedge clk or negedge arst_n) begin
    if (!arst_n) begin
      sync_ff <= '0;
    end else begin
      sync_ff[0] <= 1'b1;
      for (int unsigned stage = 1; stage < STAGES; stage++)
        sync_ff[stage] <= sync_ff[stage-1];
    end
  end

  assign srst_n = sync_ff[STAGES-1];
  /* verilator lint_on SYNCASYNCNET */

endmodule
