module sync_2ff #(
  parameter WIDTH = 5
)(
  input logic clk,
  input logic rst_n,
  input logic [WIDTH-1:0] din,
  output logic [WIDTH-1:0] dout
);

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


