module regfile #(
    parameter DATAWIDTH = 32  //32 από προεπιλογή
)(
    input                 clk,
    input                 resetn,     // active low reset

    input        [3:0]    readReg1,
    input        [3:0]    readReg2,
    input        [3:0]    readReg3,
    input        [3:0]    readReg4,

    input        [3:0]    writeReg1,
    input        [3:0]    writeReg2,
    input  [DATAWIDTH-1:0] writeData1,
    input  [DATAWIDTH-1:0] writeData2,

    input write,      

    output reg [DATAWIDTH-1:0] readData1,
    output reg [DATAWIDTH-1:0] readData2,
    output reg [DATAWIDTH-1:0] readData3,
    output reg [DATAWIDTH-1:0] readData4
);

    // 16 καταχωρητές των DATAWIDTH bits
    reg [DATAWIDTH-1:0] regs[0:15];

    integer i;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            // Αρχικοποιούμε όλους τους καταχωρητές
            for (i = 0; i < 16; i = i + 1)
                regs[i] <= {DATAWIDTH{1'b0}};

            readData1 <= {DATAWIDTH{1'b0}};
            readData2 <= {DATAWIDTH{1'b0}};
            readData3 <= {DATAWIDTH{1'b0}};
            readData4 <= {DATAWIDTH{1'b0}};
        end else begin
          	if (write) begin   // Εγγραφές
                regs[writeReg1] <= writeData1;
                regs[writeReg2] <= writeData2;
            end

            // Περιπτώσεις όπου διεύθυνση εγγραφής = διεύθυνση ανάγνωσης

            // readData1
            if (write && (writeReg1 == readReg1))
                readData1 <= writeData1;
            else if (write && (writeReg2 == readReg1))
                readData1 <= writeData2;
            else
                readData1 <= regs[readReg1];

            // readData2
            if (write && (writeReg1 == readReg2))
                readData2 <= writeData1;
            else if (write && (writeReg2 == readReg2))
                readData2 <= writeData2;
            else
                readData2 <= regs[readReg2];

            // readData3
            if (write && (writeReg1 == readReg3))
                readData3 <= writeData1;
            else if (write && (writeReg2 == readReg3))
                readData3 <= writeData2;
            else
                readData3 <= regs[readReg3];

            // readData4
            if (write && (writeReg1 == readReg4))
                readData4 <= writeData1;
            else if (write && (writeReg2 == readReg4))
                readData4 <= writeData2;
            else
                readData4 <= regs[readReg4];
        end
    end

endmodule
