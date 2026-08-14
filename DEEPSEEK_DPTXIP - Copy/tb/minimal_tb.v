`timescale 1ns/1ps
module minimal_tb;
    reg clk = 0;
    reg rst_n = 0;
    wire [3:0] txp;
    wire [3:0] txn;
    always #5 clk = ~clk;

    dp_tx_top dut (
        .clk(clk), .rst_n(rst_n),
        .pixel_in(24'h000000), .pixel_valid(0), .pixel_sof(0),
        .aux_req_valid(0), .aux_req_opcode(0), .aux_req_addr_hi(0),
        .aux_req_addr_lo(0), .aux_req_len(0), .aux_req_data(0),
        .h_active(16), .v_active(4), .h_total(32), .v_total(8),
        .h_sw(4), .v_sw(1), .h_bp(4), .v_bp(1),
        .bpc(8), .color_fmt(0), .h_pol(1), .v_pol(1),
        .txp(txp), .txn(txn),
        .aux_busy(), .aux_resp_valid(), .aux_resp_ack(),
        .aux_resp_data(), .aux_resp_code()
    );

    integer cyc;
    always @(posedge clk) cyc = cyc + 1;

    initial begin
        #25 rst_n = 1;
        #10050; // about 1000 cycles at 10ns period
        $display("DONE at cycle %0d time=%0t", cyc, $time);
        $finish;
    end
endmodule
