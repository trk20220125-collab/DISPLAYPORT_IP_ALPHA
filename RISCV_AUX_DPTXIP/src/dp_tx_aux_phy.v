module dp_tx_aux_phy #(
    parameter integer CLK_FREQ_HZ = 270_000_000,
    parameter integer AUX_FREQ_HZ = 1_000_000
) (
    input  wire        sys_clk,
    input  wire        sys_rst_n,

    // TX interface from AUX controller
    input  wire        tx_start,
    input  wire [7:0]  tx_data,
    input  wire        tx_last,
    output reg         tx_ready,
    output reg         tx_done,

    // RX interface to AUX controller
    output reg         rx_valid,
    output reg [7:0]   rx_data,
    output reg         rx_last,
    output reg         rx_err,

    // Differential AUX pins
    inout  wire        aux_p,
    inout  wire        aux_n
);

    localparam integer HALF_BIT_CYCLES = CLK_FREQ_HZ / (2 * AUX_FREQ_HZ);
    localparam integer PRECHARGE_CYCLES = 16 * 2 * HALF_BIT_CYCLES;
    localparam integer SYNC_ONES_CYCLES = 16 * 2 * HALF_BIT_CYCLES;
    localparam integer SYNC_ZERO_CYCLES = 2 * HALF_BIT_CYCLES;

    // Tri-state I/O
    reg        tx_oe;
    reg        tx_out_p, tx_out_n;
    assign aux_p = tx_oe ? tx_out_p : 1'bz;
    assign aux_n = tx_oe ? tx_out_n : 1'bz;

    wire rx_in_p = aux_p;
    wire rx_in_n = aux_n;
    wire rx_diff = rx_in_p ^ rx_in_n;

    // TX state machine
    localparam [3:0] TX_IDLE     = 4'd0;
    localparam [3:0] TX_PRECHG   = 4'd1;
    localparam [3:0] TX_SYNC_1   = 4'd2;
    localparam [3:0] TX_SYNC_0   = 4'd3;
    localparam [3:0] TX_DATA     = 4'd4;
    localparam [3:0] TX_STOP     = 4'd5;
    localparam [3:0] TX_DONE_ST  = 4'd6;

    reg [3:0]  tx_state;
    reg [15:0] tx_half_bit_cnt;
    reg [7:0]  tx_bit_cnt;
    reg [7:0]  tx_byte_cnt;
    reg [7:0]  tx_shift_reg;
    reg        tx_manchester_phase;

    // RX state machine
    localparam [3:0] RX_IDLE       = 4'd0;
    localparam [3:0] RX_PRECHG_DET = 4'd1;
    localparam [3:0] RX_SYNC_DET   = 4'd2;
    localparam [3:0] RX_DATA       = 4'd3;
    localparam [3:0] RX_STOP       = 4'd4;

    reg [3:0]  rx_state;
    reg [15:0] rx_half_bit_cnt;
    reg [7:0]  rx_bit_cnt;
    reg [7:0]  rx_byte_cnt;
    reg [7:0]  rx_shift_reg;
    reg        rx_prev_diff;
    reg        rx_sync_found;
    reg [3:0]  rx_sync_ones_cnt;

    // Edge detection for clock recovery
    wire rx_edge = rx_diff ^ rx_prev_diff;

    // TX logic
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            tx_state         <= TX_IDLE;
            tx_half_bit_cnt  <= 16'd0;
            tx_bit_cnt       <= 8'd0;
            tx_byte_cnt      <= 8'd0;
            tx_shift_reg     <= 8'd0;
            tx_manchester_phase <= 1'b0;
            tx_oe            <= 1'b0;
            tx_out_p         <= 1'b0;
            tx_out_n         <= 1'b0;
            tx_ready         <= 1'b1;
            tx_done          <= 1'b0;
        end else begin
            tx_done <= 1'b0;

            case (tx_state)
                TX_IDLE: begin
                    tx_oe <= 1'b0;
                    tx_out_p <= 1'b0;
                    tx_out_n <= 1'b0;
                    tx_ready <= 1'b1;
                    if (tx_start) begin
                        tx_ready    <= 1'b0;
                        tx_oe       <= 1'b1;
                        tx_state    <= TX_PRECHG;
                        tx_half_bit_cnt <= 16'd0;
                    end
                end

                TX_PRECHG: begin
                    // Drive logic '0' (differential 0) = AUX_P = 0, AUX_N = 0
                    tx_out_p <= 1'b0;
                    tx_out_n <= 1'b0;
                    if (tx_half_bit_cnt == PRECHARGE_CYCLES - 1) begin
                        tx_half_bit_cnt <= 16'd0;
                        tx_state <= TX_SYNC_1;
                        tx_manchester_phase <= 1'b0;
                    end else begin
                        tx_half_bit_cnt <= tx_half_bit_cnt + 1;
                    end
                end

                TX_SYNC_1: begin
                    // Manchester '1' = falling edge (10): start high, go low at mid-bit
                    if (tx_manchester_phase == 1'b0) begin
                        tx_out_p <= 1'b1;
                        tx_out_n <= 1'b0;
                    end else begin
                        tx_out_p <= 1'b0;
                        tx_out_n <= 1'b1;
                    end

                    if (tx_half_bit_cnt == SYNC_ONES_CYCLES - 1) begin
                        tx_half_bit_cnt <= 16'd0;
                        tx_state <= TX_SYNC_0;
                        tx_manchester_phase <= 1'b0;
                    end else begin
                        tx_half_bit_cnt <= tx_half_bit_cnt + 1;
                        tx_manchester_phase <= ~tx_manchester_phase;
                    end
                end

                TX_SYNC_0: begin
                    // Manchester '0' = rising edge (01): start low, go high at mid-bit
                    if (tx_manchester_phase == 1'b0) begin
                        tx_out_p <= 1'b0;
                        tx_out_n <= 1'b1;
                    end else begin
                        tx_out_p <= 1'b1;
                        tx_out_n <= 1'b0;
                    end

                    if (tx_half_bit_cnt == SYNC_ZERO_CYCLES - 1) begin
                        tx_half_bit_cnt <= 16'd0;
                        tx_bit_cnt <= 8'd0;
                        tx_byte_cnt <= 8'd0;
                        tx_shift_reg <= tx_data;
                        tx_state <= TX_DATA;
                        tx_manchester_phase <= 1'b0;
                    end else begin
                        tx_half_bit_cnt <= tx_half_bit_cnt + 1;
                        tx_manchester_phase <= ~tx_manchester_phase;
                    end
                end

                TX_DATA: begin
                    // Manchester encode current bit
                    wire current_bit = tx_shift_reg[7];
                    if (tx_manchester_phase == 1'b0) begin
                        // First half: invert for Manchester
                        tx_out_p <= ~current_bit;
                        tx_out_n <= current_bit;
                    end else begin
                        // Second half: normal
                        tx_out_p <= current_bit;
                        tx_out_n <= ~current_bit;
                    end

                    if (tx_half_bit_cnt == 2 * HALF_BIT_CYCLES - 1) begin
                        tx_half_bit_cnt <= 16'd0;
                        tx_manchester_phase <= 1'b0;
                        if (tx_bit_cnt == 7) begin
                            // Byte done, send stop bit (Manchester '0')
                            tx_state <= TX_STOP;
                        end else begin
                            tx_bit_cnt <= tx_bit_cnt + 1;
                            tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                        end
                    end else begin
                        tx_half_bit_cnt <= tx_half_bit_cnt + 1;
                        tx_manchester_phase <= ~tx_manchester_phase;
                    end
                end

                TX_STOP: begin
                    // Stop bit = Manchester '0' (rising edge)
                    if (tx_manchester_phase == 1'b0) begin
                        tx_out_p <= 1'b0;
                        tx_out_n <= 1'b1;
                    end else begin
                        tx_out_p <= 1'b1;
                        tx_out_n <= 1'b0;
                    end

                    if (tx_half_bit_cnt == 2 * HALF_BIT_CYCLES - 1) begin
                        tx_half_bit_cnt <= 16'd0;
                        tx_manchester_phase <= 1'b0;
                        if (tx_last) begin
                            tx_state <= TX_DONE_ST;
                        end else begin
                            // Wait for next byte - go back to IDLE for next tx_start
                            tx_state <= TX_IDLE;
                        end
                    end else begin
                        tx_half_bit_cnt <= tx_half_bit_cnt + 1;
                        tx_manchester_phase <= ~tx_manchester_phase;
                    end
                end

                TX_DONE_ST: begin
                    tx_oe <= 1'b0;
                    tx_out_p <= 1'b0;
                    tx_out_n <= 1'b0;
                    tx_done <= 1'b1;
                    tx_state <= TX_IDLE;
                end
            endcase
        end
    end

    // RX logic - Manchester decoding with clock recovery
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            rx_state        <= RX_IDLE;
            rx_half_bit_cnt <= 16'd0;
            rx_bit_cnt      <= 8'd0;
            rx_byte_cnt     <= 8'd0;
            rx_shift_reg    <= 8'd0;
            rx_prev_diff    <= 1'b0;
            rx_sync_found   <= 1'b0;
            rx_sync_ones_cnt <= 4'd0;
            rx_valid        <= 1'b0;
            rx_data         <= 8'd0;
            rx_last         <= 1'b0;
            rx_err          <= 1'b0;
        end else begin
            rx_valid <= 1'b0;
            rx_prev_diff <= rx_diff;

            case (rx_state)
                RX_IDLE: begin
                    rx_err <= 1'b0;
                    rx_sync_found <= 1'b0;
                    rx_sync_ones_cnt <= 4'd0;
                    // Detect precharge: extended logic '0' (diff == 0)
                    if (!rx_diff) begin
                        rx_half_bit_cnt <= rx_half_bit_cnt + 1;
                        if (rx_half_bit_cnt >= PRECHARGE_CYCLES/2) begin
                            rx_state <= RX_PRECHG_DET;
                            rx_half_bit_cnt <= 16'd0;
                        end
                    end else begin
                        rx_half_bit_cnt <= 16'd0;
                    end
                end

                RX_PRECHG_DET: begin
                    // Wait for first edge (start of sync pattern)
                    if (rx_edge) begin
                        rx_state <= RX_SYNC_DET;
                        rx_half_bit_cnt <= 16'd0;
                        rx_sync_ones_cnt <= 4'd0;
                    end
                end

                RX_SYNC_DET: begin
                    // Expect 16 Manchester '1' (falling edges) then 1 Manchester '0' (rising edge)
                    if (rx_edge) begin
                        // Check if it's a falling edge (Manchester '1') or rising (Manchester '0')
                        wire is_falling = rx_prev_diff && !rx_diff; // 1->0
                        wire is_rising  = !rx_prev_diff && rx_diff; // 0->1

                        if (is_falling && rx_sync_ones_cnt < 16) begin
                            rx_sync_ones_cnt <= rx_sync_ones_cnt + 1;
                        end else if (is_rising && rx_sync_ones_cnt == 16) begin
                            // Sync pattern complete
                            rx_state <= RX_DATA;
                            rx_bit_cnt <= 8'd0;
                            rx_shift_reg <= 8'd0;
                            rx_half_bit_cnt <= 16'd0;
                        end else begin
                            // Sync error
                            rx_state <= RX_IDLE;
                            rx_err <= 1'b1;
                        end
                        rx_half_bit_cnt <= 16'd0;
                    end else begin
                        rx_half_bit_cnt <= rx_half_bit_cnt + 1;
                        // Timeout
                        if (rx_half_bit_cnt > 4 * HALF_BIT_CYCLES) begin
                            rx_state <= RX_IDLE;
                            rx_err <= 1'b1;
                        end
                    end
                end

                RX_DATA: begin
                    // Sample at 3/4 bit position (after mid-bit transition)
                    if (rx_half_bit_cnt == 3 * HALF_BIT_CYCLES/2) begin
                        // Manchester: transition at mid-bit determines value
                        // We sample the level after transition
                        wire sampled_bit = rx_diff; // After falling edge = '1', after rising = '0'
                        rx_shift_reg <= {rx_shift_reg[6:0], sampled_bit};
                    end

                    if (rx_edge) begin
                        // Mid-bit transition detected
                        rx_half_bit_cnt <= 16'd0;
                        if (rx_bit_cnt == 7) begin
                            rx_state <= RX_STOP;
                            rx_bit_cnt <= 8'd0;
                        end else begin
                            rx_bit_cnt <= rx_bit_cnt + 1;
                        end
                    end else begin
                        rx_half_bit_cnt <= rx_half_bit_cnt + 1;
                        // Timeout
                        if (rx_half_bit_cnt > 3 * HALF_BIT_CYCLES) begin
                            rx_state <= RX_IDLE;
                            rx_err <= 1'b1;
                        end
                    end
                end

                RX_STOP: begin
                    // Expect Manchester '0' (rising edge) as stop bit
                    if (rx_edge) begin
                        wire is_rising = !rx_prev_diff && rx_diff;
                        if (is_rising) begin
                            rx_valid <= 1'b1;
                            rx_data <= rx_shift_reg;
                            rx_last <= 1'b1; // Simplified: assume single byte
                            rx_state <= RX_IDLE;
                        end else begin
                            rx_err <= 1'b1;
                            rx_state <= RX_IDLE;
                        end
                    end else begin
                        rx_half_bit_cnt <= rx_half_bit_cnt + 1;
                        if (rx_half_bit_cnt > 3 * HALF_BIT_CYCLES) begin
                            rx_err <= 1'b1;
                            rx_state <= RX_IDLE;
                        end
                    end
                end
            endcase
        end
    end

    endmodule