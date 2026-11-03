module async_fifo #(
  parameter int unsigned DATA_WIDTH = 8,
  parameter int unsigned ADDR_WIDTH = 5
)(
  // write side
  input logic clk_wr,
  input logic arst_n,
  input logic wr_en,
  input logic [DATA_WIDTH-1:0] wr_data,
  output logic full,

  // read side
  input logic clk_rd,
  input logic rd_en,
  output logic [DATA_WIDTH-1:0] rd_data,
  output logic empty
);

  localparam int unsigned FIFO_DEPTH = 1 << ADDR_WIDTH;
  localparam int unsigned PTR_WIDTH  = ADDR_WIDTH + 1;
  localparam logic [PTR_WIDTH-1:0] FULL_COMPARE_MASK = {2'b11, {(PTR_WIDTH-2){1'b0}}};

  logic [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1]; // dual-port memory
  logic [PTR_WIDTH-1:0] wr_bin, wr_gray;
  logic [PTR_WIDTH-1:0] wr_bin_next, wr_gray_next;
  logic [PTR_WIDTH-1:0] rd_bin, rd_gray;
  logic [PTR_WIDTH-1:0] rd_bin_next, rd_gray_next;
  logic wr_accept;
  logic rd_accept;
  logic [PTR_WIDTH-1:0] wr_gray_sync_to_rd; // write pointer, seen by read side
  logic [PTR_WIDTH-1:0] rd_sync_gray_to_wr; // read pointer, seen by write side
  logic wr_rst_n;
  logic rd_rst_n;
  logic full_next;
  logic empty_next;

  assign wr_accept = wr_en && !full;
  assign rd_accept = rd_en && !empty;

  initial begin
    if (DATA_WIDTH < 1)
      $fatal(1, "async_fifo requires DATA_WIDTH >= 1");
    if (ADDR_WIDTH < 1)
      $fatal(1, "async_fifo requires ADDR_WIDTH >= 1");
  end

  // A common FIFO reset flushes both pointer domains. Assertion is
  // asynchronous; release is synchronized independently in each domain.
  reset_sync wr_reset_sync (
    .clk(clk_wr),
    .arst_n(arst_n),
    .srst_n(wr_rst_n)
  );

  reset_sync rd_reset_sync (
    .clk(clk_rd),
    .arst_n(arst_n),
    .srst_n(rd_rst_n)
  );

  gray_counter #(.ADDR_WIDTH(ADDR_WIDTH)) wr_counter (
    .clk(clk_wr),
    .rst_n(wr_rst_n),
    .en(wr_accept),
    .bin_ptr(wr_bin),
    .gray_ptr(wr_gray),
    .bin_next(wr_bin_next),
    .gray_next(wr_gray_next)
  );

  gray_counter #(.ADDR_WIDTH(ADDR_WIDTH)) rd_counter (
    .clk(clk_rd),
    .rst_n(rd_rst_n),
    .en(rd_accept),
    .bin_ptr(rd_bin),
    .gray_ptr(rd_gray),
    .bin_next(rd_bin_next),
    .gray_next(rd_gray_next)
  );

  // write pointer to read clock domain
  sync_2ff #(.WIDTH(PTR_WIDTH)) sync_wr_to_rd (
    .clk(clk_rd),
    .rst_n(rd_rst_n),
    .din(wr_gray),
    .dout(wr_gray_sync_to_rd)
  );

  // read pointer to write clock domain
  sync_2ff #(.WIDTH(PTR_WIDTH)) sync_rd_to_wr (
    .clk(clk_wr),
    .rst_n(wr_rst_n),
    .din(rd_gray),
    .dout(rd_sync_gray_to_wr)
  );

  always_comb begin
    full_next = (wr_gray_next == (rd_sync_gray_to_wr ^ FULL_COMPARE_MASK));
    empty_next = (rd_gray_next == wr_gray_sync_to_rd);
  end

  always_ff @(posedge clk_wr or negedge wr_rst_n) begin
    if (!wr_rst_n)
      full <= 1'b0;
    else
      full <= full_next;
  end

  always_ff @(posedge clk_rd or negedge rd_rst_n) begin
    if (!rd_rst_n)
      empty <= 1'b1;
    else
      empty <= empty_next;
  end

  always_ff @(posedge clk_wr) begin
    if (wr_accept) begin
      mem[wr_bin[ADDR_WIDTH-1:0]] <= wr_data;
    end
  end

  assign rd_data = mem[rd_bin[ADDR_WIDTH-1:0]];

endmodule
