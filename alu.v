
module alu (
    input  signed [31:0] op1,
    input  signed [31:0] op2,
    input        [3:0]   alu_op,
    output reg           zero,
    output reg  [31:0]   result,
    output reg           ovf
);

    parameter [3:0] ALUOP_AND  = 4'b1000;
    parameter [3:0] ALUOP_OR   = 4'b1001;
    parameter [3:0] ALUOP_NOR  = 4'b1010;
    parameter [3:0] ALUOP_NAND = 4'b1011;
    parameter [3:0] ALUOP_XOR  = 4'b1100;
    parameter [3:0] ALUOP_ADD  = 4'b0100;
    parameter [3:0] ALUOP_SUB  = 4'b0101;
    parameter [3:0] ALUOP_MUL  = 4'b0110;
    parameter [3:0] ALUOP_LSR  = 4'b0000;
    parameter [3:0] ALUOP_LSL  = 4'b0001;
    parameter [3:0] ALUOP_ASR  = 4'b0010;
    parameter [3:0] ALUOP_ASL  = 4'b0011;

    reg signed [63:0] mul_ext;

  always @(*) begin
        result = 32'd0;
        ovf    = 1'b0;

        case (alu_op)
            ALUOP_AND:  result = op1 & op2;
            ALUOP_OR:   result = op1 | op2;
            ALUOP_NOR:  result = ~(op1 | op2);
            ALUOP_NAND: result = ~(op1 & op2);
            ALUOP_XOR:  result = op1 ^ op2;

            ALUOP_ADD: begin
                result = op1 + op2;
                // overflow για προσημασμένη πρόσθεση
                ovf = (op1[31] == op2[31]) && (result[31] != op1[31]);
            end

            ALUOP_SUB: begin
                result = op1 - op2;
                // overflow για προσημασμένη αφαίρεση
                ovf = (op1[31] != op2[31]) && (result[31] != op1[31]);
            end

            ALUOP_MUL: begin
                // προσημασμένος πολλαπλασιασμός σε 64 bit
                mul_ext = op1 * op2;
                result  = mul_ext[31:0];
                // overflow αν τα upper bits δεν είναι όλα ίσα με το sign bit
                ovf     = (mul_ext[63:32] != {32{mul_ext[31]}});
            end

            // λογική ολίσθηση
            ALUOP_LSR: result = $unsigned(op1) >> op2[4:0];
            ALUOP_LSL: result = op1 << op2[4:0];

            // αριθμητική ολίσθηση
            ALUOP_ASR: result = op1 >>> op2[4:0];
            ALUOP_ASL: result = op1 <<< op2[4:0];

        endcase

        zero = (result == 32'd0);
    end

endmodule
