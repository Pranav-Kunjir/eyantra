
// data_mem.v - data memory (inferred block RAM)
//              - synchronous (registered) read: the raw word is registered,
//                so rd_data_mem is valid one clock after wr_addr is
//                presented, i.e. during writeback.
//              - byte-enable writes for sb / sh / sw.
//              - load formatting (lb/lh sign-extend, lbu/lhu) is applied to
//                the registered word with the matching registered funct3 and
//                low address bits.
//              - word address is a plain address slice (no modulo logic).

module data_mem #(parameter DATA_WIDTH = 32, ADDR_WIDTH = 32, MEM_SIZE = 64) (
    input       clk, wr_en,
    input [2:0] funct3,
    input       [ADDR_WIDTH-1:0] wr_addr, wr_data,
    output reg  [DATA_WIDTH-1:0] rd_data_mem
);

localparam WORD_ADDR_W = $clog2(MEM_SIZE);

// array of 64 32-bit data, mapped to dedicated block RAM (M9K)
(* ramstyle = "M9K" *) reg [DATA_WIDTH-1:0] data_ram [0:MEM_SIZE-1];

// word-aligned memory access (plain address slice, no modulo)
wire [WORD_ADDR_W-1:0] word_addr = wr_addr[WORD_ADDR_W+1:2];

// byte-enable decode: sb/sh write only part of the addressed word
reg [DATA_WIDTH/8-1:0] byte_en;
always @(*) begin
    case (funct3)
        3'b000:  byte_en = 4'b0001 << wr_addr[1:0];          // sb
        3'b001:  byte_en = wr_addr[1] ? 4'b1100 : 4'b0011;   // sh
        default: byte_en = 4'b1111;                          // sw
    endcase
end

// store data is always right-justified in the source register, so replicate
// it into every lane; byte_en selects the lane(s) actually written
reg [DATA_WIDTH-1:0] wr_data_lanes;
always @(*) begin
    case (funct3)
        3'b000:  wr_data_lanes = {4{wr_data[7:0]}};          // sb
        3'b001:  wr_data_lanes = {2{wr_data[15:0]}};         // sh
        default: wr_data_lanes = wr_data;                    // sw
    endcase
end

// synchronous write; registered read of the addressed word.
// funct3 / address low bits are registered with the word so that the
// load formatting below uses the control of the same instruction.
reg [DATA_WIDTH-1:0] rd_word;
reg [2:0]            rd_funct3;
reg [1:0]            rd_addr_lo;

integer i;
always @(posedge clk) begin
    if (wr_en) begin
        for (i = 0; i < DATA_WIDTH/8; i = i + 1) begin
            if (byte_en[i])
                data_ram[word_addr][8*i +: 8] <= wr_data_lanes[8*i +: 8];
        end
    end
    rd_word    <= data_ram[word_addr];
    rd_funct3  <= funct3;
    rd_addr_lo <= wr_addr[1:0];
end

// load formatting (combinational, on the registered word)
always @(*) begin
    case (rd_funct3)
        3'b000: begin // lb
            case (rd_addr_lo)
                2'b00: rd_data_mem = {{24{rd_word[ 7]}}, rd_word[ 7: 0]};
                2'b01: rd_data_mem = {{24{rd_word[15]}}, rd_word[15: 8]};
                2'b10: rd_data_mem = {{24{rd_word[23]}}, rd_word[23:16]};
                2'b11: rd_data_mem = {{24{rd_word[31]}}, rd_word[31:24]};
            endcase
        end
        3'b001: begin // lh
            rd_data_mem = rd_addr_lo[1] ? {{16{rd_word[31]}}, rd_word[31:16]}
                                        : {{16{rd_word[15]}}, rd_word[15: 0]};
        end
        3'b010: rd_data_mem = rd_word; // lw
        3'b100: begin // lbu
            case (rd_addr_lo)
                2'b00: rd_data_mem = {24'b0, rd_word[ 7: 0]};
                2'b01: rd_data_mem = {24'b0, rd_word[15: 8]};
                2'b10: rd_data_mem = {24'b0, rd_word[23:16]};
                2'b11: rd_data_mem = {24'b0, rd_word[31:24]};
            endcase
        end
        3'b101: begin // lhu
            rd_data_mem = rd_addr_lo[1] ? {16'b0, rd_word[31:16]}
                                        : {16'b0, rd_word[15: 0]};
        end
        default: rd_data_mem = 32'b0;
    endcase
end

endmodule
