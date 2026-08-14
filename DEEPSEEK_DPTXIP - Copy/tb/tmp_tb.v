`timescale 1ns/1ps
module tmp_tb;
    reg clk = 0;
    reg rst_n = 0;
    reg [7:0]  in_byte = 0;
    reg        in_valid = 0;
    reg        in_k = 0;
    reg        in_sof = 0;
    wire [9:0] code_out;
    wire       disp_out;

    always #5 clk = ~clk;

    dp_tx_8b10b_enc enc (
        .data_in(in_byte),
        .is_k(in_k),
        .disp_in(1'b0),
        .code_out(code_out),
        .disp_out(disp_out)
    );

    initial begin
        #20 rst_n = 1;
        #20;

        in_byte = 8'hBC; in_k = 1; in_valid = 1;
        @(posedge clk); in_valid = 0;
        $display("K28.5 enc: code=0x%03X disp=%b", code_out, disp_out);

        in_byte = 8'hCB; in_k = 0; in_valid = 1;
        @(posedge clk); in_valid = 0;
        $display("D11.3 enc: code=0x%03X disp=%b", code_out, disp_out);

        in_byte = 8'hC6; in_k = 0; in_valid = 1;
        @(posedge clk); in_valid = 0;
        $display("D6.6 enc:  code=0x%03X disp=%b", code_out, disp_out);

        #100;
        $display("DONE");
        $finish;
    end
endmodule
