
// riscv_cpu.v - 5-stage pipelined RISC-V CPU Processor

module riscv_cpu (
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

datapath dp (.clk(clk), .reset(reset),
             .PC(PC), .Instr(Instr),
             .MemWrite(MemWrite), .Mem_WrAddr(Mem_WrAddr), .Mem_WrData(Mem_WrData),
             .ReadData(ReadData), .Result(Result), .funct3(funct3),
             .PCW(PCW), .ALUResultW(ALUResultW), .WriteDataW(WriteDataW));

endmodule
