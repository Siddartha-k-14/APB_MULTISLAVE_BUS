// -----------------------------------------------------------------------------
// apb_top.v : master + interconnect + N_SLAVES register slaves
//   Slave i has (i % 4) wait states so wait-state handling is exercised.
// -----------------------------------------------------------------------------
module apb_top #(
    parameter N_SLAVES    = 4,
    parameter ADDR_W      = 32,
    parameter DATA_W      = 32,
    parameter OFFSET_BITS = 12,
    parameter NUM_REGS    = 8
)(
    input  wire              PCLK,
    input  wire              PRESETn,

    input  wire              start,
    input  wire              wr,
    input  wire [ADDR_W-1:0] addr,
    input  wire [DATA_W-1:0] wdata,
    output wire              busy,
    output wire              done,
    output wire [DATA_W-1:0] rdata,
    output wire              err
);

    // APB bus
    wire [ADDR_W-1:0] PADDR;
    wire              PSEL, PENABLE, PWRITE;
    wire [DATA_W-1:0] PWDATA, PRDATA;
    wire              PREADY, PSLVERR;

    // per-slave signals
    wire [N_SLAVES-1:0]        PSELx, PREADYx, PSLVERRx;
    wire [N_SLAVES*DATA_W-1:0] PRDATAx;

    apb_master #(.ADDR_W(ADDR_W), .DATA_W(DATA_W)) u_master (
        .PCLK(PCLK), .PRESETn(PRESETn),
        .start(start), .wr(wr), .addr(addr), .wdata(wdata),
        .busy(busy), .done(done), .rdata(rdata), .err(err),
        .PADDR(PADDR), .PSEL(PSEL), .PENABLE(PENABLE), .PWRITE(PWRITE),
        .PWDATA(PWDATA), .PRDATA(PRDATA), .PREADY(PREADY), .PSLVERR(PSLVERR)
    );

    apb_interconnect #(
        .N_SLAVES(N_SLAVES), .ADDR_W(ADDR_W), .DATA_W(DATA_W), .OFFSET_BITS(OFFSET_BITS)
    ) u_ic (
        .PADDR(PADDR), .PSEL(PSEL), .PSELx(PSELx),
        .PRDATAx(PRDATAx), .PREADYx(PREADYx), .PSLVERRx(PSLVERRx),
        .PRDATA(PRDATA), .PREADY(PREADY), .PSLVERR(PSLVERR)
    );

    genvar g;
    generate
        for (g = 0; g < N_SLAVES; g = g + 1) begin : slaves
            apb_slave #(
                .ADDR_W(ADDR_W), .DATA_W(DATA_W), .OFFSET_BITS(OFFSET_BITS),
                .NUM_REGS(NUM_REGS), .WAIT_CYCLES(g % 4)
            ) u_slave (
                .PCLK(PCLK), .PRESETn(PRESETn),
                .PSEL(PSELx[g]), .PENABLE(PENABLE), .PWRITE(PWRITE),
                .PADDR(PADDR), .PWDATA(PWDATA),
                .PRDATA(PRDATAx[g*DATA_W +: DATA_W]),
                .PREADY(PREADYx[g]), .PSLVERR(PSLVERRx[g])
            );
        end
    endgenerate

endmodule
