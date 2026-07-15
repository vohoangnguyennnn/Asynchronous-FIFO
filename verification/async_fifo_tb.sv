`timescale 1ns/1ps

module tb_async_fifo;

    localparam int DATA_WIDTH       = 8;
    localparam int ADDR_WIDTH       = 4;
    localparam int FIFO_DEPTH       = 1 << ADDR_WIDTH;
    localparam int RANDOM_CYCLES    = 400;
    localparam int unsigned TB_SEED = 32'h1A2B_3C4D;

    logic wr_clk = 1'b0;
    logic rd_clk = 1'b0;
    logic wr_rst_n = 1'b0;
    logic rd_rst_n = 1'b0;
    logic wr_en = 1'b0;
    logic rd_en = 1'b0;
    logic [DATA_WIDTH-1:0] wr_data = '0;
    logic [DATA_WIDTH-1:0] rd_data;
    logic full;
    logic empty;

    logic [DATA_WIDTH-1:0] ref_q[$];
    semaphore ref_lock = new(1);
    int errors = 0;
    int accepted_writes = 0;
    int accepted_reads = 0;
    bit writer_done = 1'b0;

    always #5 wr_clk = ~wr_clk;  // 100 MHz
    always #7 rd_clk = ~rd_clk;  // approximately 71 MHz

    async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk_wr   (wr_clk),
        .rst_n_wr (wr_rst_n),
        .wr_en    (wr_en),
        .wr_data  (wr_data),
        .full     (full),
        .clk_rd   (rd_clk),
        .rst_n_rd (rd_rst_n),
        .rd_en    (rd_en),
        .rd_data  (rd_data),
        .empty    (empty)
    );

    task automatic check(input logic condition, input string message);
        if (condition !== 1'b1) begin
            errors++;
            $error("%s", message);
        end
    endtask

    task automatic report_phase(input string name, input int errors_before);
        if (errors == errors_before)
            $display("[%0t] PASS: %s", $time, name);
        else
            $display("[%0t] FAIL: %s", $time, name);
    endtask

    task automatic apply_reset();
        wr_en = 1'b0;
        rd_en = 1'b0;
        wr_rst_n = 1'b0;
        rd_rst_n = 1'b0;
        ref_q.delete();

        repeat (4) @(posedge wr_clk);
        repeat (4) @(posedge rd_clk);
        @(negedge wr_clk) wr_rst_n = 1'b1;
        @(negedge rd_clk) rd_rst_n = 1'b1;
        repeat (3) @(negedge rd_clk);
    endtask

    // Drive on falling edges so inputs are stable before the DUT samples them.
    task automatic write_word(input logic [DATA_WIDTH-1:0] data);
        do @(negedge wr_clk); while (full !== 1'b0);
        wr_data = data;
        wr_en = 1'b1;
        @(negedge wr_clk) wr_en = 1'b0;
    endtask

    task automatic read_word();
        do @(negedge rd_clk); while (empty !== 1'b0);
        rd_en = 1'b1;
        @(negedge rd_clk) rd_en = 1'b0;
    endtask

    // Only monitors update the reference model, using accepted transactions.
    always @(posedge wr_clk) begin
        if (wr_rst_n && wr_en && !full) begin
            ref_lock.get(1);
            ref_q.push_back(wr_data);
            ref_lock.put(1);
            accepted_writes++;
        end
    end

    always @(posedge rd_clk) begin : read_monitor
        logic [DATA_WIDTH-1:0] expected;

        if (rd_rst_n && rd_en && !empty) begin
            ref_lock.get(1);
            if (ref_q.size() == 0) begin
                errors++;
                $error("Reference queue underflow");
            end else begin
                expected = ref_q.pop_front();
                if (rd_data !== expected) begin
                    errors++;
                    $error("Data mismatch: expected=%0h got=%0h", expected, rd_data);
                end
            end
            ref_lock.put(1);
            accepted_reads++;
        end
    end

    task automatic random_writer();
        repeat (RANDOM_CYCLES) begin
            @(negedge wr_clk);
            wr_en = (full === 1'b0) && ($urandom_range(0, 99) < 70);
            wr_data = $urandom();
        end
        @(negedge wr_clk) wr_en = 1'b0;
        writer_done = 1'b1;
    endtask

    task automatic random_reader();
        while (!writer_done) begin
            @(negedge rd_clk);
            rd_en = (empty === 1'b0) && ($urandom_range(0, 99) < 65);
        end
        @(negedge rd_clk) rd_en = 1'b0;
    endtask

    task automatic drain_remaining();
        while ((ref_q.size() != 0) || (empty !== 1'b1)) begin
            @(negedge rd_clk);
            rd_en = (empty === 1'b0);
        end
        @(negedge rd_clk) rd_en = 1'b0;
    endtask

    // Gray pointers must change by zero or one bit at each local clock edge.
    property write_gray_one_bit;
        @(posedge wr_clk) disable iff (!wr_rst_n)
        $onehot0(dut.wr_gray ^ $past(dut.wr_gray));
    endproperty
    assert property (write_gray_one_bit)
    else begin
        errors++;
        $error("Write Gray pointer changed by more than one bit");
    end

    property read_gray_one_bit;
        @(posedge rd_clk) disable iff (!rd_rst_n)
        $onehot0(dut.rd_gray ^ $past(dut.rd_gray));
    endproperty
    assert property (read_gray_one_bit)
    else begin
        errors++;
        $error("Read Gray pointer changed by more than one bit");
    end

    initial begin : watchdog
        #100_000;
        $fatal(1, "Simulation timeout");
    end

    initial begin : test_sequence
        int errors_before;
        int writes_before_random;
        int unsigned seed;
        logic [ADDR_WIDTH:0] pointer_before;

        seed = TB_SEED;
        void'($urandom(seed));

        $display("============================================================");
        $display("Async FIFO self-checking testbench (seed=0x%08h)", TB_SEED);
        $display("============================================================");

        // Reset behavior.
        errors_before = errors;
        apply_reset();
        check(empty === 1'b1, "empty must be 1 after reset");
        check(full === 1'b0, "full must be 0 after reset");
        check(dut.wr_bin == '0, "write pointer must reset to zero");
        check(dut.rd_bin == '0, "read pointer must reset to zero");
        report_phase("reset state", errors_before);

        // Fill, overflow attempt, ordered drain, and underflow attempt.
        errors_before = errors;
        for (int i = 0; i < FIFO_DEPTH; i++)
            write_word(DATA_WIDTH'(i));

        while (full !== 1'b1) @(negedge wr_clk);
        check(accepted_writes == FIFO_DEPTH,
              "FIFO did not accept exactly FIFO_DEPTH writes");

        pointer_before = dut.wr_bin;
        @(negedge wr_clk);
        wr_data = '1;
        wr_en = 1'b1;
        @(negedge wr_clk) wr_en = 1'b0;
        check(dut.wr_bin == pointer_before,
              "write pointer changed during overflow attempt");

        for (int i = 0; i < FIFO_DEPTH; i++)
            read_word();
        while (empty !== 1'b1) @(negedge rd_clk);

        pointer_before = dut.rd_bin;
        @(negedge rd_clk) rd_en = 1'b1;
        @(negedge rd_clk) rd_en = 1'b0;
        check(dut.rd_bin == pointer_before,
              "read pointer changed during underflow attempt");
        check(ref_q.size() == 0, "scoreboard not empty after directed test");
        report_phase("fill/drain ordering and boundary protection", errors_before);

        // Concurrent traffic continues from pointer value FIFO_DEPTH. More
        // than FIFO_DEPTH additional writes guarantees at least one wrap.
        errors_before = errors;
        writes_before_random = accepted_writes;
        writer_done = 1'b0;
        fork
            random_writer();
            random_reader();
        join
        drain_remaining();

        check((accepted_writes - writes_before_random) > FIFO_DEPTH,
              "random test did not exercise pointer wrap-around");
        check(accepted_reads == accepted_writes,
              "accepted read/write counts differ");
        check(ref_q.size() == 0, "scoreboard not empty after random test");
        report_phase("concurrent random traffic and pointer wrap-around",
                     errors_before);

        $display("============================================================");
        if (errors == 0) begin
            $display("TEST PASSED - writes=%0d reads=%0d",
                     accepted_writes, accepted_reads);
            $display("============================================================");
            $finish;
        end else begin
            $display("TEST FAILED - errors=%0d", errors);
            $display("============================================================");
            $fatal(1, "Async FIFO verification failed");
        end
    end

endmodule
