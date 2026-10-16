
// pipeline registers -> memory | writeback stage

module pl_reg_mw (
    input             clk,
    input      [31:0] ALUResultM, WriteDataM, PCM, PCPlus4M, AuiPCM,
    input      [ 4:0] RdM,
    input             RegWriteM,
    input      [ 1:0] ResultSrcM,
    output reg [31:0] ALUResultW, WriteDataW, PCW, PCPlus4W, AuiPCW,
    output reg [ 4:0] RdW,
    output reg        RegWriteW,
    output reg [ 1:0] ResultSrcW
);

initial begin
    ALUResultW = 0; WriteDataW = 0; PCW = 0; PCPlus4W = 0; AuiPCW = 0;
    RdW = 0; RegWriteW = 0; ResultSrcW = 0;
end

always @(posedge clk) begin
    ALUResultW <= ALUResultM; WriteDataW <= WriteDataM;
    PCW <= PCM; PCPlus4W <= PCPlus4M; AuiPCW <= AuiPCM;
    RdW <= RdM; RegWriteW <= RegWriteM; ResultSrcW <= ResultSrcM;
end

endmodule
