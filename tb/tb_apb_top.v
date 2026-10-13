`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// tb_apb_top.v : self-checking testbench (works for RTL and gate-level netlist)
//   Uses only top-level ports, so the same file runs on the Yosys netlist.
//   Built for N = 4 slaves (matches apb_top default parameters).
//   Run:  vvp sim/rtl.vvp +vcd=sim/rtl.vcd
// -----------------------------------------------------------------------------
module tb_apb_top;

    localparam ADDR_W      = 32;
    localparam DATA_W      = 32;
    localparam N           = 4;
    localparam OFFSET_BITS = 12;
    localparam NUM_REGS    = 8;

    reg              PCLK    = 1'b0;
    reg              PRESETn = 1'b0;
    reg              start   = 1'b0;
    reg              wr      = 1'b0;
    reg  [ADDR_W-1:0] addr   = {ADDR_W{1'b0}};
    reg  [DATA_W-1:0] wdata  = {DATA_W{1'b0}};
    wire             busy, done, err;
    wire [DATA_W-1:0] rdata;

    apb_top dut (
        .PCLK(PCLK), .PRESETn(PRESETn),
        .start(start), .wr(wr), .addr(addr), .wdata(wdata),
        .busy(busy), .done(done), .rdata(rdata), .err(err)
    );

    always #5 PCLK = ~PCLK;                 // 100 MHz

    // ---------------- bookkeeping ----------------
    integer errors = 0;
    integer checks = 0;
    reg [DATA_W-1:0] rd;
    reg              e;
    integer          bc;                    // busy-cycle counter (transfer length)

    always @(posedge PCLK) if (busy) bc = bc + 1;

    // ---------------- helpers ----------------
    // One APB transfer through the master. Signals are driven on the falling
    // edge so there are no races with the rising-edge logic.
    task xfer(input w, input [ADDR_W-1:0] a, input [DATA_W-1:0] d);
    begin
        @(negedge PCLK);
        bc = 0;
        start = 1'b1; wr = w; addr = a; wdata = d;
        @(negedge PCLK);
        start = 1'b0;
        while (!done) @(negedge PCLK);
        rd = rdata;
        e  = err;
    end
    endtask

    task check_write(input [ADDR_W-1:0] a, input [DATA_W-1:0] d, input exp_err);
    begin
        xfer(1'b1, a, d);
        checks = checks + 1;
        if (e !== exp_err) begin
            errors = errors + 1;
            $display("FAIL write addr=%h err=%b expected err=%b", a, e, exp_err);
        end
    end
    endtask

    task check_read(input [ADDR_W-1:0] a, input [DATA_W-1:0] exp_d, input exp_err);
    begin
        xfer(1'b0, a, {DATA_W{1'b0}});
        checks = checks + 1;
        if (rd !== exp_d || e !== exp_err) begin
            errors = errors + 1;
            $display("FAIL read  addr=%h data=%h err=%b | expected data=%h err=%b",
                     a, rd, e, exp_d, exp_err);
        end
    end
    endtask

    function [ADDR_W-1:0] base_of(input integer s);
        base_of = s << OFFSET_BITS;
    endfunction

    function [DATA_W-1:0] pattern(input integer s, input integer r);
        pattern = (s << 24) | (r << 16) | 32'h0000C0DE;
    endfunction

    // ---------------- test sequence ----------------
    integer i, r;
    reg [255:0] vcdname;

    initial begin
        if (!$value$plusargs("vcd=%s", vcdname)) vcdname = "apb_tb.vcd";
        $dumpfile(vcdname);
        $dumpvars(0, tb_apb_top);
    end

    // watchdog: a hung bus must not hang the simulation
    initial begin
        #5000000;
        $display("TIMEOUT: simulation hung");
        $finish;
    end

    initial begin
        bc = 0;
        // ---- Test 1: reset ----
        repeat (4) @(negedge PCLK);
        PRESETn = 1'b1;
        @(negedge PCLK);
        checks = checks + 1;
        if (busy !== 1'b0) begin errors = errors + 1; $display("FAIL: busy after reset"); end
        $display("T1 reset done");

        // ---- Test 2: write then read back, first register of every slave ----
        for (i = 0; i < N; i = i + 1)
            check_write(base_of(i), pattern(i, 0), 1'b0);
        for (i = 0; i < N; i = i + 1)
            check_read(base_of(i), pattern(i, 0), 1'b0);
        $display("T2 write/read reg0 of every slave done");

        // ---- Test 3: all registers of all slaves (also detects aliasing) ----
        for (i = 0; i < N; i = i + 1)
            for (r = 0; r < NUM_REGS; r = r + 1)
                check_write(base_of(i) + r*4, pattern(i, r), 1'b0);
        for (i = 0; i < N; i = i + 1)
            for (r = 0; r < NUM_REGS; r = r + 1)
                check_read(base_of(i) + r*4, pattern(i, r), 1'b0);
        $display("T3 full register sweep done");

        // ---- Test 4: back-to-back transfers, alternating slaves ----
        for (r = 0; r < 16; r = r + 1) begin
            check_write(base_of(r % N) + 4, 32'hA000_0000 + r, 1'b0);
            check_read (base_of(r % N) + 4, 32'hA000_0000 + r, 1'b0);
        end
        $display("T4 back-to-back done");

        // ---- Test 5: wait states (slave i inserts i wait states) ----
        // transfer length in cycles = SETUP(1) + ACCESS(1) + waits
        for (i = 0; i < N; i = i + 1) begin
            xfer(1'b0, base_of(i), 32'h0);
            checks = checks + 1;
            if (bc !== (2 + (i % 4))) begin
                errors = errors + 1;
                $display("FAIL wait states slave %0d: %0d busy cycles, expected %0d",
                         i, bc, 2 + (i % 4));
            end
        end
        $display("T5 wait states done");

        // ---- Test 6: PSLVERR for out-of-range offset inside a valid slave ----
        for (i = 0; i < N; i = i + 1) begin
            check_write(base_of(i), 32'h1111_0000 + i, 1'b0);
            check_write(base_of(i) + 12'h100, 32'hDEAD_BEEF, 1'b1);   // invalid offset
            check_read (base_of(i) + 12'h100, 32'h0, 1'b1);
            check_read (base_of(i), 32'h1111_0000 + i, 1'b0);         // reg0 not corrupted
        end
        $display("T6 slave error response done");

        // ---- Test 7: unmapped addresses (must answer with error, not hang) ----
        check_write(base_of(N),      32'h1234_5678, 1'b1);
        check_read (base_of(N),      32'h0,         1'b1);
        check_read (32'hFFFF_F000,   32'h0,         1'b1);
        check_read (base_of(N + 3) + 4, 32'h0,      1'b1);
        $display("T7 unmapped addresses done");

        // ---- Test 8: first / last valid address and first invalid address ----
        for (i = 0; i < N; i = i + 1) begin
            check_write(base_of(i) + 12'h000, 32'hF000_0000 + i, 1'b0);              // first
            check_write(base_of(i) + (NUM_REGS-1)*4, 32'hE000_0000 + i, 1'b0);       // last valid
            check_write(base_of(i) + NUM_REGS*4, 32'h5555_5555, 1'b1);               // first invalid
            check_write(base_of(i) + 12'hFFC, 32'h5555_5555, 1'b1);                  // end of region
            check_read (base_of(i) + 12'h000, 32'hF000_0000 + i, 1'b0);
            check_read (base_of(i) + (NUM_REGS-1)*4, 32'hE000_0000 + i, 1'b0);
        end
        $display("T8 boundary addresses done");

        // ---- Test 9: reset asserted in the middle of a transfer ----
        check_write(base_of(3), 32'h1234_5678, 1'b0);
        @(negedge PCLK);
        start = 1'b1; wr = 1'b1; addr = base_of(3); wdata = 32'hFFFF_FFFF;
        @(negedge PCLK);
        start = 1'b0;                       // master now in SETUP
        @(negedge PCLK);                    // master in ACCESS, slave 3 stalling
        PRESETn = 1'b0;                     // abort mid-transfer
        #1;
        checks = checks + 1;
        if (busy !== 1'b0) begin errors = errors + 1; $display("FAIL: busy during reset"); end
        @(negedge PCLK);
        @(negedge PCLK);
        PRESETn = 1'b1;
        @(negedge PCLK);
        checks = checks + 1;
        if (busy !== 1'b0 || done !== 1'b0) begin
            errors = errors + 1; $display("FAIL: bus not idle after mid-transfer reset");
        end
        check_read(base_of(3), 32'h0, 1'b0);   // registers cleared by reset
        check_write(base_of(3), 32'h0BAD_F00D, 1'b0);   // bus usable again
        check_read (base_of(3), 32'h0BAD_F00D, 1'b0);
        $display("T9 reset mid-transfer done");

        // ---- summary ----
        $display("--------------------------------------------");
        $display("Checks run : %0d", checks);
        $display("Errors     : %0d", errors);
        if (errors == 0) $display("RESULT: ALL TESTS PASSED");
        else             $display("RESULT: TESTS FAILED");
        $display("--------------------------------------------");
        $finish;
    end

endmodule
