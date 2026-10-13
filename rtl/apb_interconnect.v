// -----------------------------------------------------------------------------
// apb_interconnect.v : parameterized address decoder + response mux
//   Address map : slave i occupies [i << OFFSET_BITS, (i+1) << OFFSET_BITS)
//                 (default: 4 KB each -> slave0 = 0x0000, slave1 = 0x1000, ...)
//   Unmapped    : if the address hits no slave, the interconnect itself answers
//                 with PREADY = 1 and PSLVERR = 1 so the bus never hangs.
// -----------------------------------------------------------------------------
module apb_interconnect #(
    parameter N_SLAVES    = 4,
    parameter ADDR_W      = 32,
    parameter DATA_W      = 32,
    parameter OFFSET_BITS = 12
)(
    // from master
    input  wire [ADDR_W-1:0]           PADDR,
    input  wire                        PSEL,

    // to slaves
    output wire [N_SLAVES-1:0]         PSELx,

    // from slaves
    input  wire [N_SLAVES*DATA_W-1:0]  PRDATAx,
    input  wire [N_SLAVES-1:0]         PREADYx,
    input  wire [N_SLAVES-1:0]         PSLVERRx,

    // back to master
    output reg  [DATA_W-1:0]           PRDATA,
    output reg                         PREADY,
    output reg                         PSLVERR
);

    localparam REGION_W = ADDR_W - OFFSET_BITS;

    wire [REGION_W-1:0] region = PADDR[ADDR_W-1:OFFSET_BITS];
    wire [N_SLAVES-1:0] hit;

    // ---- address decoder / PSELx generation ----
    genvar g;
    generate
        for (g = 0; g < N_SLAVES; g = g + 1) begin : dec
            assign hit[g]   = (region == g);
            assign PSELx[g] = PSEL & hit[g];
        end
    endgenerate

    // ---- response mux (AND-OR form, hit is one-hot) ----
    integer i;
    always @* begin
        PRDATA  = {DATA_W{1'b0}};
        PREADY  = 1'b0;
        PSLVERR = 1'b0;
        for (i = 0; i < N_SLAVES; i = i + 1) begin
            if (hit[i]) begin
                PRDATA  = PRDATA  | PRDATAx[i*DATA_W +: DATA_W];
                PREADY  = PREADY  | PREADYx[i];
                PSLVERR = PSLVERR | PSLVERRx[i];
            end
        end
        // default responder for unmapped addresses
        if (!(|hit)) begin
            PRDATA  = {DATA_W{1'b0}};
            PREADY  = 1'b1;
            PSLVERR = 1'b1;
        end
    end

endmodule
