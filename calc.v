
module calc (
    input        clk,    
    input        btnc,   
    input        btnac, 
    input        btnl,   
    input        btnr,   
    input        btnd,   
    input  [15:0] sw,    
    output [15:0] led    
);


    reg [15:0] accumulator;

    wire signed [31:0] acc_ext;
    wire signed [31:0] sw_ext;

  	assign acc_ext = {{16{accumulator[15]}}, accumulator};
    assign sw_ext  = {{16{sw[15]}},          sw};

    
    wire [31:0] alu_result;
    wire        alu_zero;
    wire        alu_ovf;
    wire [3:0]  alu_op;


    calc_enc u_enc (
        .btnl   (btnl),
        .btnr   (btnr),
        .btnd   (btnd),
        .alu_op (alu_op)
    );

   
    alu u_alu (
        .op1    (acc_ext),   
        .op2    (sw_ext),   
        .alu_op (alu_op),     
        .zero   (alu_zero),
        .result (alu_result),
        .ovf    (alu_ovf)
    );

   
   
    reg btnc_prev;

    always @(posedge clk) begin
        // αποθήκευση προηγούμενης τιμής του btnc
        btnc_prev <= btnc;

        if (btnac) begin
            accumulator <= 16'd0;
        end 
        else if (btnc && !btnc_prev) begin
            accumulator <= alu_result[15:0];
        end
    end

    assign led = accumulator;

endmodule