`timescale 1ns/1ps

`define __ICARUS__

module dp_tx_top_tb;
    reg clk = 0;
    reg pixel_clk = 0;
    reg rst_n = 0;
    reg [23:0] pixel_in = 24'h000000;
    reg pixel_valid = 0;
    reg pixel_sof = 0;
    reg aux_req_valid = 0;
    reg [1:0] aux_req_type = 2'd0;
    reg [19:0] aux_req_addr = 20'd0;
    reg [7:0] aux_req_len = 8'd0;
    reg [7:0] aux_req_data = 8'h00;
    reg aux_req_data_valid = 0;
    reg aux_req_last = 0;

    reg [15:0] h_active = 16'd1920;
    reg [15:0] v_active = 16'd1080;
    reg [15:0] h_total  = 16'd2200;
    reg [15:0] v_total  = 16'd1125;
    reg [15:0] h_sw     = 16'd44;
    reg [15:0] v_sw     = 16'd5;
    reg [15:0] h_bp     = 16'd148;
    reg [15:0] v_bp     = 16'd36;
    reg [7:0]  bpc      = 8'd8;
    reg [7:0]  color_fmt = 8'd0;
    reg        h_pol    = 1'b1;
    reg        v_pol    = 1'b1;

    wire [3:0] txp;
    wire [3:0] txn;
    wire aux_busy;
    wire aux_resp_valid;
    wire [1:0] aux_resp_reply;
    wire [7:0] aux_resp_data;
    wire aux_resp_last;

    // AUX PHY pins
    wire aux_p;
    wire aux_n;

    dp_tx_top dut (
        .clk                 (clk),
        .pixel_clk           (pixel_clk),
        .rst_n               (rst_n),
        .pixel_in            (pixel_in),
        .pixel_valid         (pixel_valid),
        .pixel_sof           (pixel_sof),
        .aux_req_valid       (aux_req_valid),
        .aux_req_type        (aux_req_type),
        .aux_req_addr        (aux_req_addr),
        .aux_req_len         (aux_req_len),
        .aux_req_data        (aux_req_data),
        .aux_req_data_valid  (aux_req_data_valid),
        .aux_req_last        (aux_req_last),
        .h_active            (h_active),
        .v_active            (v_active),
        .h_total             (h_total),
        .v_total             (v_total),
        .h_sw                (h_sw),
        .v_sw                (v_sw),
        .h_bp                (h_bp),
        .v_bp                (v_bp),
        .bpc                 (bpc),
        .color_fmt           (color_fmt),
        .h_pol               (h_pol),
        .v_pol               (v_pol),
        .txp                 (txp),
        .txn                 (txn),
        .aux_busy            (aux_busy),
        .aux_resp_valid      (aux_resp_valid),
        .aux_resp_reply      (aux_resp_reply),
        .aux_resp_data       (aux_resp_data),
        .aux_resp_last       (aux_resp_last),
        .aux_p               (aux_p),
        .aux_n               (aux_n)
    );

    always #5 clk = ~clk;
    always #5 pixel_clk = ~pixel_clk;

    // DP 1.2 AUX command types
    localparam [1:0] AUX_NATIVE_WRITE = 2'b00;
    localparam [1:0] AUX_NATIVE_READ  = 2'b01;
    localparam [1:0] AUX_I2C_WRITE    = 2'b10;
    localparam [1:0] AUX_I2C_READ     = 2'b11;

    // Reply codes
    localparam [1:0] REPLY_ACK  = 2'b00;
    localparam [1:0] REPLY_NACK = 2'b01;
    localparam [1:0] REPLY_DEFER = 2'b10;

    task aux_write(input [19:0] addr, input [7:0] data, input [7:0] len);
        begin : aux_wr_task
            reg got_resp;
            got_resp = 0;
            @(posedge clk);
            aux_req_valid = 1;
            aux_req_type = AUX_NATIVE_WRITE;
            aux_req_addr = addr;
            aux_req_len = len;
            aux_req_data = data;
            aux_req_data_valid = 1;
            aux_req_last = 1;
            @(posedge clk);
            aux_req_valid = 0;
            aux_req_data_valid = 0;
            fork : aux_wr_fork
                begin
                    wait (aux_resp_valid);
                    @(posedge clk);
                    got_resp = 1;
                end
                begin
                    #5000;
                end
            join
            disable aux_wr_fork;
            if (!got_resp)
                $display("  [TIMEOUT] aux_write resp for addr=0x%05X", addr);
        end
    endtask

    task aux_read(input [19:0] addr, input [7:0] len);
        begin : aux_rd_task
            reg got_resp;
            got_resp = 0;
            @(posedge clk);
            aux_req_valid = 1;
            aux_req_type = AUX_NATIVE_READ;
            aux_req_addr = addr;
            aux_req_len = len;
            aux_req_data = 8'h00;
            aux_req_data_valid = 0;
            aux_req_last = 1;
            @(posedge clk);
            aux_req_valid = 0;
            fork : aux_rd_fork
                begin
                    wait (aux_resp_valid);
                    @(posedge clk);
                    got_resp = 1;
                end
                begin
                    #5000;
                end
            join
            disable aux_rd_fork;
            if (!got_resp)
                $display("  [TIMEOUT] aux_read resp for addr=0x%05X", addr);
        end
    endtask

    initial begin
        rst_n = 0;
        #20 rst_n = 1;
        #20;

        // Test 1: Read DPCD[0x01] - should return 0x02 (initial value)
        $display("=== Test 1: Read DPCD[0x01] ===");
        aux_read(20'h00001, 8'd0);
        $display("RESP: reply=%b data=0x%02X (expect ACK=00 data=0x02)",
                 aux_resp_reply, aux_resp_data);

        // Test 2: Write DPCD[0x05] = 0xAA
        $display("=== Test 2: Write DPCD[0x05] = 0xAA ===");
        aux_write(20'h00005, 8'hAA, 8'd0);
        $display("RESP: reply=%b (expect ACK=00)", aux_resp_reply);

        // Test 3: Read back DPCD[0x05] - should return 0xAA
        $display("=== Test 3: Read DPCD[0x05] (expect 0xAA) ===");
        aux_read(20'h00005, 8'd0);
        $display("RESP: reply=%b data=0x%02X (expect ACK=00 data=0xAA)",
                 aux_resp_reply, aux_resp_data);

        // Test 4: Multi-byte read DPCD[0x00..0x03] (4 bytes)
        $display("=== Test 4: Multi-byte read DPCD[0x00..0x03] ===");
        aux_read(20'h00000, 8'd3);
        $display("RESP: reply=%b data=0x%02X (expect ACK=00 data=0x01)",
                 aux_resp_reply, aux_resp_data);

        // Test 5: Verify DPCD[0x00] still has initial values
        $display("=== Test 5: Read DPCD[0x00] (expect 0x01) ===");
        aux_read(20'h00000, 8'd0);
        $display("RESP: reply=%b data=0x%02X (expect ACK=00 data=0x01)",
                 aux_resp_reply, aux_resp_data);

        #100;
        $finish;
    end
endmodule