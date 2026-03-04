`timescale 1ns/1ps

module calc_tb;

    reg        clk;
    reg        btnc;
    reg        btnac;
    reg        btnl;
    reg        btnr;
    reg        btnd;
    reg [15:0] sw;

    wire [15:0] led;
  
    calc DUT (
        .clk  (clk),
        .btnc (btnc),
        .btnac(btnac),
        .btnl (btnl),
        .btnr (btnr),
        .btnd (btnd),
        .sw   (sw),
        .led  (led)
    );

    initial clk = 0;
    always #5 clk = ~clk;   // περίοδος 10ns

    initial begin
        $dumpfile("calc_tb.vcd");
        $dumpvars(0, calc_tb);
    end
  
    // Για ένα βήμα του πίνακα
    task do_step(
        input [2:0] buttons,        // {btnl, btnr, btnd}
        input [15:0] switches,      // sw
        input [15:0] prev_expected, // αναμενόμενη προηγούμενη τιμή
        input [15:0] expected,      // αναμενόμενο αποτέλεσμα
        input [127:0] name          // όνομα πράξης 
    );
    begin
        // Έλεγχος προηγούμενης τιμής
        if (led !== prev_expected) begin
            $display("[ERROR before %s] expected prev acc=0x%h, got 0x%h",
                     name, prev_expected, led);
        end else begin
            $display("[OK before %s] acc=0x%h", name, led);
        end

        {btnl, btnr, btnd} = buttons;
        sw   = switches;
        btnc = 1'b0;

        @(posedge clk);

        // Παλμός σε btnc
        btnc = 1'b1;
        @(posedge clk); 
        btnc = 1'b0;

        @(posedge clk);

        // Έλεγχος νέας τιμής 
        if (led !== expected)
            $display("[FAIL %s] expected=0x%h got=0x%h", name, expected, led);
        else
            $display("[PASS %s] acc=0x%h", name, led);

        $display("");
    end
    endtask

    initial begin
        btnc  = 0;
        btnac = 0;
        btnl  = 0;
        btnr  = 0;
        btnd  = 0;
        sw    = 16'h0000;


        @(posedge clk);

        // RESET με btnac
        $display("RESET");
        btnac = 1'b1;
        @(posedge clk);
        btnac = 1'b0;
        @(posedge clk);   

        if (led !== 16'h0000) begin
            $display("TIME %0t ns: [ERROR RESET] expected acc = 0x0000, got 0x%h",
                     $time, led);
        end else begin
            $display("TIME %0t ns: [PASS RESET] acc = 0x0000", $time);
        end
        $display("");

        // Πίνακας από εκφώνηση:

        // 0,1,0  0x0000 0x285a ADD  0x285a
        do_step(3'b010, 16'h285a, 16'h0000, 16'h285a, "ADD");

        // 1,1,1  0x285a 0x04c8 XOR  0x2c92
        do_step(3'b111, 16'h04c8, 16'h285a, 16'h2c92, "XOR");

        // 0,0,0  0x2c92 0x0005 LSR  0x0164
        do_step(3'b000, 16'h0005, 16'h2c92, 16'h0164, "LSR");

        // 1,0,1  0x0164 0xa085 NOR  0x5e1a
        do_step(3'b101, 16'hA085, 16'h0164, 16'h5e1a, "NOR");

        // 1,0,0  0x5e1a 0x07fe MULT 0x13cc
        do_step(3'b100, 16'h07fe, 16'h5e1a, 16'h13cc, "MULT");

        // 0,0,1  0x13cc 0x0004 LSL  0x3cc0
        do_step(3'b001, 16'h0004, 16'h13cc, 16'h3cc0, "LSL");

        // 1,1,0  0x3cc0 0xfa65 NAND 0xc7bf
        do_step(3'b110, 16'hFA65, 16'h3cc0, 16'hc7bf, "NAND");

        // 0,1,1  0xc7bf 0xb2e4 SUB  0x14db
        do_step(3'b011, 16'hB2E4, 16'hc7bf, 16'h14db, "SUB");

        $finish;
    end

endmodule
