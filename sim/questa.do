onerror {quit -code 1}

vsim -voptargs=+acc work.tb_async_fifo

add wave -divider {Testbench}
add wave sim:/tb_async_fifo/wr_clk
add wave sim:/tb_async_fifo/wr_rst_n
add wave sim:/tb_async_fifo/wr_en
add wave -radix hexadecimal sim:/tb_async_fifo/wr_data
add wave sim:/tb_async_fifo/full
add wave sim:/tb_async_fifo/rd_clk
add wave sim:/tb_async_fifo/rd_rst_n
add wave sim:/tb_async_fifo/rd_en
add wave -radix hexadecimal sim:/tb_async_fifo/rd_data
add wave sim:/tb_async_fifo/empty

add wave -divider {FIFO pointers}
add wave -radix unsigned sim:/tb_async_fifo/dut/wr_bin
add wave -radix hexadecimal sim:/tb_async_fifo/dut/wr_gray
add wave -radix unsigned sim:/tb_async_fifo/dut/rd_bin
add wave -radix hexadecimal sim:/tb_async_fifo/dut/rd_gray
add wave -radix hexadecimal sim:/tb_async_fifo/dut/wr_gray_sync_to_rd
add wave -radix hexadecimal sim:/tb_async_fifo/dut/rd_sync_gray_to_wr

run -all
wave zoom full

if {[batch_mode]} {
    quit -f
}
