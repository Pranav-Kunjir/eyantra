
// pipeline registers -> execute | memory stage

module pl_reg_em (
    input             clk,
    input      [31:0] ALUResultE, WriteDataE, PCE, PCPlus4E, AuiPCE,
    input      [ 4:0] RdE,
    input      [ 2:0] Funct3E,
    input             RegWriteE, MemWriteE,
    input      [ 1:0] ResultSrcE,
    output reg [31:0] ALUResultM, WriteDataM, PCM, PCPlus4M, AuiPCM,
    output reg [ 4:0] RdM,
    output reg [ 2:0] Funct3M,
    output reg        RegWriteM, MemWriteM,
    output reg [ 1:0] ResultSrcM
);

initial begin
    ALUResultM = 0; WriteDataM = 0; PCM = 0; PCPlus4M = 0; AuiPCM = 0;
    RdM = 0; Funct3M = 0; RegWriteM = 0; MemWriteM = 0; ResultSrcM = 0;
end

always @(posedge clk) begin
    ALUResultM <= ALUResultE; WriteDataM <= WriteDataE;
    PCM <= PCE; PCPlus4M <= PCPlus4E; AuiPCM <= AuiPCE;
    RdM <= RdE; Funct3M <= Funct3E;
    RegWriteM <= RegWriteE; MemWriteM <= MemWriteE; ResultSrcM <= ResultSrcE;
end

endmodule
