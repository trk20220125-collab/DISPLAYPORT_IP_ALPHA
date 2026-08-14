// =============================================================================
// Clock Generator: 135 MHz reference -> 270 MHz byte clock + 148.5 MHz pixel clock
// Uses Xilinx MMCM (Kintex-7 / Artix-7)
// =============================================================================

module dp_tx_clk_gen (
    input  wire  refclk,        // 135 MHz reference clock
    input  wire  rst_n,         // active-low reset
    output wire  clk,           // 270 MHz byte clock (link domain)
    output wire  pixel_clk,     // 148.5 MHz pixel clock (video domain)
    output wire  locked         // MMCM locked indicator
);

    wire clk_fb;
    wire clk_270;
    wire clk_148_5;
    wire locked_i;

    // MMCM_BASE for Kintex-7 / Artix-7
    // VCO = 135 MHz × 11 = 1485 MHz (within 600-1600 MHz range)
    //   CLKOUT0 = 1485/5.5 = 270 MHz  (byte clock, exact)
    //   CLKOUT1 = 1485/10  = 148.5 MHz (pixel clock, exact)
    // Both frequencies are exact using fractional divide on CLKOUT0

    MMCM_BASE #(
        .BANDWIDTH          ("OPTIMIZED"),
        .CLKFBOUT_MULT_F   (11.0),        // VCO = 135 MHz × 11 = 1485 MHz
        .CLKFBOUT_PHASE    (0.0),
        .CLKIN1_PERIOD     (7.407),       // 135 MHz → 1/135MHz = 7.407 ns
        .CLKOUT0_DIVIDE_F  (5.5),         // 1485/5.5 = 270 MHz (byte clock)
        .CLKOUT0_DUTY_CYCLE(0.5),
        .CLKOUT0_PHASE     (0.0),
        .CLKOUT1_DIVIDE    (10),          // 1485/10 = 148.5 MHz (pixel clock, exact)
        .CLKOUT1_DUTY_CYCLE(0.5),
        .CLKOUT1_PHASE     (0.0),
        .CLKOUT2_DIVIDE    (1),
        .CLKOUT3_DIVIDE    (1),
        .CLKOUT4_DIVIDE    (1),
        .CLKOUT5_DIVIDE    (1),
        .CLKOUT6_DIVIDE    (1),
        .CLK_FEEDBACK      ("CLKFBOUT"),
        .COMPENSATION      ("ZHOLD"),
        .DIVCLK_DIVIDE     (1),
        .REF_JITTER1       (0.01),
        .STARTUP_WAIT      ("FALSE")
    ) mmcm_inst (
        .CLKIN1    (refclk),
        .CLKFBIN   (clk_fb),
        .CLKFBOUT  (clk_fb),
        .CLKFBOUTB (),
        .CLKOUT0   (clk_270),
        .CLKOUT0B  (),
        .CLKOUT1   (clk_148_5),
        .CLKOUT1B  (),
        .CLKOUT2   (),
        .CLKOUT2B  (),
        .CLKOUT3   (),
        .CLKOUT3B  (),
        .CLKOUT4   (),
        .CLKOUT5   (),
        .CLKOUT6   (),
        .LOCKED    (locked_i),
        .PWRDWN    (1'b0),
        .RST       (~rst_n),
        .DCLK      (1'b0),
        .DRDY      (),
        .DADDR     (7'd0),
        .DWE       (1'b0),
        .DEN       (1'b0),
        .DI        (16'd0),
        .DO        (),
        .PSCLK     (1'b0),
        .PSEN      (1'b0),
        .PSINCDEC  (1'b0),
        .PSDONE    ()
    );

    // Buffer outputs
    BUFG bufg_byte  (.I(clk_270),   .O(clk));
    BUFG bufg_pixel (.I(clk_148_5), .O(pixel_clk));

    assign locked = locked_i;

endmodule
