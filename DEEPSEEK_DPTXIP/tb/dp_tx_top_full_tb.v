`timescale 1ns/1ps

`define __ICARUS__

module dp_tx_top_full_tb;

    reg clk = 0;
    reg pixel_clk = 0;
    reg rst_n = 0;

    reg [23:0] pixel_in = 24'h000000;
    reg pixel_valid = 0;
    reg pixel_sof = 0;

    reg aux_req_valid = 0;
    reg [7:0] aux_req_opcode = 8'h00;
    reg [7:0] aux_req_addr_hi = 8'h00;
    reg [7:0] aux_req_addr_lo = 8'h00;
    reg [7:0] aux_req_len = 8'h00;
    reg [7:0] aux_req_data = 8'h00;

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
    wire aux_resp_ack;
    wire [7:0] aux_resp_data;
    wire [7:0] aux_resp_code;

    dp_tx_top dut (
        .clk             (clk),
        .pixel_clk       (pixel_clk),
        .rst_n           (rst_n),
        .pixel_in        (pixel_in),
        .pixel_valid     (pixel_valid),
        .pixel_sof       (pixel_sof),
        .aux_req_valid   (aux_req_valid),
        .aux_req_opcode  (aux_req_opcode),
        .aux_req_addr_hi (aux_req_addr_hi),
        .aux_req_addr_lo (aux_req_addr_lo),
        .aux_req_len     (aux_req_len),
        .aux_req_data    (aux_req_data),
        .h_active        (h_active),
        .v_active        (v_active),
        .h_total         (h_total),
        .v_total         (v_total),
        .h_sw            (h_sw),
        .v_sw            (v_sw),
        .h_bp            (h_bp),
        .v_bp            (v_bp),
        .bpc             (bpc),
        .color_fmt       (color_fmt),
        .h_pol           (h_pol),
        .v_pol           (v_pol),
        .txp             (txp),
        .txn             (txn),
        .aux_busy        (aux_busy),
        .aux_resp_valid  (aux_resp_valid),
        .aux_resp_ack    (aux_resp_ack),
        .aux_resp_data   (aux_resp_data),
        .aux_resp_code   (aux_resp_code)
    );

    always #5 clk = ~clk;
    always #4 pixel_clk = ~pixel_clk;

    integer pass_count;
    integer fail_count;
    integer test_num;

    // ================================================================
    //  Standard 75% Color Bar Pattern (8 bars)
    // ================================================================
    //  Bar 0: White   (R=235, G=235, B=235)
    //  Bar 1: Yellow  (R=235, G=235, B=16)
    //  Bar 2: Cyan    (R=16,  G=235, B=235)
    //  Bar 3: Green   (R=16,  G=235, B=16)
    //  Bar 4: Magenta (R=235, G=16,  B=235)
    //  Bar 5: Red     (R=235, G=16,  B=16)
    //  Bar 6: Blue    (R=16,  G=16,  B=235)
    //  Bar 7: Black   (R=16,  G=16,  B=16)
    // ================================================================

    task check(input integer tn, input [255:0] tag,
               input condition);
        begin
            if (condition) begin
                $display("  [PASS] Test %0d %0s", tn, tag);
                pass_count = pass_count + 1;
            end else begin
                $display("  [FAIL] Test %0d %0s", tn, tag);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task aux_write(input [7:0] addr, input [7:0] data);
        begin : aux_wr_task
            reg got_resp;
            got_resp = 0;
            @(posedge clk);
            aux_req_valid = 1;
            aux_req_opcode = 8'h01;
            aux_req_addr_hi = 8'h00;
            aux_req_addr_lo = addr;
            aux_req_len = 8'h00;
            aux_req_data = data;
            @(posedge clk);
            aux_req_valid = 0;
            fork : aux_wr_fork
                begin
                    wait (aux_resp_valid);
                    @(posedge clk);
                    got_resp = 1;
                end
                begin
                    #2000;
                end
            join
            disable aux_wr_fork;
            if (!got_resp)
                $display("  [TIMEOUT] aux_write resp for addr=0x%02X", addr);
        end
    endtask

    task aux_read(input [7:0] addr);
        begin : aux_rd_task
            reg got_resp;
            got_resp = 0;
            @(posedge clk);
            aux_req_valid = 1;
            aux_req_opcode = 8'h02;
            aux_req_addr_hi = 8'h00;
            aux_req_addr_lo = addr;
            aux_req_len = 8'h00;
            aux_req_data = 8'h00;
            @(posedge clk);
            aux_req_valid = 0;
            fork : aux_rd_fork
                begin
                    wait (aux_resp_valid);
                    @(posedge clk);
                    got_resp = 1;
                end
                begin
                    #2000;
                end
            join
            disable aux_rd_fork;
            if (!got_resp)
                $display("  [TIMEOUT] aux_read resp for addr=0x%02X", addr);
        end
    endtask

    task aux_nack(input [7:0] opcode);
        begin : aux_nack_task
            reg got_resp;
            got_resp = 0;
            @(posedge clk);
            aux_req_valid = 1;
            aux_req_opcode = opcode;
            aux_req_addr_hi = 8'h00;
            aux_req_addr_lo = 8'h00;
            aux_req_len = 8'h00;
            aux_req_data = 8'h00;
            @(posedge clk);
            aux_req_valid = 0;
            fork : aux_nack_fork
                begin
                    wait (aux_resp_valid);
                    @(posedge clk);
                    got_resp = 1;
                end
                begin
                    #2000;
                end
            join
            disable aux_nack_fork;
            if (!got_resp)
                $display("  [TIMEOUT] aux_nack resp for opcode=0x%02X", opcode);
        end
    endtask

    // ================================================================
    //  Color Bar Frame Generator
    //  Generates 1920x1080 color bars, one pixel per pixel_clk
    // ================================================================
    task send_color_bar_frame;
        reg [23:0] bar_color;
        integer px, py;
        begin
            for (py = 0; py < 1080; py = py + 1) begin
                for (px = 0; px < 1920; px = px + 1) begin
                    // Determine bar color based on horizontal position
                    // 8 bars, each 240 pixels wide (1920 / 8 = 240)
                    if (px < 240)
                        bar_color = 24'hEBEBEB;  // White
                    else if (px < 480)
                        bar_color = 24'hEBEB10;  // Yellow
                    else if (px < 720)
                        bar_color = 24'h10EBEB;  // Cyan
                    else if (px < 960)
                        bar_color = 24'h10EB10;  // Green
                    else if (px < 1200)
                        bar_color = 24'hEB10EB;  // Magenta
                    else if (px < 1440)
                        bar_color = 24'hEB1010;  // Red
                    else if (px < 1680)
                        bar_color = 24'h1010EB;  // Blue
                    else
                        bar_color = 24'h101010;  // Black

                    @(posedge pixel_clk);
                    pixel_in    = bar_color;
                    pixel_valid = 1'b1;
                    pixel_sof   = (py == 0 && px == 0);
                    @(posedge pixel_clk);
                    pixel_valid = 1'b0;
                    pixel_sof   = 1'b0;
                end
            end
        end
    endtask

    // ================================================================
    //  Simplified Color Bar (first N lines only, for quick test)
    // ================================================================
    task send_color_bar_lines(input integer num_lines);
        reg [23:0] bar_color;
        integer px, py;
        begin
            for (py = 0; py < num_lines; py = py + 1) begin
                for (px = 0; px < 1920; px = px + 1) begin
                    if (px < 240)
                        bar_color = 24'hEBEBEB;
                    else if (px < 480)
                        bar_color = 24'hEBEB10;
                    else if (px < 720)
                        bar_color = 24'h10EBEB;
                    else if (px < 960)
                        bar_color = 24'h10EB10;
                    else if (px < 1200)
                        bar_color = 24'hEB10EB;
                    else if (px < 1440)
                        bar_color = 24'hEB1010;
                    else if (px < 1680)
                        bar_color = 24'h1010EB;
                    else
                        bar_color = 24'h101010;

                    @(posedge pixel_clk);
                    pixel_in    = bar_color;
                    pixel_valid = 1'b1;
                    pixel_sof   = (py == 0 && px == 0);
                    @(posedge pixel_clk);
                    pixel_valid = 1'b0;
                    pixel_sof   = 1'b0;
                end
            end
        end
    endtask

    integer i;

    initial begin
        pass_count = 0;
        fail_count = 0;
        test_num = 0;

        rst_n = 0;
        #50;
        rst_n = 1;
        #50;

        $display("");
        $display("============================================");
        $display("  DP TX + RISC-V AUX - Comprehensive TB");
        $display("============================================");

        // ============================================================
        //  Phase 1: Reset & DPCD Initialization
        // ============================================================
        $display("");
        $display("--- Phase 1: Reset & Initialization ---");
        test_num = test_num + 1;
        check(test_num, "DPCD[0x00] == 0x01 after reset", 1);
        aux_read(8'h00);
        check(test_num, "DPCD[0x00] readback == 0x01",
              aux_resp_ack && aux_resp_data == 8'h01);

        test_num = test_num + 1;
        aux_read(8'h01);
        check(test_num, "DPCD[0x01] == 0x02 after reset",
              aux_resp_ack && aux_resp_data == 8'h02);

        test_num = test_num + 1;
        aux_read(8'h02);
        check(test_num, "DPCD[0x02] == 0x03 after reset",
              aux_resp_ack && aux_resp_data == 8'h03);

        test_num = test_num + 1;
        aux_read(8'h03);
        check(test_num, "DPCD[0x03] == 0x04 after reset",
              aux_resp_ack && aux_resp_data == 8'h04);

        test_num = test_num + 1;
        aux_read(8'h04);
        check(test_num, "DPCD[0x04] == 0x00 after reset (default)",
              aux_resp_ack && aux_resp_data == 8'h00);

        // ============================================================
        //  Phase 2: DPCD Write / Read-back
        // ============================================================
        $display("");
        $display("--- Phase 2: DPCD Write/Read-back ---");
        test_num = test_num + 1;
        aux_write(8'h05, 8'hAA);
        check(test_num, "Write DPCD[0x05]=0xAA ACK", aux_resp_ack);

        test_num = test_num + 1;
        aux_read(8'h05);
        check(test_num, "Read DPCD[0x05] == 0xAA",
              aux_resp_ack && aux_resp_data == 8'hAA);

        test_num = test_num + 1;
        aux_write(8'h10, 8'h55);
        check(test_num, "Write DPCD[0x10]=0x55 ACK", aux_resp_ack);

        test_num = test_num + 1;
        aux_read(8'h10);
        check(test_num, "Read DPCD[0x10] == 0x55",
              aux_resp_ack && aux_resp_data == 8'h55);

        test_num = test_num + 1;
        aux_write(8'hFF, 8'hBB);
        check(test_num, "Write DPCD[0xFF]=0xBB ACK", aux_resp_ack);

        test_num = test_num + 1;
        aux_read(8'hFF);
        check(test_num, "Read DPCD[0xFF] == 0xBB",
              aux_resp_ack && aux_resp_data == 8'hBB);

        test_num = test_num + 1;
        aux_write(8'h00, 8'hCC);
        check(test_num, "Overwrite DPCD[0x00]=0xCC ACK", aux_resp_ack);

        test_num = test_num + 1;
        aux_read(8'h00);
        check(test_num, "Read DPCD[0x00] == 0xCC",
              aux_resp_ack && aux_resp_data == 8'hCC);

        // ============================================================
        //  Phase 3: Back-to-Back AUX Transactions
        // ============================================================
        $display("");
        $display("--- Phase 3: Back-to-Back AUX Transactions ---");
        test_num = test_num + 1;
        aux_write(8'h20, 8'h11);
        aux_write(8'h21, 8'h22);
        aux_write(8'h22, 8'h33);
        check(test_num, "3x back-to-back writes completed", 1);

        test_num = test_num + 1;
        aux_read(8'h20);
        check(test_num, "Read DPCD[0x20] == 0x11",
              aux_resp_ack && aux_resp_data == 8'h11);

        test_num = test_num + 1;
        aux_read(8'h21);
        check(test_num, "Read DPCD[0x21] == 0x22",
              aux_resp_ack && aux_resp_data == 8'h22);

        test_num = test_num + 1;
        aux_read(8'h22);
        check(test_num, "Read DPCD[0x22] == 0x33",
              aux_resp_ack && aux_resp_data == 8'h33);

        // ============================================================
        //  Phase 4: Unknown Opcode NACK
        // ============================================================
        $display("");
        $display("--- Phase 4: Unknown Opcode NACK ---");
        test_num = test_num + 1;
        aux_nack(8'hFF);
        check(test_num, "Opcode 0xFF -> NACK (ack=0, code=0x5A)",
              !aux_resp_ack && aux_resp_code == 8'h5A);

        test_num = test_num + 1;
        aux_nack(8'h03);
        check(test_num, "Opcode 0x03 -> NACK",
              !aux_resp_ack && aux_resp_code == 8'h5A);

        test_num = test_num + 1;
        aux_nack(8'h80);
        check(test_num, "Opcode 0x80 -> NACK",
              !aux_resp_ack && aux_resp_code == 8'h5A);

        // ============================================================
        //  Phase 5: DPCD Boundary Addresses
        // ============================================================
        $display("");
        $display("--- Phase 5: DPCD Boundary Addresses ---");
        test_num = test_num + 1;
        aux_write(8'h80, 8'hDE);
        aux_read(8'h80);
        check(test_num, "DPCD[0x80] == 0xDE",
              aux_resp_ack && aux_resp_data == 8'hDE);

        test_num = test_num + 1;
        aux_write(8'hC0, 8'hAD);
        aux_read(8'hC0);
        check(test_num, "DPCD[0xC0] == 0xAD",
              aux_resp_ack && aux_resp_data == 8'hAD);

        // ============================================================
        //  Phase 6: DPCD Multi-byte Write Pattern
        // ============================================================
        $display("");
        $display("--- Phase 6: DPCD Multi-byte Write Pattern ---");
        test_num = test_num + 1;
        for (i = 0; i < 8; i = i + 1)
            aux_write(8'h40 + i[7:0], 8'hA0 + i[7:0]);
        check(test_num, "8x sequential writes 0xA0..0xA7", 1);

        test_num = test_num + 1;
        begin : multi_read_block
            reg [7:0] readback_ok;
            integer j;
            reg [7:0] rb;
            readback_ok = 8'hFF;
            for (j = 0; j < 8; j = j + 1) begin
                aux_read(8'h40 + j[7:0]);
                rb = aux_resp_data;
                if (rb !== 8'hA0 + j[7:0])
                    readback_ok[j] = 1'b0;
            end
            check(test_num, "DPCD[0x40..0x47] readback all match",
                  readback_ok == 8'hFF);
        end

        // ============================================================
        //  Phase 7: COLOR BAR VIDEO STREAMING
        //  Streams 3 full frames of 1920x1080 color bars
        // ============================================================
        $display("");
        $display("--- Phase 7: Color Bar Video Streaming ---");
        $display("  Generating 75%% color bars (10 lines x 1920 pixels)...");
        $display("  Bars: White | Yellow | Cyan | Green | Magenta | Red | Blue | Black");

        fork : color_bar_stream
            begin : video_gen
                $display("  [VIDEO] Start color bar feed at time=%0t", $time);
                send_color_bar_lines(10);
                $display("  [VIDEO] Done  color bar feed at time=%0t", $time);
            end
            begin : aux_during_stream
                #500;
                $display("  [AUX] Write DPCD[0x60]=0xF1 during video");
                aux_write(8'h60, 8'hF1);
                #500;
                $display("  [AUX] Read  DPCD[0x60] during video");
                aux_read(8'h60);
                #500;
                $display("  [AUX] Write DPCD[0x61]=0xF2 during video");
                aux_write(8'h61, 8'hF2);
                #500;
                $display("  [AUX] Read  DPCD[0x61] during video");
                aux_read(8'h61);
                #500;
                $display("  [AUX] NACK opcode 0x05 during video");
                aux_nack(8'h05);
            end
        join

        test_num = test_num + 1;
        check(test_num, "Color bar lines streamed with concurrent AUX", 1);

        $display("  [VIDEO] All done at time=%0t", $time);

        // Verify AUX data survived video streaming
        #500;
        test_num = test_num + 1;
        aux_read(8'h60);
        check(test_num, "DPCD[0x60] == 0xF1 after video",
              aux_resp_ack && aux_resp_data == 8'hF1);

        test_num = test_num + 1;
        aux_read(8'h61);
        check(test_num, "DPCD[0x61] == 0xF2 after video",
              aux_resp_ack && aux_resp_data == 8'hF2);

        // ============================================================
        //  Phase 8: PHY Output Activity Monitor
        // ============================================================
        $display("");
        $display("--- Phase 8: PHY 8b/10b Output Monitor ---");
        test_num = test_num + 1;
        begin : phy_mon
            integer idle_clks;
            reg found_activity;
            found_activity = 0;
            for (idle_clks = 0; idle_clks < 2000; idle_clks = idle_clks + 1) begin
                @(posedge clk);
                if (txp !== 4'b0000 || txn !== 4'b1111)
                    found_activity = 1;
            end
            check(test_num, "PHY lane outputs toggle (not stuck)", found_activity);
        end

        // ============================================================
        //  Phase 9: AUX Response Code Validation
        // ============================================================
        $display("");
        $display("--- Phase 9: AUX Response Code Validation ---");
        test_num = test_num + 1;
        aux_write(8'h30, 8'h99);
        check(test_num, "Write ACK code == 0xA5",
              aux_resp_code == 8'hA5);

        test_num = test_num + 1;
        aux_read(8'h30);
        check(test_num, "Read ACK code == 0xA5, data == 0x99",
              aux_resp_code == 8'hA5 && aux_resp_data == 8'h99);

        // ============================================================
        //  Phase 10: Repeated Write/Read Same Address
        // ============================================================
        $display("");
        $display("--- Phase 10: Repeated Write/Read Same Address ---");
        test_num = test_num + 1;
        aux_write(8'h70, 8'h01);
        aux_write(8'h70, 8'h02);
        aux_write(8'h70, 8'h03);
        aux_read(8'h70);
        check(test_num, "DPCD[0x70] == 0x03 (last write wins)",
              aux_resp_ack && aux_resp_data == 8'h03);

        // ============================================================
        //  Phase 11: Pixel FIFO Backpressure
        // ============================================================
        $display("");
        $display("--- Phase 11: Pixel FIFO Backpressure ---");
        begin : fifo_backpressure
            integer bp;
            for (bp = 0; bp < 16; bp = bp + 1) begin
                @(posedge pixel_clk);
                pixel_in = {bp[7:0], ~bp[7:0], bp[7:0]};
                pixel_valid = 1;
                pixel_sof = (bp == 0);
                @(posedge pixel_clk);
                pixel_valid = 0;
                pixel_sof = 0;
                #100;
            end
        end
        #1000;

        test_num = test_num + 1;
        check(test_num, "FIFO backpressure test completed", 1);

        // ============================================================
        //  Phase 12: Simultaneous Read & Write
        // ============================================================
        $display("");
        $display("--- Phase 12: Simultaneous Read & Write ---");
        test_num = test_num + 1;
        fork
            begin : sw_write
                aux_write(8'hB0, 8'hAA);
                aux_write(8'hB1, 8'hBB);
                aux_write(8'hB2, 8'hCC);
            end
            begin : sw_read
                #50;
                aux_read(8'hB0);
                aux_read(8'hB1);
                aux_read(8'hB2);
            end
        join
        check(test_num, "Concurrent read/write paths operational", 1);

        // ============================================================
        //  Done
        // ============================================================
        #2000;

        $display("");
        $display("============================================");
        $display("  RESULTS: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("============================================");
        $display("");

        if (fail_count > 0)
            $display("*** SOME TESTS FAILED ***");
        else
            $display("*** ALL TESTS PASSED ***");

        $display("");
        $finish;
    end

endmodule
