onerror {quit -code 1}

# Keep visibility for the small set of internal CDC/RDC evidence signals.
# Suppress only the corresponding optimization notice; design warnings remain.
vsim -suppress 10908 -voptargs=+acc work.tb_async_fifo

if {![batch_mode]} {
add wave -divider {FIFO interface}
add wave sim:/tb_async_fifo/wr_clk
add wave sim:/tb_async_fifo/arst_n
add wave sim:/tb_async_fifo/dut/wr_rst_n
add wave sim:/tb_async_fifo/wr_en
add wave -radix hexadecimal sim:/tb_async_fifo/wr_data
add wave sim:/tb_async_fifo/full
add wave sim:/tb_async_fifo/rd_clk
add wave sim:/tb_async_fifo/dut/rd_rst_n
add wave sim:/tb_async_fifo/rd_en
add wave -radix hexadecimal sim:/tb_async_fifo/rd_data
add wave sim:/tb_async_fifo/empty

add wave -divider {Gray pointer CDC}
add wave -radix unsigned sim:/tb_async_fifo/dut/wr_bin
add wave -radix hexadecimal sim:/tb_async_fifo/dut/wr_gray
add wave -radix hexadecimal sim:/tb_async_fifo/dut/sync_wr_to_rd/ff1
add wave -radix hexadecimal sim:/tb_async_fifo/dut/wr_gray_sync_to_rd
add wave -radix unsigned sim:/tb_async_fifo/dut/rd_bin
add wave -radix hexadecimal sim:/tb_async_fifo/dut/rd_gray
add wave -radix hexadecimal sim:/tb_async_fifo/dut/sync_rd_to_wr/ff1
add wave -radix hexadecimal sim:/tb_async_fifo/dut/rd_sync_gray_to_wr

add wave -divider {Reset synchronization}
add wave -radix binary sim:/tb_async_fifo/dut/wr_reset_sync/sync_ff
add wave -radix binary sim:/tb_async_fifo/dut/rd_reset_sync/sync_ff
}

run -all

if {[batch_mode]} {
    quit -f
} else {
    wave zoom full
}
