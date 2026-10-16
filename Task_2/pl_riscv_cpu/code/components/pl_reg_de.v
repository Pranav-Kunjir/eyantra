
// pipeline registers -> decode | execute stage

module pl_reg_de (
    input             clk, en, clr,
    input      [31:0] RD1D, RD2D, ImmExtD, PCD, PCPlus4D, AuiPCD,
    input      [ 4:0] Rs1D, Rs2D, RdD,
    input      [ 2:0] Funct3D,
    input             RegWriteD, MemWriteD, JumpD, BranchD, JalrD, ALUSrcD,
    input      [ 1:0] ResultSrcD,
    input      [ 3:0] ALUControlD,
    output reg [31:0] RD1E, RD2E, ImmExtE, PCE, PCPlus4E, AuiPCE,
    output reg [ 4:0] Rs1E, Rs2E, RdE,
    output reg [ 2:0] Funct3E,
    output reg        RegWriteE, MemWriteE, JumpE, BranchE, JalrE, ALUSrcE,
    output reg [ 1:0] ResultSrcE,
    output reg [ 3:0] ALUControlE
);

initial begin
    RD1E = 0; RD2E = 0; ImmExtE = 0; PCE = 0; PCPlus4E = 0; AuiPCE = 0;
    Rs1E = 0; Rs2E = 0; RdE = 0; Funct3E = 0;
    RegWriteE = 0; MemWriteE = 0; JumpE = 0; BranchE = 0; JalrE = 0; ALUSrcE = 0;
    ResultSrcE = 0; ALUControlE = 0;
end

always @(posedge clk) begin
    if (clr) begin
        RD1E <= 0; RD2E <= 0; ImmExtE <= 0; PCE <= 0; PCPlus4E <= 0; AuiPCE <= 0;
        Rs1E <= 0; Rs2E <= 0; RdE <= 0; Funct3E <= 0;
        RegWriteE <= 0; MemWriteE <= 0; JumpE <= 0; BranchE <= 0; JalrE <= 0; ALUSrcE <= 0;
        ResultSrcE <= 0; ALUControlE <= 0;
    end else if (!en) begin
        RD1E <= RD1D; RD2E <= RD2D; ImmExtE <= ImmExtD;
        PCE <= PCD; PCPlus4E <= PCPlus4D; AuiPCE <= AuiPCD;
        Rs1E <= Rs1D; Rs2E <= Rs2D; RdE <= RdD; Funct3E <= Funct3D;
        RegWriteE <= RegWriteD; MemWriteE <= MemWriteD; JumpE <= JumpD;
        BranchE <= BranchD; JalrE <= JalrD; ALUSrcE <= ALUSrcD;
        ResultSrcE <= ResultSrcD; ALUControlE <= ALUControlD;
    end
end

endmodule
