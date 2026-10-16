
// datapath.v - 5-stage pipelined RISC-V datapath
module datapath (
    input         clk, reset,
    output [31:0] PC,
    input  [31:0] Instr,
    output        MemWrite,
    output [31:0] Mem_WrAddr, Mem_WrData,
    input  [31:0] ReadData,
    output [31:0] Result,
    output [ 2:0] funct3,
    output [31:0] PCW, ALUResultW, WriteDataW
);

    // ---- hazard / flush -------------------------------------------------
    wire StallF, StallD, FlushD, FlushE, FlushD_hu, FlushE_hu;

    // ---- fetch ----------------------------------------------------------
    wire [31:0] InstrF = Instr;
    wire [31:0] PCPlus4F, PCTargetE, PCNext;
    wire        PCSrcE;

    // ---- fetch | decode -------------------------------------------------
    wire [31:0] InstrD, PCD, PCPlus4D;

    // ---- decode ---------------------------------------------------------
    wire [31:0] RD1D, RD2D, ImmExtD, UpperImmD, AuiPCD, lAuiPCD;
    wire [ 1:0] ResultSrcD, ImmSrcD;
    wire [ 3:0] ALUControlD;
    wire        MemWriteD, ALUSrcD, RegWriteD, BranchD, JumpD, JalrD;

    // ---- decode | execute ----------------------------------------------
    wire [31:0] RD1E, RD2E, ImmExtE, PCE, PCPlus4E, lAuiPCE;
    wire [ 4:0] Rs1E, Rs2E, RdE;
    wire [ 2:0] Funct3E;
    wire [ 3:0] ALUControlE;
    wire [ 1:0] ResultSrcE;
    wire        RegWriteE, MemWriteE, JumpE, BranchE, JalrE, ALUSrcE;

    // ---- execute --------------------------------------------------------
    wire [ 1:0] ForwardAE, ForwardBE;
    wire [31:0] SrcAE, RD2E_fwd, SrcBE, ALUResultE;
    wire        ZeroE, TakeBranchE, LoadE;

    // ---- execute | memory ----------------------------------------------
    wire [31:0] ALUResultM, WriteDataM, PCM, PCPlus4M, lAuiPCM;
    wire [ 4:0] RdM;
    wire [ 2:0] Funct3M;
    wire [ 1:0] ResultSrcM;
    wire        RegWriteM, MemWriteM;

    // ---- memory ---------------------------------------------------------
    wire [31:0] ResultM;

    // ---- memory | writeback --------------------------------------------
    wire [31:0] ResultW;
    wire [ 4:0] RdW;
    wire        RegWriteW;

    // ====================================================================
    // Fetch
    // ====================================================================
    assign PCNext = PCSrcE ? PCTargetE : PCPlus4F;

    reset_ff #(32) pcreg (clk, reset, StallF, PCNext, PC);
    adder          pcadd4 (PC, 32'd4, PCPlus4F);

    // Pipeline Register 1 -> Fetch | Decode
    pl_reg_fd plfd (.clk(clk), .en(StallD), .clr(FlushD),
                    .InstrF(InstrF), .PCF(PC), .PCPlus4F(PCPlus4F),
                    .InstrD(InstrD), .PCD(PCD), .PCPlus4D(PCPlus4D));

    // ====================================================================
    // Decode
    // ====================================================================
    controller  c   (.op(InstrD[6:0]), .funct3(InstrD[14:12]), .funct7b5(InstrD[30]),
                     .ResultSrc(ResultSrcD), .MemWrite(MemWriteD), .ALUSrc(ALUSrcD),
                     .RegWrite(RegWriteD), .Branch(BranchD), .Jump(JumpD), .Jalr(JalrD),
                     .ImmSrc(ImmSrcD), .ALUControl(ALUControlD));

    imm_extend  ext (.instr(InstrD[31:7]), .immsrc(ImmSrcD), .immext(ImmExtD));

    reg_file    rf  (.clk(clk), .wr_en(RegWriteW),
                     .rd_addr1(InstrD[19:15]), .rd_addr2(InstrD[24:20]),
                     .wr_addr(RdW), .wr_data(ResultW),
                     .rd_data1(RD1D), .rd_data2(RD2D));

    // lui / auipc result (resolved in decode, carried to writeback)
    assign UpperImmD = {InstrD[31:12], 12'b0};
    assign AuiPCD   = PCD + UpperImmD;
    assign lAuiPCD  = InstrD[5] ? UpperImmD : AuiPCD;

    // Pipeline Register 2 -> Decode | Execute
    pl_reg_de plde (.clk(clk), .en(1'b0), .clr(FlushE),
                    .RD1D(RD1D), .RD2D(RD2D), .ImmExtD(ImmExtD),
                    .PCD(PCD), .PCPlus4D(PCPlus4D), .AuiPCD(lAuiPCD),
                    .Rs1D(InstrD[19:15]), .Rs2D(InstrD[24:20]), .RdD(InstrD[11:7]),
                    .Funct3D(InstrD[14:12]),
                    .RegWriteD(RegWriteD), .MemWriteD(MemWriteD), .JumpD(JumpD),
                    .BranchD(BranchD), .JalrD(JalrD), .ALUSrcD(ALUSrcD),
                    .ResultSrcD(ResultSrcD), .ALUControlD(ALUControlD),
                    .RD1E(RD1E), .RD2E(RD2E), .ImmExtE(ImmExtE),
                    .PCE(PCE), .PCPlus4E(PCPlus4E), .AuiPCE(lAuiPCE),
                    .Rs1E(Rs1E), .Rs2E(Rs2E), .RdE(RdE), .Funct3E(Funct3E),
                    .RegWriteE(RegWriteE), .MemWriteE(MemWriteE), .JumpE(JumpE),
                    .BranchE(BranchE), .JalrE(JalrE), .ALUSrcE(ALUSrcE),
                    .ResultSrcE(ResultSrcE), .ALUControlE(ALUControlE));

    // ====================================================================
    // Execute
    // ====================================================================
    assign SrcAE    = (ForwardAE == 2'b01) ? ResultM :
                      (ForwardAE == 2'b10) ? ResultW : RD1E;
    assign RD2E_fwd = (ForwardBE == 2'b01) ? ResultM :
                      (ForwardBE == 2'b10) ? ResultW : RD2E;
    assign SrcBE    = ALUSrcE ? ImmExtE : RD2E_fwd;
    assign LoadE    = (ResultSrcE == 2'b01);

    alu            alu (.a(SrcAE), .b(SrcBE), .alu_ctrl(ALUControlE),
                        .alu_out(ALUResultE), .zero(ZeroE));
    branching_unit bu  (.funct3(Funct3E), .SrcA(SrcAE), .SrcB(SrcBE),
                        .TakeBranch(TakeBranchE));

    assign PCSrcE    = (BranchE & TakeBranchE) | JumpE | JalrE;
    assign PCTargetE = JalrE ? ALUResultE : (PCE + ImmExtE);

    // Pipeline Register 3 -> Execute | Memory
    pl_reg_em plem (.clk(clk),
                    .ALUResultE(ALUResultE), .WriteDataE(RD2E_fwd),
                    .PCE(PCE), .PCPlus4E(PCPlus4E), .AuiPCE(lAuiPCE),
                    .RdE(RdE), .Funct3E(Funct3E),
                    .RegWriteE(RegWriteE), .MemWriteE(MemWriteE), .ResultSrcE(ResultSrcE),
                    .ALUResultM(ALUResultM), .WriteDataM(WriteDataM),
                    .PCM(PCM), .PCPlus4M(PCPlus4M), .AuiPCM(lAuiPCM),
                    .RdM(RdM), .Funct3M(Funct3M),
                    .RegWriteM(RegWriteM), .MemWriteM(MemWriteM), .ResultSrcM(ResultSrcM));

    // ====================================================================
    // Memory
    // ====================================================================
    mux4 #(32) resultmux (.d0(ALUResultM), .d1(ReadData), .d2(PCPlus4M), .d3(lAuiPCM),
                          .sel(ResultSrcM), .y(ResultM));

    assign Mem_WrAddr = ALUResultM;
    assign Mem_WrData = WriteDataM;
    assign MemWrite   = MemWriteM;
    assign funct3     = Funct3M;

    // Pipeline Register 4 -> Memory | Writeback
    pl_reg_mw plmw (.clk(clk),
                    .ResultM(ResultM), .ALUResultM(ALUResultM), .WriteDataM(WriteDataM),
                    .PCM(PCM), .RdM(RdM), .RegWriteM(RegWriteM),
                    .ResultW(ResultW), .ALUResultW(ALUResultW), .WriteDataW(WriteDataW),
                    .PCW(PCW), .RdW(RdW), .RegWriteW(RegWriteW));

    assign Result = ResultW;

    // ====================================================================
    // Hazard unit
    // ====================================================================
    hazard_unit hu (.Rs1D(InstrD[19:15]), .Rs2D(InstrD[24:20]),
                    .Rs1E(Rs1E), .Rs2E(Rs2E), .RdE(RdE),
                    .RdM(RdM), .RdW(RdW),
                    .RegWriteM(RegWriteM), .RegWriteW(RegWriteW),
                    .LoadE(LoadE), .PCSrcE(PCSrcE),
                    .ForwardAE(ForwardAE), .ForwardBE(ForwardBE),
                    .StallF(StallF), .StallD(StallD),
                    .FlushD(FlushD_hu), .FlushE(FlushE_hu));

    assign FlushD = FlushD_hu | reset;
    assign FlushE = FlushE_hu | reset;

endmodule
