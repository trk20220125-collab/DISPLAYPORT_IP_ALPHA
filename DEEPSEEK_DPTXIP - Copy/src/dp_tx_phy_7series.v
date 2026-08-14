module dp_tx_phy_7series (
    input  wire        clk,           // byte clock (e.g., 270 MHz for HBR)
    input  wire        rst_n,
    input  wire [31:0] tx_data,       // 4 bytes from lane mapper
    input  wire [3:0]  tx_k_mask,     // K-code flag per byte
    input  wire        tx_valid,
    input  wire        tx_sof,
    output wire [9:0]  tx_code0,
    output wire [9:0]  tx_code1,
    output wire [9:0]  tx_code2,
    output wire [9:0]  tx_code3,
    output wire [3:0]  txp,
    output wire [3:0]  txn
);

    reg disp0, disp1, disp2, disp3;
    wire disp_next0, disp_next1, disp_next2, disp_next3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            disp0 <= 1'b0;
            disp1 <= 1'b0;
            disp2 <= 1'b0;
            disp3 <= 1'b0;
        end else if (tx_valid) begin
            disp0 <= disp_next0;
            disp1 <= disp_next1;
            disp2 <= disp_next2;
            disp3 <= disp_next3;
        end
    end

    dp_tx_8b10b_enc enc0 (
        .data_in (tx_data[7:0]),
        .is_k    (tx_k_mask[0]),
        .disp_in (disp0),
        .code_out(tx_code0),
        .disp_out(disp_next0)
    );

    dp_tx_8b10b_enc enc1 (
        .data_in (tx_data[15:8]),
        .is_k    (tx_k_mask[1]),
        .disp_in (disp1),
        .code_out(tx_code1),
        .disp_out(disp_next1)
    );

    dp_tx_8b10b_enc enc2 (
        .data_in (tx_data[23:16]),
        .is_k    (tx_k_mask[2]),
        .disp_in (disp2),
        .code_out(tx_code2),
        .disp_out(disp_next2)
    );

    dp_tx_8b10b_enc enc3 (
        .data_in (tx_data[31:24]),
        .is_k    (tx_k_mask[3]),
        .disp_in (disp3),
        .code_out(tx_code3),
        .disp_out(disp_next3)
    );

`ifdef __ICARUS__
    assign txp[0] = tx_code0[0];
    assign txn[0] = ~tx_code0[0];
    assign txp[1] = tx_code1[0];
    assign txn[1] = ~tx_code1[0];
    assign txp[2] = tx_code2[0];
    assign txn[2] = ~tx_code2[0];
    assign txp[3] = tx_code3[0];
    assign txn[3] = ~tx_code3[0];
`else
    reg gearbox_toggle;
    reg [9:0] sym_odd[3:0];
    reg [19:0] gtx_txdata[3:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gearbox_toggle <= 1'b0;
        end else if (tx_valid) begin
            gearbox_toggle <= ~gearbox_toggle;
            if (!gearbox_toggle) begin
                sym_odd[0] <= tx_code0;
                sym_odd[1] <= tx_code1;
                sym_odd[2] <= tx_code2;
                sym_odd[3] <= tx_code3;
            end else begin
                gtx_txdata[0] <= {tx_code0[9:0], sym_odd[0]};
                gtx_txdata[1] <= {tx_code1[9:0], sym_odd[1]};
                gtx_txdata[2] <= {tx_code2[9:0], sym_odd[2]};
                gtx_txdata[3] <= {tx_code3[9:0], sym_odd[3]};
            end
        end
    end

    wire gtx_txusrclk2;
    BUFGCE_DIV #(.BUFGCE_DIVIDE(2)) bufg_div (
        .I(clk), .O(gtx_txusrclk2), .CE(1'b1), .CLR(~rst_n)
    );

    reg [7:0] gtx_rst_cnt;
    reg gtx_txusrrdy;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gtx_rst_cnt  <= 8'd0;
            gtx_txusrrdy <= 1'b0;
        end else if (gtx_rst_cnt < 8'd200) begin
            gtx_rst_cnt <= gtx_rst_cnt + 1;
        end else begin
            gtx_txusrrdy <= 1'b1;
        end
    end

    genvar l;
    generate
        for (l = 0; l < 4; l = l + 1) begin : gtx_lane
            wire lane_txp, lane_txn;

            GTXE2_CHANNEL #(
                .TX_DATA_WIDTH(20),
                .TX_INT_DATAWIDTH(0),
                .TX_8B10B_EN("FALSE"),
                .TXOUT_DIV(1),
                .TX_CLK25_DIV(10),
                .PMA_RSV(32'h00000000),
                .TX_PMA_CFG(16'h0080),
                .SIM_GTRESET_SPEEDUP("TRUE"),
                .SIM_TX_RESET_SPEEDUP("TRUE")
            ) gtx_inst (
                .GTREFCLK0    (clk),
                .GTREFCLK1    (1'b0),
                .TXPD         (2'b00),
                .TXSYSCLKSEL  (2'b01),
                .TXUSRCLK     (gtx_txusrclk2),
                .TXUSRCLK2    (gtx_txusrclk2),
                .TXDATA       (gtx_txdata[l]),
                .TXBYPASS8B10B({2{1'b1}}),
                .TXCHARDISPMODE(2'b00),
                .TXCHARDISPVAL (2'b00),
                .TXCHARISK     (2'b00),
                .TXPOLARITY    (1'b0),
                .TXDIFFCTRL    (3'b100),
                .TXMAINCURSOR  (7'b0000000),
                .TXDETECTRX    (1'b0),
                .TXDLYBYPASS   (1'b1),
                .TXRESETMODE   (1'b0),
                .TXPCSRESET    (1'b0),
                .TXBUFPDCE     (1'b0),
                .TXBUFRESET    (1'b0),
                .GTTXRESET     (1'b0),
                .TXUSERRDY     (gtx_txusrrdy),
                .TXP           (lane_txp),
                .TXN           (lane_txn)
            );

            assign txp[l] = lane_txp;
            assign txn[l] = lane_txn;
        end
    endgenerate
`endif

endmodule
