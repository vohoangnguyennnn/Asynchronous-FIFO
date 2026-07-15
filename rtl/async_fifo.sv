module async_fifo #(
  parameter DATA_WIDTH = 8,
  parameter ADDR_WIDTH = 5
)(
  // write side
  input logic clk_wr,
  input logic rst_n_wr,
  input logic wr_en,
  input logic [DATA_WIDTH-1:0] wr_data,
  output logic full,

  // read side
  input logic clk_rd,
  input logic rst_n_rd,
  input logic rd_en,
  output logic [DATA_WIDTH-1:0] rd_data,
  output logic empty
);

  logic [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1]; // dual-port memory
  logic [ADDR_WIDTH:0] wr_bin, wr_gray;
  logic [ADDR_WIDTH:0] rd_bin, rd_gray;
  logic [ADDR_WIDTH:0] wr_gray_sync_to_rd; // write pointer, seen by read side
  logic [ADDR_WIDTH:0] rd_sync_gray_to_wr; // read pointer, seen by write side

  gray_counter #(.ADDR_WIDTH(ADDR_WIDTH)) wr_counter (
    .clk(clk_wr),
    .rst_n(rst_n_wr),
    .en(wr_en && !full),
    .bin_ptr(wr_bin),
    .gray_ptr(wr_gray)
  );

  gray_counter #(.ADDR_WIDTH(ADDR_WIDTH)) rd_counter (
    .clk(clk_rd),
    .rst_n(rst_n_rd),
    .en(rd_en && !empty),
    .bin_ptr(rd_bin),
    .gray_ptr(rd_gray)
  );

  // write pointer to read clock domain
  sync_2ff #(.WIDTH(ADDR_WIDTH+1)) sync_wr_to_rd (
    .clk(clk_rd),
    .rst_n(rst_n_rd),
    .din(wr_gray),
    .dout(wr_gray_sync_to_rd)
  );

  // read pointer to write clock domain
  sync_2ff #(.WIDTH(ADDR_WIDTH+1)) sync_rd_to_wr (
    .clk(clk_wr),
    .rst_n(rst_n_wr),
    .din(rd_gray),
    .dout(rd_sync_gray_to_wr)
  );

  always_comb begin
    full = (wr_gray == {~rd_sync_gray_to_wr[ADDR_WIDTH:ADDR_WIDTH-1], rd_sync_gray_to_wr[ADDR_WIDTH-2:0]});
    empty = (rd_gray == wr_gray_sync_to_rd);
  end

  always_ff @(posedge clk_wr) begin
    if (wr_en && !full) begin
      mem[wr_bin[ADDR_WIDTH-1:0]] <= wr_data;
    end
  end

  assign rd_data = mem[rd_bin[ADDR_WIDTH-1:0]];

endmodule