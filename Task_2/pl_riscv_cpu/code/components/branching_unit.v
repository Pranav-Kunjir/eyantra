
// branching_unit.v - logic for branching in execute stage
// Compares the two (forwarded) source operands according to funct3.

module branching_unit (
    input [2:0]  funct3,
    input [31:0] SrcA, SrcB,
    output reg   TakeBranch
);

// signed less-than: if signs differ the negative operand is smaller,
// otherwise a plain (unsigned) compare gives the same ordering
wire signed_lt = (SrcA[31] != SrcB[31]) ? SrcA[31] : (SrcA < SrcB);

initial begin
    TakeBranch = 1'b0;
end

always @(*) begin
    case (funct3)
        3'b000: TakeBranch = (SrcA == SrcB);   // beq
        3'b001: TakeBranch = (SrcA != SrcB);   // bne
        3'b100: TakeBranch =  signed_lt;       // blt
        3'b101: TakeBranch = !signed_lt;       // bge
        3'b110: TakeBranch = (SrcA <  SrcB);   // bltu
        3'b111: TakeBranch = (SrcA >= SrcB);   // bgeu
        default: TakeBranch = 1'b0;
    endcase
end

endmodule
