module calc_enc (
    input  btnl,
    input  btnr,
    input  btnd,
    output [3:0] alu_op
);

     // alu_op[0]
    wire n_btnl_0, n_btnd_0;
    wire mid_and_0, top_and_0, bot_and_0;

    // NOT(btnl) και NOT(btnd)
    not u0_not_l (n_btnl_0, btnl);
    not u0_not_d (n_btnd_0, btnd);
  
    // mid = btnr & btnl
    and u0_and_mid (mid_and_0, btnr, btnl);

    // top = ~btnl & btnd
    and u0_and_top (top_and_0, n_btnl_0, btnd);

    // bot = ~btnd & mid
    and u0_and_bot (bot_and_0, n_btnd_0, mid_and_0);

    // alu_op[0] = top | bot
    or  u0_or (alu_op[0], top_and_0, bot_and_0);



    
  // alu_op[1] 
    
    wire n_btnr_1, n_btnd_1, or1_1;

    // NOT(btnr), NOT(btnd)
    not u1_not_r (n_btnr_1, btnr);
    not u1_not_d (n_btnd_1, btnd);

    // OR( ~btnr, ~btnd )
    or  u1_or    (or1_1, n_btnr_1, n_btnd_1);

    // AND( btnl , OR(...) ) -> alu_op[1]
    and u1_and   (alu_op[1], btnl, or1_1);


  
  
    // alu_op[2]
    wire n_btnl_2, and_top_2;
    wire xor_2, n_xor_2, and_bot_2;

    // NOT(btnl) AND btnr
    not u2_not_l   (n_btnl_2, btnl);
    and u2_and_top (and_top_2, n_btnl_2, btnr);

    // btnr AND NOT( btnr XOR btnd )
    xor u2_xor     (xor_2, btnr, btnd);
    not u2_not_xor (n_xor_2, xor_2);
    and u2_and_bot (and_bot_2, btnl, n_xor_2);

    // OR των δύο κλαδιών = alu_op[2]
    or  u2_or (alu_op[2], and_top_2, and_bot_2);




  // alu_op[3] 
    wire and_top_3, and_bot_3;

    // πάνω AND: btnl AND btnr
    and u3_and_top (and_top_3, btnl, btnr);

    // κάτω AND:  btnr AND btnd
    and u3_and_bot (and_bot_3, btnl, btnd);

    // OR των δύο AND = alu_op[3]
    or  u3_or (alu_op[3], and_top_3, and_bot_3);

endmodule
