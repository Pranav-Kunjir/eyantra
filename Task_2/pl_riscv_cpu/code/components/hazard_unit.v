
// hazard_unit.v - forwarding, load-use stall and branch flush control
// Combinational: no clock, no state.

module hazard_unit (
    input      [4:0] Rs1D, Rs2D,
    input      [4:0] Rs1E, Rs2E, RdE,
    input      [4:0] RdM, RdW,
    input            RegWriteM, RegWriteW, LoadE, PCSrcE,
    output reg [1:0] ForwardAE, ForwardBE,
    output reg       StallF, StallD, FlushD, FlushE
);

reg lwstall;

always @(*) begin
    // ---- data forwarding (Execute) ----
    if (RegWriteM && (RdM != 5'd0) && (RdM == Rs1E))
        ForwardAE = 2'b01;                       // from Memory stage ALU/result
    else if (RegWriteW && (RdW != 5'd0) && (RdW == Rs1E))
        ForwardAE = 2'b10;                       // from Writeback stage
    else
        ForwardAE = 2'b00;                       // register file

    if (RegWriteM && (RdM != 5'd0) && (RdM == Rs2E))
        ForwardBE = 2'b01;
    else if (RegWriteW && (RdW != 5'd0) && (RdW == Rs2E))
        ForwardBE = 2'b10;
    else
        ForwardBE = 2'b00;

    // ---- load-use hazard (Decode consumes a load still in Execute) ----
    lwstall = LoadE && (RdE != 5'd0) && ((RdE == Rs1D) || (RdE == Rs2D));

    // ---- control hazard (branch resolved in Execute) ----
    StallF  = lwstall;
    StallD  = lwstall;
    FlushE  = lwstall | PCSrcE;
    FlushD  = PCSrcE;
end

endmodule
