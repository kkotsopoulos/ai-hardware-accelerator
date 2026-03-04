module mac_unit (
    input  signed [31:0] op1,   
    input  signed [31:0] op2,   
    input  signed [31:0] op3,   
    output signed [31:0] total_result, 
    output               zero_mul,     
    output               zero_add,     
    output               ovf_mul,      
    output               ovf_add     
);

    // Κωδικοί alu_op 
    localparam [3:0] ALUOP_MUL = 4'b0110;
    localparam [3:0] ALUOP_ADD = 4'b0100;

    // Ενδιάμεσα σήματα από τις δύο ALU
    wire [31:0] mul_result;
    wire        mul_zero;
    wire        mul_ovf;

    wire [31:0] add_result;
    wire        add_zero;
    wire        add_ovf;

    // Προσημασμένος πολλαπλασιασμός op1 * op2
    alu alu_mul (
        .op1    (op1),
        .op2    (op2),
        .alu_op (ALUOP_MUL),
        .zero   (mul_zero),
        .result (mul_result),
        .ovf    (mul_ovf)
    );

    // Προσημασμένη πρόσθεση (mul_result + op3)
    alu alu_add (
        .op1    (mul_result),
        .op2    (op3),
        .alu_op (ALUOP_ADD),
        .zero   (add_zero),
        .result (add_result),
        .ovf    (add_ovf)
    );

    // Outputs
    assign total_result = add_result;
    assign zero_mul     = mul_zero;
    assign zero_add     = add_zero;
    assign ovf_mul      = mul_ovf;
    assign ovf_add      = add_ovf;

endmodule
