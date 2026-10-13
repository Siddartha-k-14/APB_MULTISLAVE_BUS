// -----------------------------------------------------------------------------
// apb_master.v : APB master / requester
//   Command side : pulse 'start' with wr/addr/wdata while busy == 0
//   Result side  : 'done' pulses for one cycle; rdata and err are valid then
//   FSM          : IDLE -> SETUP -> ACCESS -> IDLE (ACCESS repeats until PREADY)
// -----------------------------------------------------------------------------
module apb_master #(
    parameter ADDR_W = 32,
    parameter DATA_W = 32
)(
    input  wire              PCLK,
    input  wire              PRESETn,

    // command interface
    input  wire              start,
    input  wire              wr,
    input  wire [ADDR_W-1:0] addr,
    input  wire [DATA_W-1:0] wdata,
    output wire              busy,
    output reg               done,
    output reg  [DATA_W-1:0] rdata,
    output reg               err,

    // APB master interface
    output reg  [ADDR_W-1:0] PADDR,
    output wire              PSEL,
    output wire              PENABLE,
    output reg               PWRITE,
    output reg  [DATA_W-1:0] PWDATA,
    input  wire [DATA_W-1:0] PRDATA,
    input  wire              PREADY,
    input  wire              PSLVERR
);

    localparam [1:0] IDLE = 2'd0, SETUP = 2'd1, ACCESS = 2'd2;
    reg [1:0] state;

    assign PSEL    = (state != IDLE);
    assign PENABLE = (state == ACCESS);
    assign busy    = (state != IDLE);

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            state  <= IDLE;
            PADDR  <= {ADDR_W{1'b0}};
            PWRITE <= 1'b0;
            PWDATA <= {DATA_W{1'b0}};
            done   <= 1'b0;
            rdata  <= {DATA_W{1'b0}};
            err    <= 1'b0;
        end else begin
            done <= 1'b0;                       // default: pulse only
            case (state)
                IDLE: begin
                    if (start) begin
                        PADDR  <= addr;
                        PWRITE <= wr;
                        PWDATA <= wdata;
                        state  <= SETUP;
                    end
                end
                SETUP: begin
                    state <= ACCESS;            // PSEL=1, PENABLE=0 during this state
                end
                ACCESS: begin
                    if (PREADY) begin           // transfer completes
                        rdata <= PWRITE ? {DATA_W{1'b0}} : PRDATA;
                        err   <= PSLVERR;
                        done  <= 1'b1;
                        state <= IDLE;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end

endmodule
