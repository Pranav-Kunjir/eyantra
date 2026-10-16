
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
    output [31:0] PCW, ALUResultW, WriteDataW,
    output        StallF
);

    // ---- hazard / flush -------------------------------------------------
    wire StallD, FlushD, FlushE, FlushD_hu, FlushE_hu;

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
    wire [31:0] ResultW, PCPlus4W, lAuiPCW;
    wire [ 4:0] RdW;
    wire        RegWriteW;
    wire [ 1:0] ResultSrcW;

    // ====================================================================
    // Fetch
    // ====================================================================
    assign PCNext = PCSrcE ? PCTargetE : PCPlus4F;

    reset_ff #(32) pcreg (clk, reset, StallF, PCNext, PC);
    adder          pcadd4 (PC, 32'd4, PCPlus4F);

    // The instruction memory is a block-RAM ROM with a registered read, so the
    // instruction presented during a cycle belongs to the PC of the previous
    // cycle. Register PC and PC+4 alongside it and let IF/ID capture that
    // matching pair (this makes the fetch path one cycle deeper).
    reg [31:0] PCF_d, PCPlus4F_d;
    initial begin
        PCF_d = 0; PCPlus4F_d = 0;
    end
    always @(posedge clk) begin
        if (!StallF) begin
            PCF_d      <= PC;
            PCPlus4F_d <= PCPlus4F;
        end
    end

    // Pipeline Register 1 -> Fetch | Decode
    pl_reg_fd plfd (.clk(clk), .en(StallD), .clr(FlushD),
                    .InstrF(InstrF), .PCF(PCF_d), .PCPlus4F(PCPlus4F_d),
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
    pl_reg_de plde (.clk(clk), .en(StallD), .clr(FlushE),
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
    // Value forwarded from the memory stage. Load data is not available in
    // this stage (the data memory has a registered read), and the load-use
    // interlock guarantees a load in M is never forwarded to E, so the
    // load case is a don't-care here.
    assign ResultM = (ResultSrcM == 2'b10) ? PCPlus4M :
                     (ResultSrcM == 2'b11) ? lAuiPCM : ALUResultM;

    assign Mem_WrAddr = ALUResultM;
    assign Mem_WrData = WriteDataM;
    assign MemWrite   = MemWriteM;
    assign funct3     = Funct3M;

    // Pipeline Register 4 -> Memory | Writeback
    pl_reg_mw plmw (.clk(clk),
                    .ALUResultM(ALUResultM), .WriteDataM(WriteDataM),
                    .PCM(PCM), .PCPlus4M(PCPlus4M), .AuiPCM(lAuiPCM),
                    .RdM(RdM), .RegWriteM(RegWriteM), .ResultSrcM(ResultSrcM),
                    .ALUResultW(ALUResultW), .WriteDataW(WriteDataW),
                    .PCW(PCW), .PCPlus4W(PCPlus4W), .AuiPCW(lAuiPCW),
                    .RdW(RdW), .RegWriteW(RegWriteW), .ResultSrcW(ResultSrcW));

    // Writeback result mux: ALU result, load data (registered memory output,
    // live during writeback), PC+4 (JAL/JALR) or LUI/AUIPC (resolved in decode)
    mux4 #(32) resultmux (.d0(ALUResultW), .d1(ReadData), .d2(PCPlus4W), .d3(lAuiPCW),
                          .sel(ResultSrcW), .y(ResultW));

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

    // Extra decode flushes for the block-RAM instruction memory latency:
    // - one cycle when a branch/jump redirects the PC (the wrong-path fetch
    //   issued before the redirect must not reach decode),
    // - one cycle after reset (the ROM re-presents the instruction that was
    //   held during reset).
    reg PCSrcE_d, rst_d;
    initial begin
        PCSrcE_d = 0; rst_d = 0;
    end
    always @(posedge clk) begin
        PCSrcE_d <= PCSrcE;
        rst_d    <= reset;
    end

    assign FlushD = FlushD_hu | PCSrcE_d | (rst_d & ~reset) | reset;
    assign FlushE = FlushE_hu | reset;

endmodule
