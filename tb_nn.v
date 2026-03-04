`timescale 1ns/1ps

// Function nn_model
function [31:0] nn_model (input [31:0] input_1, input [31:0] input_2);

    // Internal variables
    reg [7:0] ROM [0:511];
    reg [31:0] inter1, inter2;
    reg [63:0] mul1, mul2, mac1, mac2, mul3, mul4, mac3, mac4;
    
    reg ovf_mul1, ovf_mul2, ovf_mul3, ovf_mul4, ovf_mac1, ovf_mac2, ovf_mac3, ovf_mac4, ovf_sb;

    reg [31:0] weight1, weight2, weight3, weight4, bias1, bias2, bias3;
    reg [31:0] shift_bias1, shift_bias2, shift_bias3;
    reg [63:0] result;
    integer addr;

    begin
        addr = 8;
        // -----    Load the rom.data file  -----
        $readmemb("rom_bytes.data", ROM);

        // -----    Pre-processing layer    -----
        shift_bias1 = {ROM[addr], ROM[addr + 1], ROM[addr + 2], ROM[addr + 3]};
        addr = addr + 4;
        shift_bias2 = {ROM[addr], ROM[addr + 1], ROM[addr + 2], ROM[addr + 3]};
        addr = addr + 4;

        inter1 = $signed(input_1) >>> shift_bias1; 
        inter2 = $signed(input_2) >>> shift_bias2;

        // -----    Neural Network Input Layer    -----
        weight1 = {ROM[addr], ROM[addr + 1], ROM[addr + 2], ROM[addr + 3]};
        addr = addr + 4;
        bias1   = {ROM[addr], ROM[addr + 1], ROM[addr + 2], ROM[addr + 3]};
        addr = addr + 4;

        weight2 = {ROM[addr], ROM[addr + 1], ROM[addr + 2], ROM[addr + 3]};
        addr = addr + 4;
        bias2   = {ROM[addr], ROM[addr + 1], ROM[addr + 2], ROM[addr + 3]};
        addr = addr + 4;

        mul1 = $signed({{32{inter1[31]}}, inter1}) * $signed({{32{weight1[31]}}, weight1});
        ovf_mul1 = (mul1[63:32] != {32{mul1[31]}})? 1'b1 : 1'b0;
         
        mac1 = $signed({{32{mul1[31]}}, mul1[31:0]}) + $signed({{32{bias1[31]}}, bias1});
        ovf_mac1 = (mac1[63:32] != {32{mac1[31]}})? 1'b1 : 1'b0;

        mul2 = $signed({{32{inter2[31]}}, inter2}) * $signed({{32{weight2[31]}}, weight2});
        ovf_mul2 = (mul2[63:32] != {32{mul2[31]}})? 1'b1 : 1'b0;

        mac2 = $signed({{32{mul2[31]}}, mul2[31:0]}) + $signed({{32{bias2[31]}}, bias2});
        ovf_mac2 = (mac2[63:32] != {32{mac2[31]}})? 1'b1 : 1'b0;

        // -----    Neural Network Output Layer    -----
        weight3 = {ROM[addr], ROM[addr + 1], ROM[addr + 2], ROM[addr + 3]};
        addr = addr + 4;
        weight4 = {ROM[addr], ROM[addr + 1], ROM[addr + 2], ROM[addr + 3]};
        addr = addr + 4;
        bias3   = {ROM[addr], ROM[addr + 1], ROM[addr + 2], ROM[addr + 3]};
        addr = addr + 4;

        mul3 = $signed({{32{mac1[31]}}, mac1[31:0]}) * $signed({{32{weight3[31]}}, weight3});
        ovf_mul3 = (mul3[63:32] != {32{mul3[31]}})? 1'b1 : 1'b0;

        mul4 = $signed({{32{mac2[31]}}, mac2[31:0]}) * $signed({{32{weight4[31]}}, weight4});
        ovf_mul4 = (mul4[63:32] != {32{mul4[31]}})? 1'b1 : 1'b0;

        mac3 = $signed({{32{mul3[31]}}, mul3[31:0]}) + $signed({{32{bias3[31]}}, bias3});
        ovf_mac3 = (mac3[63:32] != {32{mac3[31]}})? 1'b1 : 1'b0;

        mac4 = $signed({{32{mul4[31]}}, mul4[31:0]}) + $signed({{32{mac3[31]}}, mac3[31:0]});
        ovf_mac4 = (mac4[63:32] != {32{mac4[31]}})? 1'b1 : 1'b0;

        // -----    Post-processing layer   -----
        shift_bias3 = {ROM[addr], ROM[addr + 1], ROM[addr + 2], ROM[addr + 3]};
        addr = addr + 4;
        result = $signed(mac4[31:0]) <<< shift_bias3;

        ovf_sb = (result[63:32] != {32{result[31]}})? 1'b1 : 1'b0;

        if (ovf_mul1 | ovf_mul2 | ovf_mul3 | ovf_mul4 |
            ovf_mac1 | ovf_mac2 | ovf_mac3 | ovf_mac4 | ovf_sb) begin
            nn_model = 32'hFFFFFFFF;
        end else begin
            nn_model = result[31:0];
        end
    end
endfunction

// Testbench 
module tb_nn;
	// Σήματα προς DUT    
    logic                resetn;   // active-low reset
    logic                enable;
    logic signed [31:0]  input_1;
    logic signed [31:0]  input_2;

    wire  signed [31:0]  final_output;
    wire                 total_ovf;
    wire                 total_zero;
    wire          [2:0]  ovf_fsm_stage;
    wire          [2:0]  zero_fsm_stage;

    // Σήματα από DUT
    nn DUT (
        .input_1       (input_1),
        .input_2       (input_2),
        .clk           (clk),
        .resetn        (resetn),
        .enable        (enable),
        .final_output  (final_output),
        .total_ovf     (total_ovf),
        .total_zero    (total_zero),
        .ovf_fsm_stage (ovf_fsm_stage),
        .zero_fsm_stage(zero_fsm_stage)
    );

    // περίοδος 10 ns
    initial clk = 1'b0;
    always #5 clk = ~clk;

        // Προσημασμένος τυχαίος ακέραιος στο [min, max]
    function int signed Surandom_range (int signed max, int signed min);
        int signed range;
        int unsigned r;
        begin
            range = max - min;          // έυρος τιμών
            r     = $urandom_range(range, 0); // [0, range]
            Surandom_range = min + int'(r);    //μετατόπιση στο [min, max]
        end
    endfunction

    // Counters αποτελεσμάτων
    int unsigned pass_count, fail_count, total_tests;

    // Όρια 32-bit signed
    localparam int signed MAX_POS = 32'sh7fffffff;   //  2^31 - 1
    localparam int signed MAX_NEG = -32'sh80000000;  // -2^31

    // Task για ένα test case
    task automatic run_single_case(
        input int        id,
        input int signed in1,
        input int signed in2
    );
        reg [31:0] ref_out;
    begin
        total_tests++;

        // είσοδοι
        input_1 = in1;
        input_2 = in2;

 // Ένα παλμό enable: Από IDLE/DEACTIVATED ξεκινά ακολουθία FSM       
      	enable = 1'b1;
        @(posedge clk);
        enable = 1'b0;

      // Χρόνος για pipeline/FSM να ολοκληρώσει
        repeat (10) @(posedge clk);

        // reference output
        ref_out = nn_model(input_1, input_2);

      // Σύγκριση DUT vs reference
      
    	if (final_output !== ref_out) begin
            fail_count++;
            $display("[FAIL] Test %0d : in1=%0d in2=%0d  REF=0x%08x  DUT=0x%08x  time=%0t",
                     id, in1, in2, ref_out, final_output, $time);
            $display("        total_ovf=%0d total_zero=%0d ovf_stage=%0d zero_stage=%0d state=%0d",
                     total_ovf, total_zero, ovf_fsm_stage, zero_fsm_stage, DUT.state);
            $display("");
        end else begin
            pass_count++;
            $display("[PASS] Test %0d : in1=%0d in2=%0d  OUT=0x%08x  time=%0t",
                     id, in1, in2, final_output, $time);
        end
    end
    endtask
    
    int i;
    int signed r1, r2;

    initial begin
        clk        = 1'b0;
        resetn      = 1'b0;
        enable      = 1'b0;
        input_1     = 32'sd0;
        input_2     = 32'sd0;
        pass_count  = 0;
        fail_count  = 0;
        total_tests = 0;

        // reset
        #20;
        resetn = 1'b1;


        enable = 1'b1;
        @(posedge clk);
        enable = 1'b0;

      // Περιμένουμε μέχρι το DUT να ολοκληρώσει το loading
        wait (DUT.weights_loaded == 1'b1);
        repeat (2) @(posedge clk);

	input_1 = 32'sd0;
        input_2 = 32'sd0;
        enable  = 1'b1;
        @(posedge clk);
        enable  = 1'b0;
  		// Αναμονή για pipeline/latency
        repeat (8) @(posedge clk);



        $display("=== START NN TESTBENCH ===");

        // 100 επαναλήψεις σε 3 κατηγορίες tests
        for (i = 0; i < 100; i++) begin
            // Τυχαία μικρά signed inputs: [-4096, 4095]
            r1 = Surandom_range( 4095, -4096);
            r2 = Surandom_range( 4095, -4096);
            run_single_case(i*3 + 0, r1, r2);

           // Μεγάλοι θετικοί: [MAX_POS/2, MAX_POS]
            r1 = Surandom_range(MAX_POS, MAX_POS/2);
            r2 = Surandom_range(MAX_POS, MAX_POS/2);
            run_single_case(i*3 + 1, r1, r2);

            //Μεγάλοι αρνητικοί: [MAX_NEG, MAX_NEG/2]
            r1 = Surandom_range(MAX_NEG/2, MAX_NEG);
            r2 = Surandom_range(MAX_NEG/2, MAX_NEG);
            run_single_case(i*3 + 2, r1, r2);
        end

        // Τελική αναφορά αποτελεσμάτων
        $display("\n=== TEST SUMMARY ===");
        $display("  Total tests : %0d", total_tests);
        $display("  Passed      : %0d", pass_count);
        $display("  Failed      : %0d", fail_count);
        $display("=====================");

        $finish;
    end

endmodule
