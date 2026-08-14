module dp_tx_aux_phy #(
    parameter int AUX_CLK_FREQ_HZ = 1_000_000,
    parameter int SYS_CLK_FREQ_HZ = 270_000_000
) (
    input  wire        sys_clk,
    input  wire        sys_rst_n,
    input  wire        aux_clk_en,          // 1 MHz tick from sys_clk domain

    // TX side (controller -> PHY)
    input  wire        tx_start,
    input  wire [7:0]  tx_data,
    input  wire        tx_last,
    output reg         tx_ready,
    output reg         tx_done,

    // RX side (PHY -> controller)
    output reg         rx_valid,
    output reg  [7:0]  rx_data,
    output reg         rx_last,
    output reg         rx_err,

    // Differential AUX pins
    inout  wire        aux_p,
    inout  wire        aux_n
);

    // ------------------------------------------------------------
    // Manchester Encoder (TX)
    // Biphase-Mark: '0' = mid-bit transition 0->1, '1' = mid-bit transition 1->0
    // Bit rate = AUX_CLK_FREQ_HZ (1 Mbps), so 1 bit = 1 µs = 1 aux_clk_en cycle
    // We use a 2x oversample clock internally for clean transitions
    // ------------------------------------------------------------
    localparam int OVERSAMPLE = 2;
    localparam int BIT_CYCLES = SYS_CLK_FREQ_HZ / (AUX_CLK_FREQ_HZ * OVERSAMPLE);

    reg  [$clog2(BIT_CYCLES):0] bit_ctr;
    reg                         aux_clk_en_d;

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            bit_ctr <= 0;
            aux_clk_en_d <= 1'b0;
        end else begin
            aux_clk_en_d <= aux_clk_en;
            if (aux_clk_en) begin
                bit_ctr <= 0;
            end else begin
                bit_ctr <= bit_ctr + 1;
            end
        end
    end

    // TX state machine
    parameter TX_IDLE        = 3'd0;
    parameter TX_PREAMBLE    = 3'd1;
    parameter TX_START_BIT   = 3'd2;
    parameter TX_DATA_BITS   = 3'd3;
    parameter TX_STOP_BIT    = 3'd4;
    parameter TX_TURNAROUND  = 3'd5;

    reg [2:0] tx_state, tx_state_n;
    reg [4:0]  tx_bit_idx;
    reg [7:0]  tx_shift;
    reg        tx_manchester_level;
    reg        tx_driving;

    // Manchester output: differential drive
    assign aux_p = tx_driving ?  tx_manchester_level : 1'bz;
    assign aux_n = tx_driving ? ~tx_manchester_level : 1'bz;

    // TX next-state logic
    always @(*) begin
        tx_state_n = tx_state;
        case (tx_state)
            TX_IDLE:       if (tx_start) tx_state_n = TX_PREAMBLE;
            TX_PREAMBLE:   if (tx_bit_idx == 15 && aux_clk_en) tx_state_n = TX_START_BIT;
            TX_START_BIT:  if (aux_clk_en) tx_state_n = TX_DATA_BITS;
            TX_DATA_BITS:  if (tx_bit_idx == 7 && aux_clk_en) tx_state_n = TX_STOP_BIT;
            TX_STOP_BIT:   if (aux_clk_en) tx_state_n = TX_TURNAROUND;
            TX_TURNAROUND: tx_state_n = TX_IDLE;
        endcase
    end

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            tx_state         <= TX_IDLE;
            tx_bit_idx       <= 0;
            tx_shift         <= 0;
            tx_manchester_level <= 1'b0;
            tx_driving       <= 1'b0;
            tx_ready         <= 1'b1;
            tx_done          <= 1'b0;
        end else begin
            tx_state <= tx_state_n;
            tx_done  <= 1'b0;

            if (aux_clk_en) begin
                case (tx_state)
                    TX_IDLE: begin
                        tx_driving <= 1'b0;
                        tx_ready   <= 1'b1;
                        if (tx_start) begin
                            tx_shift   <= tx_data;
                            tx_bit_idx <= 0;
                            tx_driving <= 1'b1;
                            tx_manchester_level <= 1'b0; // Preamble '0' starts low
                            tx_ready   <= 1'b0;
                        end
                    end

                    TX_PREAMBLE: begin
                        // Manchester '0': toggle mid-bit
                        tx_manchester_level <= ~tx_manchester_level; // first half
                        if (bit_ctr == BIT_CYCLES/2 - 1) begin
                            tx_manchester_level <= ~tx_manchester_level; // second half (transition)
                        end
                        if (tx_bit_idx == 15) tx_bit_idx <= 0;
                        else tx_bit_idx <= tx_bit_idx + 1;
                    end

                    TX_START_BIT: begin
                        // Start bit = '0'
                        tx_manchester_level <= ~tx_manchester_level;
                        if (bit_ctr == BIT_CYCLES/2 - 1) tx_manchester_level <= ~tx_manchester_level;
                        tx_bit_idx <= 0;
                    end

                    TX_DATA_BITS: begin
                        reg bit_val;
                        bit_val = tx_shift[tx_bit_idx];
                        // Manchester: '0' = 0->1 transition, '1' = 1->0 transition
                        if (bit_ctr == 0) begin
                            tx_manchester_level <= bit_val ? 1'b1 : 1'b0; // first half = bit value
                        end else if (bit_ctr == BIT_CYCLES/2 - 1) begin
                            tx_manchester_level <= bit_val ? 1'b0 : 1'b1; // second half = inverted
                        end
                        if (tx_bit_idx == 7) tx_bit_idx <= 0;
                        else tx_bit_idx <= tx_bit_idx + 1;
                    end

                    TX_STOP_BIT: begin
                        // Stop bit = '1'
                        if (bit_ctr == 0) tx_manchester_level <= 1'b1;
                        else if (bit_ctr == BIT_CYCLES/2 - 1) tx_manchester_level <= 1'b0;
                    end

                    TX_TURNAROUND: begin
                        tx_driving <= 1'b0;
                        tx_done    <= 1'b1;
                    end
                endcase
            end
        end
    end

    // ------------------------------------------------------------
    // Manchester Decoder (RX) - simple oversample + edge detect
    // ------------------------------------------------------------
    reg [2:0] aux_p_sync, aux_n_sync;
    wire      aux_diff = aux_p_sync[1] ^ aux_n_sync[1];

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            aux_p_sync <= 3'b000;
            aux_n_sync <= 3'b000;
        end else begin
            aux_p_sync <= {aux_p_sync[1:0], aux_p};
            aux_n_sync <= {aux_n_sync[1:0], aux_n};
        end
    end

    // Edge detection on differential signal
    reg  aux_diff_d;
    wire pos_edge =  aux_diff & ~aux_diff_d;
    wire neg_edge = ~aux_diff &  aux_diff_d;

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) aux_diff_d <= 1'b0;
        else            aux_diff_d <= aux_diff;
    end

    // RX state machine
    parameter RX_IDLE       = 3'd0;
    parameter RX_PREAMBLE   = 3'd1;
    parameter RX_START_BIT  = 3'd2;
    parameter RX_DATA_BITS  = 3'd3;
    parameter RX_STOP_BIT   = 3'd4;

    reg [2:0] rx_state;
    reg [4:0]  rx_bit_idx;
    reg [7:0]  rx_shift;
    reg        rx_sample_phase;

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            rx_state       <= RX_IDLE;
            rx_bit_idx     <= 0;
            rx_shift       <= 0;
            rx_valid       <= 1'b0;
            rx_last        <= 1'b0;
            rx_err         <= 1'b0;
            rx_sample_phase <= 1'b0;
        end else begin
            rx_valid <= 1'b0;
            rx_last  <= 1'b0;
            rx_err   <= 1'b0;

            if (pos_edge || neg_edge) begin
                // Manchester transition detected
                case (rx_state)
                    RX_IDLE: begin
                        // Wait for SYNC pattern (series of '0's = regular transitions)
                        rx_state   <= RX_PREAMBLE;
                        rx_bit_idx <= 0;
                        rx_sample_phase <= 1'b0;
                    end
                    RX_PREAMBLE: begin
                        if (rx_bit_idx == 15) rx_state <= RX_START_BIT;
                        else rx_bit_idx <= rx_bit_idx + 1;
                    end
                    RX_START_BIT: begin
                        // Start bit '0' transition
                        rx_state <= RX_DATA_BITS;
                        rx_bit_idx <= 0;
                    end
                    RX_DATA_BITS: begin
                        // Sample in middle of bit cell
                        if (rx_sample_phase) begin
                            rx_shift[rx_bit_idx] <= aux_diff; // decoded bit
                            if (rx_bit_idx == 7) rx_state <= RX_STOP_BIT;
                            else rx_bit_idx <= rx_bit_idx + 1;
                        end
                        rx_sample_phase <= ~rx_sample_phase;
                    end
                    RX_STOP_BIT: begin
                        // Stop bit '1' - verify
                        rx_valid <= 1'b1;
                        rx_data  <= rx_shift;
                        rx_last  <= 1'b1;
                        rx_err   <= ~aux_diff; // expect '1'
                        rx_state <= RX_IDLE;
                    end
                endcase
            end
        end
    end

endmodule