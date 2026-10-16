
// pipeline registers -> memory | writeback stage

module pl_reg_mw (
    input             clk,
    input      [31:0] ResultM, ALUResultM, WriteDataM, PCM,
    input      [ 4:0] RdM,
    input             RegWriteM,
    output reg [31:0] ResultW, ALUResultW, WriteDataW, PCW,
    output reg [ 4:0] RdW,
    output reg        RegWriteW
);

initial begin
    ResultW = 0; ALUResultW = 0; WriteDataW = 0; PCW = 0;
    RdW = 0; RegWriteW = 0;
end

always @(posedge clk) begin
    ResultW <= ResultM; ALUResultW <= ALUResultM; WriteDataW <= WriteDataM;
    PCW <= PCM; RdW <= RdM; RegWriteW <= RegWriteM;
end

endmodule
