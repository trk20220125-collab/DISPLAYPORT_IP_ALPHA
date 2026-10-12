module dp_tx_aux_phy #(
    parameter integer CLK_FREQ_HZ = 270_000_000,
    parameter integer AUX_FREQ_HZ = 1_000_000
) (
    input  wire        sys_clk,
    input  wire        sys_rst_n,

    // TX interface - DP 1.2 AUX transaction
    input  wire        tx_start,
    input  wire [1:0]  tx_type,        // 00=NATIVE_WRITE, 01=NATIVE_READ, 10=I2C_WRITE, 11=I2C_READ
    input  wire [19:0] tx_addr,        // 20-bit address (DPCD or I2C)
    input  wire [7:0]  tx_len,         // Length-1 (0 = 1 byte, 15 = 16 bytes)
    input  wire [7:0]  tx_data,        // Data byte (for WRITE)
    input  wire        tx_data_valid,  // Data byte valid
    input  wire        tx_last,        // Last data byte
    output reg         tx_ready,       // Ready for next byte/command
    output reg         tx_done,        // Transaction complete

    // RX interface - DP 1.2 AUX transaction
    output reg         rx_valid,       // Reply received
    output reg [1:0]   rx_reply_code,  // 00=ACK, 01=NACK, 10=DEFER
    output reg [7:0]   rx_data,        // Data byte
    output reg         rx_last,        // Last data byte
    output reg         rx_err,         // Error (timeout, invalid sync, etc.)

    // Differential AUX pins
    inout  wire        aux_p,
    inout  wire        aux_n
);

    localparam integer HALF_BIT_CYCLES = CLK_FREQ_HZ / (2 * AUX_FREQ_HZ);
    localparam integer PRECHARGE_UI    = 16;
    localparam integer SYNC_ONES_UI    = 16;
    localparam integer SYNC_ZERO_UI    = 1;
    localparam integer PRECHARGE_CYCLES = PRECHARGE_UI * 2 * HALF_BIT_CYCLES;
    localparam integer SYNC_ONES_CYCLES = SYNC_ONES_UI * 2 * HALF_BIT_CYCLES;
    localparam integer SYNC_ZERO_CYCLES = SYNC_ZERO_UI * 2 * HALF_BIT_CYCLES;
    localparam integer BIT_CYCLES = 2 * HALF_BIT_CYCLES;

    // Minimum inter-transaction gap: 400 µs
    localparam integer GAP_CYCLES = 400 * CLK_FREQ_HZ / 1_000_000;

    // Tri-state I/O
    reg        tx_oe;
    reg        tx_out_p, tx_out_n;
    assign aux_p = tx_oe ? tx_out_p : 1'bz;
    assign aux_n = tx_oe ? tx_out_n : 1'bz;

    wire rx_in_p = aux_p;
    wire rx_in_n = aux_n;
    wire rx_diff = rx_in_p ^ rx_in_n;

    // TX state machine
    localparam [4:0] TX_IDLE       = 5'd0;
    localparam [4:0] TX_GAP        = 5'd1;
    localparam [4:0] TX_PRECHG     = 5'd2;
    localparam [4:0] TX_SYNC_1     = 5'd3;
    localparam [4:0] TX_SYNC_0     = 5'd4;
    localparam [4:0] TX_CMD        = 5'd5;
    localparam [4:0] TX_ADDR_HI    = 5'd6;
    localparam [4:0] TX_ADDR_MID   = 5'd7;
    localparam [4:0] TX_ADDR_LO    = 5'd8;
    localparam [4:0] TX_LEN        = 5'd9;
    localparam [4:0] TX_DATA       = 5'd10;
    localparam [4:0] TX_STOP       = 5'd11;
    localparam [4:0] TX_DONE_ST    = 5'd12;

    reg [4:0]  tx_state;
    reg [15:0] tx_half_bit_cnt;
    reg [7:0]  tx_bit_cnt;
    reg [7:0]  tx_byte_cnt;
    reg [7:0]  tx_shift_reg;
    reg        tx_manchester_phase;
    reg [15:0] tx_gap_cnt;

    // TX transaction buffer
    reg [1:0]  tx_type_reg;
    reg [19:0] tx_addr_reg;
    reg [7:0]  tx_len_reg;
    reg [7:0]  tx_data_reg;
    reg        tx_data_valid_reg;
    reg        tx_last_reg;

    // RX state machine
    localparam [3:0] RX_IDLE       = 4'd0;
    localparam [3:0] RX_GAP        = 4'd1;
    localparam [3:0] RX_PRECHG_DET = 4'd2;
    localparam [3:0] RX_SYNC_DET   = 4'd3;
    localparam [3:0] RX_REPLY      = 4'd4;
    localparam [3:0] RX_DATA       = 4'd5;
    localparam [3:0] RX_STOP       = 4'd6;

    reg [3:0]  rx_state;
    reg [15:0] rx_half_bit_cnt;
    reg [7:0]  rx_bit_cnt;
    reg [7:0]  rx_byte_cnt;
    reg [7:0]  rx_shift_reg;
    reg        rx_prev_diff;
    reg [3:0]  rx_sync_ones_cnt;
    reg [15:0] rx_gap_cnt;
    reg [7:0]  rx_expected_bytes;
    reg [1:0]  rx_reply_code_reg;

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
            tx_gap_cnt       <= 16'd0;
            tx_type_reg      <= 2'd0;
            tx_addr_reg      <= 20'd0;
            tx_len_reg       <= 8'd0;
            tx_data_reg      <= 8'd0;
            tx_data_valid_reg <= 1'b0;
            tx_last_reg      <= 1'b0;
        end else begin
            tx_done <= 1'b0;

            case (tx_state)
                TX_IDLE: begin
                    tx_oe <= 1'b0;
                    tx_out_p <= 1'b0;
                    tx_out_n <= 1'b0;
                    tx_ready <= 1'b1;
                    if (tx_start) begin
                        tx_ready       <= 1'b0;
                        tx_type_reg    <= tx_type;
                        tx_addr_reg    <= tx_addr;
                        tx_len_reg     <= tx_len;
                        tx_data_reg    <= tx_data;
                        tx_data_valid_reg <= tx_data_valid;
                        tx_last_reg    <= tx_last;
                        tx_gap_cnt     <= 16'd0;
                        tx_state       <= TX_GAP;
                    end
                end

                TX_GAP: begin
                    // Enforce minimum 400µs inter-transaction gap
                    if (tx_gap_cnt == GAP_CYCLES - 1) begin
                        tx_gap_cnt <= 16'd0;
                        tx_oe <= 1'b1;
                        tx_state <= TX_PRECHG;
                        tx_half_bit_cnt <= 16'd0;
                    end else begin
                        tx_gap_cnt <= tx_gap_cnt + 1;
                    end
                end

                TX_PRECHG: begin
                    // Drive logic '0' (common mode) = AUX_P = 0, AUX_N = 0
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
                    // Manchester '1' = falling edge (10)
                    if (tx_manchester_phase == 1'b0) begin
                        tx_out_p <= 1'b1; tx_out_n <= 1'b0;
                    end else begin
                        tx_out_p <= 1'b0; tx_out_n <= 1'b1;
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
                    // Manchester '0' = rising edge (01)
                    if (tx_manchester_phase == 1'b0) begin
                        tx_out_p <= 1'b0; tx_out_n <= 1'b1;
                    end else begin
                        tx_out_p <= 1'b1; tx_out_n <= 1'b0;
                    end
                    if (tx_half_bit_cnt == SYNC_ZERO_CYCLES - 1) begin
                        tx_half_bit_cnt <= 16'd0;
                        tx_bit_cnt <= 8'd0;
                        // Load command byte: {4'b0000, tx_type[1:0], 2'b00} per DP spec
                        tx_shift_reg <= {4'b0000, tx_type_reg, 2'b00};
                        tx_state <= TX_CMD;
                        tx_manchester_phase <= 1'b0;
                    end else begin
                        tx_half_bit_cnt <= tx_half_bit_cnt + 1;
                        tx_manchester_phase <= ~tx_manchester_phase;
                    end
                end

                TX_CMD: begin
                    // Send command byte (8 bits MSB first)
                    wire current_bit = tx_shift_reg[7];
                    if (tx_manchester_phase == 1'b0) begin
                        tx_out_p <= ~current_bit; tx_out_n <= current_bit;
                    end else begin
                        tx_out_p <= current_bit; tx_out_n <= ~current_bit;
                    end
                    if (tx_half_bit_cnt == BIT_CYCLES - 1) begin
                        tx_half_bit_cnt <= 16'd0;
                        tx_manchester_phase <= 1'b0;
                        if (tx_bit_cnt == 7) begin
                            tx_state <= TX_STOP;
                            tx_bit_cnt <= 8'd0;
                        end else begin
                            tx_bit_cnt <= tx_bit_cnt + 1;
                            tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                        end
                    end else begin
                        tx_half_bit_cnt <= tx_half_bit_cnt + 1;
                        tx_manchester_phase <= ~tx_manchester_phase;
                    end
                end

                TX_ADDR_HI: begin
                    // Address bits [19:12]
                    wire current_bit = tx_shift_reg[7];
                    if (tx_manchester_phase == 1'b0) begin
                        tx_out_p <= ~current_bit; tx_out_n <= current_bit;
                    end else begin
                        tx_out_p <= current_bit; tx_out_n <= ~current_bit;
                    end
                    if (tx_half_bit_cnt == BIT_CYCLES - 1) begin
                        tx_half_bit_cnt <= 16'd0;
                        tx_manchester_phase <= 1'b0;
                        if (tx_bit_cnt == 7) begin
                            tx_state <= TX_STOP;
                            tx_bit_cnt <= 8'd0;
                        end else begin
                            tx_bit_cnt <= tx_bit_cnt + 1;
                            tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                        end
                    end else begin
                        tx_half_bit_cnt <= tx_half_bit_cnt + 1;
                        tx_manchester_phase <= ~tx_manchester_phase;
                    end
                end

                TX_ADDR_MID: begin
                    // Address bits [11:4]
                    wire current_bit = tx_shift_reg[7];
                    if (tx_manchester_phase == 1'b0) begin
                        tx_out_p <= ~current_bit; tx_out_n <= current_bit;
                    end else begin
                        tx_out_p <= current_bit; tx_out_n <= ~current_bit;
                    end
                    if (tx_half_bit_cnt == BIT_CYCLES - 1) begin
                        tx_half_bit_cnt <= 16'd0;
                        tx_manchester_phase <= 1'b0;
                        if (tx_bit_cnt == 7) begin
                            tx_state <= TX_STOP;
                            tx_bit_cnt <= 8'd0;
                        end else begin
                            tx_bit_cnt <= tx_bit_cnt + 1;
                            tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                        end
                    end else begin
                        tx_half_bit_cnt <= tx_half_bit_cnt + 1;
                        tx_manchester_phase <= ~tx_manchester_phase;
                    end
                end

                TX_ADDR_LO: begin
                    // Address bits [3:0] + 4 reserved bits
                    wire current_bit = tx_shift_reg[7];
                    if (tx_manchester_phase == 1'b0) begin
                        tx_out_p <= ~current_bit; tx_out_n <= current_bit;
                    end else begin
                        tx_out_p <= current_bit; tx_out_n <= ~current_bit;
                    end
                    if (tx_half_bit_cnt == BIT_CYCLES - 1) begin
                        tx_half_bit_cnt <= 16'd0;
                        tx_manchester_phase <= 1'b0;
                        if (tx_bit_cnt == 7) begin
                            tx_state <= TX_STOP;
                            tx_bit_cnt <= 8'd0;
                        end else begin
                            tx_bit_cnt <= tx_bit_cnt + 1;
                            tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                        end
                    end else begin
                        tx_half_bit_cnt <= tx_half_bit_cnt + 1;
                        tx_manchester_phase <= ~tx_manchester_phase;
                    end
                end

                TX_LEN: begin
                    // Length byte (number of data bytes - 1)
                    wire current_bit = tx_shift_reg[7];
                    if (tx_manchester_phase == 1'b0) begin
                        tx_out_p <= ~current_bit; tx_out_n <= current_bit;
                    end else begin
                        tx_out_p <= current_bit; tx_out_n <= ~current_bit;
                    end
                    if (tx_half_bit_cnt == BIT_CYCLES - 1) begin
                        tx_half_bit_cnt <= 16'd0;
                        tx_manchester_phase <= 1'b0;
                        if (tx_bit_cnt == 7) begin
                            tx_state <= TX_STOP;
                            tx_bit_cnt <= 8'd0;
                            tx_byte_cnt <= 8'd0;
                        end else begin
                            tx_bit_cnt <= tx_bit_cnt + 1;
                            tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                        end
                    end else begin
                        tx_half_bit_cnt <= tx_half_bit_cnt + 1;
                        tx_manchester_phase <= ~tx_manchester_phase;
                    end
                end

                TX_DATA: begin
                    // Wait for data from controller
                    if (tx_data_valid_reg) begin
                        tx_shift_reg <= tx_data_reg;
                        tx_data_valid_reg <= 1'b0;
                        tx_last_reg <= tx_last;
                    end

                    wire current_bit = tx_shift_reg[7];
                    if (tx_manchester_phase == 1'b0) begin
                        tx_out_p <= ~current_bit; tx_out_n <= current_bit;
                    end else begin
                        tx_out_p <= current_bit; tx_out_n <= ~current_bit;
                    end

                    if (tx_half_bit_cnt == BIT_CYCLES - 1) begin
                        tx_half_bit_cnt <= 16'd0;
                        tx_manchester_phase <= 1'b0;
                        if (tx_bit_cnt == 7) begin
                            tx_state <= TX_STOP;
                            tx_bit_cnt <= 8'd0;
                            tx_byte_cnt <= tx_byte_cnt + 1;
                            if (tx_byte_cnt == tx_len_reg) begin
                                tx_last_reg <= 1'b1;
                            end
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
                        tx_out_p <= 1'b0; tx_out_n <= 1'b1;
                    end else begin
                        tx_out_p <= 1'b1; tx_out_n <= 1'b0;
                    end

                    if (tx_half_bit_cnt == BIT_CYCLES - 1) begin
                        tx_half_bit_cnt <= 16'd0;
                        tx_manchester_phase <= 1'b0;
                        case (tx_state)
                            TX_CMD:     tx_state <= TX_ADDR_HI;
                            TX_ADDR_HI: tx_state <= TX_ADDR_MID;
                            TX_ADDR_MID: tx_state <= TX_ADDR_LO;
                            TX_ADDR_LO: tx_state <= TX_LEN;
                            TX_LEN: begin
                                if (tx_type_reg[1] == 1'b0) begin // NATIVE
                                    if (tx_len_reg == 0) begin
                                        tx_state <= TX_DONE_ST;
                                    end else begin
                                        tx_state <= TX_DATA;
                                        tx_byte_cnt <= 8'd0;
                                    end
                                end else begin // I2C - simplified
                                    tx_state <= TX_DONE_ST;
                                end
                            end
                            TX_DATA: begin
                                if (tx_last_reg) begin
                                    tx_state <= TX_DONE_ST;
                                end else begin
                                    tx_state <= TX_DATA;
                                end
                            end
                            default: tx_state <= TX_DONE_ST;
                        endcase
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
                    tx_gap_cnt <= 16'd0;
                    tx_state <= TX_GAP; // Enforce gap after transaction
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
            rx_sync_ones_cnt <= 4'd0;
            rx_valid        <= 1'b0;
            rx_data         <= 8'd0;
            rx_last         <= 1'b0;
            rx_err          <= 1'b0;
            rx_gap_cnt      <= 16'd0;
            rx_expected_bytes <= 8'd0;
            rx_reply_code_reg <= 2'd0;
        end else begin
            rx_valid <= 1'b0;
            rx_prev_diff <= rx_diff;

            case (rx_state)
                RX_IDLE: begin
                    rx_err <= 1'b0;
                    rx_sync_ones_cnt <= 4'd0;
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

                RX_GAP: begin
                    if (rx_gap_cnt == GAP_CYCLES - 1) begin
                        rx_gap_cnt <= 16'd0;
                        rx_state <= RX_IDLE;
                    end else begin
                        rx_gap_cnt <= rx_gap_cnt + 1;
                    end
                end

                RX_PRECHG_DET: begin
                    if (rx_edge) begin
                        rx_state <= RX_SYNC_DET;
                        rx_half_bit_cnt <= 16'd0;
                        rx_sync_ones_cnt <= 4'd0;
                    end
                end

                RX_SYNC_DET: begin
                    if (rx_edge) begin
                        wire is_falling = rx_prev_diff && !rx_diff;
                        wire is_rising  = !rx_prev_diff && rx_diff;
                        if (is_falling && rx_sync_ones_cnt < 16) begin
                            rx_sync_ones_cnt <= rx_sync_ones_cnt + 1;
                        end else if (is_rising && rx_sync_ones_cnt == 16) begin
                            rx_state <= RX_REPLY;
                            rx_bit_cnt <= 8'd0;
                            rx_shift_reg <= 8'd0;
                            rx_half_bit_cnt <= 16'd0;
                        end else begin
                            rx_state <= RX_IDLE;
                            rx_err <= 1'b1;
                        end
                        rx_half_bit_cnt <= 16'd0;
                    end else begin
                        rx_half_bit_cnt <= rx_half_bit_cnt + 1;
                        if (rx_half_bit_cnt > 4 * HALF_BIT_CYCLES) begin
                            rx_state <= RX_IDLE;
                            rx_err <= 1'b1;
                        end
                    end
                end

                RX_REPLY: begin
                    if (rx_half_bit_cnt == 3 * HALF_BIT_CYCLES/2) begin
                        rx_shift_reg <= {rx_shift_reg[6:0], rx_diff};
                    end
                    if (rx_edge) begin
                        rx_half_bit_cnt <= 16'd0;
                        if (rx_bit_cnt == 7) begin
                            rx_state <= RX_STOP;
                            rx_bit_cnt <= 8'd0;
                            rx_reply_code_reg <= rx_shift_reg[1:0]; // Lower 2 bits = reply code
                        end else begin
                            rx_bit_cnt <= rx_bit_cnt + 1;
                        end
                    end else begin
                        rx_half_bit_cnt <= rx_half_bit_cnt + 1;
                        if (rx_half_bit_cnt > 3 * HALF_BIT_CYCLES) begin
                            rx_state <= RX_IDLE;
                            rx_err <= 1'b1;
                        end
                    end
                end

                RX_DATA: begin
                    if (rx_half_bit_cnt == 3 * HALF_BIT_CYCLES/2) begin
                        rx_shift_reg <= {rx_shift_reg[6:0], rx_diff};
                    end
                    if (rx_edge) begin
                        rx_half_bit_cnt <= 16'd0;
                        if (rx_bit_cnt == 7) begin
                            rx_state <= RX_STOP;
                            rx_bit_cnt <= 8'd0;
                            rx_byte_cnt <= rx_byte_cnt + 1;
                        end else begin
                            rx_bit_cnt <= rx_bit_cnt + 1;
                        end
                    end else begin
                        rx_half_bit_cnt <= rx_half_bit_cnt + 1;
                        if (rx_half_bit_cnt > 3 * HALF_BIT_CYCLES) begin
                            rx_state <= RX_IDLE;
                            rx_err <= 1'b1;
                        end
                    end
                end

                RX_STOP: begin
                    if (rx_edge) begin
                        wire is_rising = !rx_prev_diff && rx_diff;
                        if (is_rising) begin
                            if (rx_state == RX_REPLY) begin
                                // After reply code, check if data follows
                                rx_state <= RX_DATA;
                                rx_expected_bytes <= 8'd0; // Will be set by controller
                                rx_byte_cnt <= 8'd0;
                            end else begin
                                rx_valid <= 1'b1;
                                rx_data <= rx_shift_reg;
                                rx_reply_code <= rx_reply_code_reg;
                                rx_last <= (rx_byte_cnt == rx_expected_bytes);
                                rx_state <= RX_GAP;
                                rx_gap_cnt <= 16'd0;
                            end
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