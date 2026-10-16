
// instr_mem.v - instruction memory (inferred block RAM ROM)
//               The read is synchronous: instr is valid one clock after
//               instr_addr is presented (registered output). ce holds the
//               address register while the fetch stage is stalled, so the
//               presented instruction does not change during a stall.

module instr_mem #(parameter DATA_WIDTH = 32, ADDR_WIDTH = 32, MEM_SIZE = 512) (
    input                        clk, ce,
    input       [ADDR_WIDTH-1:0] instr_addr,
    output reg  [DATA_WIDTH-1:0] instr
);

localparam WORD_ADDR_W = $clog2(MEM_SIZE);

// array of 512 32-bit instructions, mapped to dedicated block RAM (M9K)
(* romstyle = "M9K" *) reg [DATA_WIDTH-1:0] instr_ram [0:MEM_SIZE-1];

initial begin
    $readmemh("rv32i_test.hex", instr_ram);
end

// word-aligned memory access (plain address slice)
always @(posedge clk) begin
    if (ce)
        instr <= instr_ram[instr_addr[WORD_ADDR_W+1:2]];
end

endmodule
