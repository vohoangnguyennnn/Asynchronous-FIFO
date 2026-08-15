module sync_2ff #(
  parameter WIDTH = 5
)(
  input logic clk,
  input logic rst_n,
  input logic [WIDTH-1:0] din,
  output logic [WIDTH-1:0] dout
);

  // Preserve both stages and identify them as a CDC synchronizer chain.
  // Quartus defines ALTERA_RESERVED_QIS during synthesis; other tools retain
  // the portable ASYNC_REG marker without seeing vendor-specific attributes.
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
  logic [WIDTH-1:0] ff1, ff2;
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      ff1 <= '0;
      ff2 <= '0;
    end else begin
      ff1 <= din;
      ff2 <= ff1;
    end
  end

  assign dout = ff2;

endmodule
