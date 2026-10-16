
// alu.v - ALU module

module alu #(parameter WIDTH = 32) (
    input       [WIDTH-1:0] a, b,       // operands
    input       [3:0] alu_ctrl,         // ALU control
    output reg  [WIDTH-1:0] alu_out,    // ALU output
    output      zero                    // zero flag
);

// signed less-than computed from the sign bits
wire slt = (a[WIDTH-1] != b[WIDTH-1]) ? a[WIDTH-1] : (a < b);

// arithmetic (sign-propagating) right shift, built from a logical shift
wire [WIDTH-1:0] sra = (a >> b[4:0]) |
                       (a[WIDTH-1] ? ~({WIDTH{1'b1}} >> b[4:0]) : {WIDTH{1'b0}});

always @(*) begin
    case (alu_ctrl)
        4'b0000: alu_out = a + b;                       // ADD
        4'b0001: alu_out = a - b;                       // SUB
        4'b0010: alu_out = a & b;                       // AND
        4'b0011: alu_out = a | b;                       // OR
        4'b0100: alu_out = a ^ b;                       // XOR
        4'b0101: alu_out = slt ? {{(WIDTH-1){1'b0}}, 1'b1} : {WIDTH{1'b0}}; // SLT
        4'b0110: alu_out = (a < b) ? {{(WIDTH-1){1'b0}}, 1'b1} : {WIDTH{1'b0}}; // SLTU
        4'b0111: alu_out = a << b[4:0];                 // SLL
        4'b1000: alu_out = a >> b[4:0];                 // SRL
        4'b1001: alu_out = sra;                         // SRA
        default: alu_out = {WIDTH{1'b0}};
    endcase
end

assign zero = (alu_out == 0) ? 1'b1 : 1'b0;

endmodule
