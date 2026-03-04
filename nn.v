module nn (
    input  signed [31:0] input_1,
    input  signed [31:0] input_2,
    input                clk,
    input                resetn,        // active-low reset
    input                enable,        

    output signed [31:0] final_output,   
    output               total_ovf,      // 1 αν είχαμε οπουδήποτε overflow 
    output               total_zero,     // 1 αν είχαμε οπουδήποτε 0
  output        [2:0]  ovf_fsm_stage,  // FSM state που εμφανίστηκε το πρώτο overflow
  output        [2:0]  zero_fsm_stage  // FSM state που εμφανίστηκε το πρώτο 0
);

  // FSM states
    localparam [2:0]
        ST_DEACTIVATED = 3'b000,
        ST_LOADING     = 3'b001,  // Loading weights & biases
        ST_PREPROC     = 3'b010,  // Data pre-processing layer
        ST_INPUT_L     = 3'b011,  // Input layer
        ST_OUTPUT_L    = 3'b100,  // Output layer
        ST_POSTPROC    = 3'b101,  // Data post-processing layer
        ST_IDLE        = 3'b110;  // Idle

    // Καμία καταγραφή ακόμα
    localparam [2:0] ST_NONE = 3'b111;

    // ALU πράξεις
    localparam [3:0]
        ALUOP_ASR = 4'b0010,  // arithmetic shift right
        ALUOP_ASL = 4'b0011;  // arithmetic shift left

    // Διευθύνσεις στο regfile για αποθήκευση παραμέτρων
    localparam [3:0]
        REG_SHIFT_B1 = 4'h2,
        REG_SHIFT_B2 = 4'h3,
        REG_WEIGHT1  = 4'h4,
        REG_BIAS1    = 4'h5,
        REG_WEIGHT2  = 4'h6,
        REG_BIAS2    = 4'h7,
        REG_WEIGHT3  = 4'h8,
        REG_WEIGHT4  = 4'h9,
        REG_BIAS3    = 4'hA,
        REG_SHIFT_B3 = 4'hB;

    // ROM base address
    localparam [7:0]  ROM_BASE_ADDR = 8'd8;
    localparam integer NUM_PARAMS   = 10;

    // Τιμή κορεσμού στο overflow
    localparam [31:0] SAT_OVF = 32'hFFFFFFFF;

    // Καταχωρητές FSM
    reg [2:0] state, next_state;

    // Καταχωρητές outputs & flags
    reg signed [31:0] final_output_reg;
    reg signed [31:0] final_output_next;
    reg               total_ovf_reg;
    reg               total_zero_reg;
    reg        [2:0]  ovf_fsm_stage_reg;
    reg        [2:0]  zero_fsm_stage_reg;

    // Δείχνει αν έχουν φορτωθεί 
    reg weights_loaded;

    //Registers για παραμέτρους
    reg signed [31:0] shift_bias_1_reg;
    reg signed [31:0] shift_bias_2_reg;
    reg signed [31:0] shift_bias_3_reg;
    reg signed [31:0] weight_1_reg;
    reg signed [31:0] weight_2_reg;
    reg signed [31:0] weight_3_reg;
    reg signed [31:0] weight_4_reg;
    reg signed [31:0] bias_1_reg;
    reg signed [31:0] bias_2_reg;
    reg signed [31:0] bias_3_reg;

    // Ενδιάμεσα Registers
  
    // έξοδοι PREPROC
    reg signed [31:0] inter_1, inter_2;
    reg signed [31:0] inter_1_next, inter_2_next;

    // έξοδοι INPUT_L
    reg signed [31:0] inter_3, inter_4;
    reg signed [31:0] inter_3_next, inter_4_next;

    // έξοδοι OUTPUT_L
    reg signed [31:0] inter_5;
    reg signed [31:0] inter_5_next;

    reg ovf_this_stage;
    reg zero_this_stage;

    // ROM & regfile
    reg  [7:0]  rom_addr1, rom_addr2;
    wire [31:0] rom_dout1, rom_dout2;

    WEIGHT_BIAS_MEMORY #(.DATAWIDTH(32)) u_rom (
        .clk   (clk),
        .addr1 (rom_addr1),
        .addr2 (rom_addr2),
        .dout1 (rom_dout1),
        .dout2 (rom_dout2)
    );

    reg  [3:0]  rf_readReg1, rf_readReg2, rf_readReg3, rf_readReg4;
    reg  [3:0]  rf_writeReg1, rf_writeReg2;
    reg  [31:0] rf_writeData1, rf_writeData2;
    reg         rf_write_en;
    wire [31:0] rf_readData1, rf_readData2, rf_readData3, rf_readData4;

    regfile #(.DATAWIDTH(32)) u_regfile (
        .clk        (clk),
        .resetn     (resetn),
        .readReg1   (rf_readReg1),
        .readReg2   (rf_readReg2),
        .readReg3   (rf_readReg3),
        .readReg4   (rf_readReg4),
        .writeReg1  (rf_writeReg1),
        .writeReg2  (rf_writeReg2),
        .writeData1 (rf_writeData1),
        .writeData2 (rf_writeData2),
        .write      (rf_write_en),
        .readData1  (rf_readData1),
        .readData2  (rf_readData2),
        .readData3  (rf_readData3),
        .readData4  (rf_readData4)
    );

    // ALUs για PRE/POSTPROC
    reg  signed [31:0] alu1_op1, alu1_op2;
    reg  signed [31:0] alu2_op1, alu2_op2;
    reg         [3:0]  alu1_op,  alu2_op;
    wire signed [31:0] alu1_result, alu2_result;
    wire               alu1_zero, alu2_zero;
    wire               alu1_ovf,  alu2_ovf;

    alu u_alu1 (
        .op1    (alu1_op1),
        .op2    (alu1_op2),
        .alu_op (alu1_op),
        .zero   (alu1_zero),
        .result (alu1_result),
        .ovf    (alu1_ovf)
    );

    alu u_alu2 (
        .op1    (alu2_op1),
        .op2    (alu2_op2),
        .alu_op (alu2_op),
        .zero   (alu2_zero),
        .result (alu2_result),
        .ovf    (alu2_ovf)
    );

    // MAC units για INPUT/OUTPUT
    reg  signed [31:0] mac1_op1, mac1_op2, mac1_op3;
    wire signed [31:0] mac1_result;
    wire               mac1_zero_mul, mac1_zero_add;
    wire               mac1_ovf_mul,  mac1_ovf_add;

    reg  signed [31:0] mac2_op1, mac2_op2, mac2_op3;
    wire signed [31:0] mac2_result;
    wire               mac2_zero_mul, mac2_zero_add;
    wire               mac2_ovf_mul,  mac2_ovf_add;

    mac_unit u_mac1 (
        .op1          (mac1_op1),
        .op2          (mac1_op2),
        .op3          (mac1_op3),
        .total_result (mac1_result),
        .zero_mul     (mac1_zero_mul),
        .zero_add     (mac1_zero_add),
        .ovf_mul      (mac1_ovf_mul),
        .ovf_add      (mac1_ovf_add)
    );

    mac_unit u_mac2 (
        .op1          (mac2_op1),
        .op2          (mac2_op2),
        .op3          (mac2_op3),
        .total_result (mac2_result),
        .zero_mul     (mac2_zero_mul),
        .zero_add     (mac2_zero_add),
        .ovf_mul      (mac2_ovf_mul),
        .ovf_add      (mac2_ovf_add)
    );

    //  Loader ROM σε regfile (ST_LOADING)
    reg        load_active;
    reg        load_phase;   // 0: wait, 1: write
    reg  [3:0] load_index;   // 0 ??? 9

    // ενημέρωση state, registers, και latch των flags
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state               <= ST_DEACTIVATED;
            final_output_reg    <= 32'sd0;
            final_output_next   <= 32'sd0;
            total_ovf_reg       <= 1'b0;
            total_zero_reg      <= 1'b0;
            ovf_fsm_stage_reg   <= ST_NONE;
            zero_fsm_stage_reg  <= ST_NONE;
            weights_loaded      <= 1'b0;

            rom_addr1           <= ROM_BASE_ADDR;
            rom_addr2           <= 8'd0;
            load_active         <= 1'b0;
            load_phase          <= 1'b0;
            load_index          <= 4'd0;

            rf_readReg1         <= 4'd0;
            rf_readReg2         <= 4'd0;
            rf_readReg3         <= 4'd0;
            rf_readReg4         <= 4'd0;
            rf_writeReg1        <= 4'd0;
            rf_writeReg2        <= 4'd0;
            rf_writeData1       <= 32'sd0;
            rf_writeData2       <= 32'sd0;
            rf_write_en         <= 1'b0;

            shift_bias_1_reg    <= 32'sd0;
            shift_bias_2_reg    <= 32'sd0;
            shift_bias_3_reg    <= 32'sd0;
            weight_1_reg        <= 32'sd0;
            weight_2_reg        <= 32'sd0;
            weight_3_reg        <= 32'sd0;
            weight_4_reg        <= 32'sd0;
            bias_1_reg          <= 32'sd0;
            bias_2_reg          <= 32'sd0;
            bias_3_reg          <= 32'sd0;

            inter_1             <= 32'sd0;
            inter_2             <= 32'sd0;
            inter_3             <= 32'sd0;
            inter_4             <= 32'sd0;
            inter_5             <= 32'sd0;
            inter_1_next        <= 32'sd0;
            inter_2_next        <= 32'sd0;
            inter_3_next        <= 32'sd0;
            inter_4_next        <= 32'sd0;
            inter_5_next        <= 32'sd0;

        end else begin
            // Ενημέρωση κατάστασης FSM
            state <= next_state;

            // default: δεν γράφουμε στο regfile (εκτός αν είμαστε στο ST_LOADING)
            rf_write_en <= 1'b0;

            // Καταχωρούμε τα next που υπολογίζονται
            inter_1          <= inter_1_next;
            inter_2          <= inter_2_next;
            inter_3          <= inter_3_next;
            inter_4          <= inter_4_next;
            inter_5          <= inter_5_next;
            final_output_reg <= final_output_next;

            // reset flags και stage
            if ((state == ST_DEACTIVATED && enable) ||
                (state == ST_IDLE        && enable)) begin
                total_ovf_reg      <= 1'b0;
                total_zero_reg     <= 1'b0;
                ovf_fsm_stage_reg  <= ST_NONE;
                zero_fsm_stage_reg <= ST_NONE;
            end
          
            // Aν εμφανιστεί σε οποιοδήποτε στάδιο, κρατάμε total_ovf=1
            // και αποθηκεύουμε το πρώτο state που το προκάλεσε
            if (ovf_this_stage) begin
                if (!total_ovf_reg) begin
                    total_ovf_reg     <= 1'b1;
                    ovf_fsm_stage_reg <= state;
                end else begin
                    total_ovf_reg     <= 1'b1;
                end
            end

            if (zero_this_stage) begin
                if (!total_zero_reg) begin
                    total_zero_reg     <= 1'b1;
                    zero_fsm_stage_reg <= state;
                end else begin
                    total_zero_reg     <= 1'b1;
                end
            end

            // Loader: ανάγνωση ROM και εγγραφή σε regfile
            case (state)
                ST_LOADING: begin
                    if (!load_active) begin
                        load_active    <= 1'b1;
                        load_phase     <= 1'b0;
                        load_index     <= 4'd0;
                        rom_addr1      <= ROM_BASE_ADDR;
                        rom_addr2      <= ROM_BASE_ADDR;
                        weights_loaded <= 1'b0;
                    end else begin
                        if (!load_phase) begin
                          // 1 κύκλος αναμονής
                            load_phase <= 1'b1;
                        end else begin
                     // Γράφουμε την τρέχουσα τιμή της ROM
                            rf_write_en <= 1'b1;

                            case (load_index)
                                4'd0: begin
                                    rf_writeReg1     <= REG_SHIFT_B1;
                                    rf_writeData1    <= rom_dout1;
                                    shift_bias_1_reg <= rom_dout1;
                                end
                                4'd1: begin
                                    rf_writeReg1     <= REG_SHIFT_B2;
                                    rf_writeData1    <= rom_dout1;
                                    shift_bias_2_reg <= rom_dout1;
                                end
                                4'd2: begin
                                    rf_writeReg1  <= REG_WEIGHT1;
                                    rf_writeData1 <= rom_dout1;
                                    weight_1_reg  <= rom_dout1;
                                end
                                4'd3: begin
                                    rf_writeReg1  <= REG_BIAS1;
                                    rf_writeData1 <= rom_dout1;
                                    bias_1_reg    <= rom_dout1;
                                end
                                4'd4: begin
                                    rf_writeReg1  <= REG_WEIGHT2;
                                    rf_writeData1 <= rom_dout1;
                                    weight_2_reg  <= rom_dout1;
                                end
                                4'd5: begin
                                    rf_writeReg1  <= REG_BIAS2;
                                    rf_writeData1 <= rom_dout1;
                                    bias_2_reg    <= rom_dout1;
                                end
                                4'd6: begin
                                    rf_writeReg1  <= REG_WEIGHT3;
                                    rf_writeData1 <= rom_dout1;
                                    weight_3_reg  <= rom_dout1;
                                end
                                4'd7: begin
                                    rf_writeReg1  <= REG_WEIGHT4;
                                    rf_writeData1 <= rom_dout1;
                                    weight_4_reg  <= rom_dout1;
                                end
                                4'd8: begin
                                    rf_writeReg1  <= REG_BIAS3;
                                    rf_writeData1 <= rom_dout1;
                                    bias_3_reg    <= rom_dout1;
                                end
                                4'd9: begin
                                    rf_writeReg1     <= REG_SHIFT_B3;
                                    rf_writeData1    <= rom_dout1;
                                    shift_bias_3_reg <= rom_dout1;
                                end
                                default: begin
                                    rf_writeReg1  <= 4'd0;
                                    rf_writeData1 <= 32'sd0;
                                end
                            endcase
							// επόμενο parameter
                            load_index <= load_index + 1'b1;
                            rom_addr1  <= rom_addr1 + 8'd4;
						// αν φτάσαμε στο τελευταίο, ολοκλήρωση φόρτωσης
                            if (load_index == (NUM_PARAMS-1)) begin
                                load_active    <= 1'b0;
                                load_phase     <= 1'b0;
                                weights_loaded <= 1'b1;
                            end else begin
                                load_phase <= 1'b0;
                            end
                        end
                    end
                end

                default: begin
                end
            endcase
        end
    end

     // next_state και υπολογισμοί datapath ανά state
    always @(*) begin
        // default: μένουμε στην ίδια κατάσταση
        next_state        = state;

        // default: κρατάμε προηγούμενες τιμές
        inter_1_next      = inter_1;
        inter_2_next      = inter_2;
        inter_3_next      = inter_3;
        inter_4_next      = inter_4;
        inter_5_next      = inter_5;
        final_output_next = final_output_reg;

        ovf_this_stage    = 1'b0;
        zero_this_stage   = 1'b0;

        // default ALUs
        alu1_op   = ALUOP_ASR;
        alu2_op   = ALUOP_ASR;
        alu1_op1  = 32'sd0;
        alu1_op2  = 32'sd0;
        alu2_op1  = 32'sd0;
        alu2_op2  = 32'sd0;

        // default regfile
        rf_readReg1 = 4'd0;
        rf_readReg2 = 4'd0;
        rf_readReg3 = 4'd0;
        rf_readReg4 = 4'd0;
        rf_writeReg2  = 4'd0;
        rf_writeData2 = 32'sd0;

        // default MAC
        mac1_op1 = 32'sd0;
        mac1_op2 = 32'sd0;
        mac1_op3 = 32'sd0;
        mac2_op1 = 32'sd0;
        mac2_op2 = 32'sd0;
        mac2_op3 = 32'sd0;

        case (state)
          // Με enable: αν δεν έχουμε φορτώσει weights -> LOADING, αλλιώς PREPROC.
            ST_DEACTIVATED: begin
                if (enable) begin
                    if (!weights_loaded)
                        next_state = ST_LOADING;
                    else
                        next_state = ST_PREPROC;
                end
            end
	// Μένουμε σε LOADING μέχρι να γίνει weights_loaded=1 από τον loader.
            ST_LOADING: begin
                if (weights_loaded)
                    next_state = ST_PREPROC;
                else
                    next_state = ST_LOADING;
            end

            ST_PREPROC: begin
                // inter_1 = input_1 >>> shift_bias_1
                // inter_2 = input_2 >>> shift_bias_2
                alu1_op  = ALUOP_ASR;
                alu1_op1 = input_1;
                alu1_op2 = shift_bias_1_reg;

                alu2_op  = ALUOP_ASR;
                alu2_op1 = input_2;
                alu2_op2 = shift_bias_2_reg;

                inter_1_next = alu1_result;
                inter_2_next = alu2_result;

                ovf_this_stage  = alu1_ovf  | alu2_ovf;
                zero_this_stage = alu1_zero | alu2_zero;

               // αν overflow: κορεσμός και μετάβαση σε IDLE 
                if (ovf_this_stage) begin
                    final_output_next = SAT_OVF;
                    next_state        = ST_IDLE;
                end else begin
                    next_state        = ST_INPUT_L;
                end
            end

            ST_INPUT_L: begin
                // inter_3 = inter_1 * weight_1 + bias_1
                // inter_4 = inter_2 * weight_2 + bias_2
                mac1_op1 = inter_1;
                mac1_op2 = weight_1_reg;
                mac1_op3 = bias_1_reg;

                mac2_op1 = inter_2;
                mac2_op2 = weight_2_reg;
                mac2_op3 = bias_2_reg;

                inter_3_next = mac1_result;
                inter_4_next = mac2_result;

                ovf_this_stage  = mac1_ovf_mul | mac1_ovf_add |
                                  mac2_ovf_mul | mac2_ovf_add;

                zero_this_stage = mac1_zero_mul | mac1_zero_add |
                                  mac2_zero_mul | mac2_zero_add;

                if (ovf_this_stage) begin
                    final_output_next = SAT_OVF;
                    next_state        = ST_IDLE;
                end else begin
                    next_state        = ST_OUTPUT_L;
                end
            end

            ST_OUTPUT_L: begin           
                // temp = inter_3 * weight_3 + bias_3
                mac1_op1 = inter_3;
                mac1_op2 = weight_3_reg;
                mac1_op3 = bias_3_reg;
				// inter_5 = inter_4 * weight_4 + temp
                mac2_op1 = inter_4;
                mac2_op2 = weight_4_reg;
                mac2_op3 = mac1_result;

                inter_5_next = mac2_result;

                ovf_this_stage  = mac1_ovf_mul | mac1_ovf_add |
                                  mac2_ovf_mul | mac2_ovf_add;

                zero_this_stage = mac1_zero_mul | mac1_zero_add |
                                  mac2_zero_mul | mac2_zero_add;

                if (ovf_this_stage) begin
                    final_output_next = SAT_OVF;
                    next_state        = ST_IDLE;
                end else begin
                    next_state        = ST_POSTPROC;
                end
            end

            ST_POSTPROC: begin
                // final_output = inter_5 <<< shift_bias_3
                alu1_op  = ALUOP_ASL;
                alu1_op1 = inter_5;
                alu1_op2 = shift_bias_3_reg;

                final_output_next = alu1_result;

                ovf_this_stage  = alu1_ovf;
                zero_this_stage = alu1_zero;

                if (ovf_this_stage) begin
                    final_output_next = SAT_OVF;
                    next_state        = ST_IDLE;
                end else begin
                    next_state        = ST_IDLE;
                end
            end

            ST_IDLE: begin
                if (enable) begin
                    next_state = ST_PREPROC;
                end
            end

            default: begin
                next_state = ST_DEACTIVATED;
            end
        endcase
    end

    // Σύνδεση register σε outputs
    assign final_output   = final_output_reg;
    assign total_ovf      = total_ovf_reg;
    assign total_zero     = total_zero_reg;
    assign ovf_fsm_stage  = ovf_fsm_stage_reg;
    assign zero_fsm_stage = zero_fsm_stage_reg;

endmodule
