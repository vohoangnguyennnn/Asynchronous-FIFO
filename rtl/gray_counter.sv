module gray_counter #(
  parameter int unsigned ADDR_WIDTH = 5
)(
  input  logic clk,
  input  logic rst_n,
  input  logic en,
  output logic [ADDR_WIDTH:0] bin_ptr,
  output logic [ADDR_WIDTH:0] gray_ptr,
  output logic [ADDR_WIDTH:0] bin_next,
  output logic [ADDR_WIDTH:0] gray_next
);

  initial begin
    if (ADDR_WIDTH < 1)
      $fatal(1, "gray_counter requires ADDR_WIDTH >= 1");
  end

  always_comb begin
    bin_next = bin_ptr + {{ADDR_WIDTH{1'b0}}, en};
    gray_next = (bin_next >> 1) ^ bin_next;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      bin_ptr <= '0;
      gray_ptr <= '0;
    end else begin
      bin_ptr <= bin_next;
      gray_ptr <= gray_next;
    end
  end

endmodule
