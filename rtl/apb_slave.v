// -----------------------------------------------------------------------------
// apb_slave.v : simple register-based APB peripheral
//   - NUM_REGS word registers at byte offsets 0x00, 0x04, 0x08, ...
//   - WAIT_CYCLES wait states (PREADY low for that many ACCESS cycles)
//   - PSLVERR when the offset is outside the implemented registers
// -----------------------------------------------------------------------------
module apb_slave #(
    parameter ADDR_W      = 32,
    parameter DATA_W      = 32,
    parameter OFFSET_BITS = 12,   // each slave owns a 2^OFFSET_BITS byte region
    parameter NUM_REGS    = 8,
    parameter WAIT_CYCLES = 0
)(
    input  wire              PCLK,
    input  wire              PRESETn,
    input  wire              PSEL,
    input  wire              PENABLE,
    input  wire              PWRITE,
    input  wire [ADDR_W-1:0] PADDR,
    input  wire [DATA_W-1:0] PWDATA,
    output wire [DATA_W-1:0] PRDATA,
    output wire              PREADY,
    output wire              PSLVERR
);

    localparam IDX_W = (NUM_REGS > 1) ? $clog2(NUM_REGS) : 1;

    // Registers stored as one flat vector (keeps synthesis simple: plain flops)
    reg [NUM_REGS*DATA_W-1:0] regs_flat;
    reg [7:0]                 wait_cnt;

    wire [OFFSET_BITS-3:0] word  = PADDR[OFFSET_BITS-1:2];   // word offset in region
    wire                   valid = (word < NUM_REGS);
    wire [IDX_W-1:0]       idx   = word[IDX_W-1:0];
    wire                   access = PSEL & PENABLE;          // ACCESS phase

    // Wait states: PREADY goes high once wait_cnt reaches WAIT_CYCLES
    assign PREADY  = (wait_cnt >= WAIT_CYCLES);
    assign PSLVERR = access & ~valid;
    assign PRDATA  = valid ? regs_flat[idx*DATA_W +: DATA_W] : {DATA_W{1'b0}};

    integer k;
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            regs_flat <= {NUM_REGS*DATA_W{1'b0}};
            wait_cnt  <= 8'd0;
        end else begin
            // count wait states while the transfer is stalled
            if (access && !PREADY)
                wait_cnt <= wait_cnt + 8'd1;
            else
                wait_cnt <= 8'd0;

            // write completes on the cycle where PSEL & PENABLE & PREADY
            if (access && PREADY && PWRITE && valid) begin
                for (k = 0; k < NUM_REGS; k = k + 1)
                    if (idx == k)
                        regs_flat[k*DATA_W +: DATA_W] <= PWDATA;
            end
        end
    end

endmodule
