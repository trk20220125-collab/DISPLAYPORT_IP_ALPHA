module aux_periph (
    input  wire        clk,
    input  wire        rst_n,

    // Host AUX interface (DP 1.2 native AUX)
    input  wire        aux_req_valid,
    input  wire [1:0]  aux_req_type,     // 00=WRITE, 01=READ, 10=I2C_WRITE, 11=I2C_READ
    input  wire [19:0] aux_req_addr,     // 20-bit address
    input  wire [7:0]  aux_req_len,      // Length-1 (0-15)
    input  wire [7:0]  aux_req_data,     // Write data byte
    input  wire        aux_req_data_valid,
    input  wire        aux_req_last,
    output reg         aux_busy,
    output reg         aux_resp_valid,
    output reg [1:0]   aux_resp_reply,   // 00=ACK, 01=NACK, 10=DEFER
    output reg [7:0]   aux_resp_data,
    output reg         aux_resp_last,

    // RISC-V memory slave interface
    input  wire        cpu_valid,
    input  wire [31:0] cpu_addr,
    input  wire [31:0] cpu_wdata,
    input  wire [3:0]  cpu_wstrb,
    output reg  [31:0] cpu_rdata,

    // AUX PHY interface
    output reg         phy_tx_start,
    output reg [1:0]   phy_tx_type,
    output reg [19:0]  phy_tx_addr,
    output reg [7:0]   phy_tx_len,
    output reg [7:0]   phy_tx_data,
    output reg         phy_tx_data_valid,
    output reg         phy_tx_last,
    input  wire        phy_tx_ready,
    input  wire        phy_tx_done,
    input  wire        phy_rx_valid,
    input  wire [1:0]  phy_rx_reply,
    input  wire [7:0]  phy_rx_data,
    input  wire        phy_rx_last,
    input  wire        phy_rx_err
);

    reg  req_pending;
    reg  resp_ready;
    reg [1:0] resp_reply_reg;
    reg [7:0] resp_data_reg;
    reg       resp_last_reg;

    reg [1:0]  host_type;
    reg [19:0] host_addr;
    reg [7:0]  host_len;
    reg [7:0]  host_wdata;
    reg        host_wdata_valid;
    reg        host_last;

    reg [7:0] dpcd_mem [0:255];

    integer i;

    // PHY TX state machine
    localparam [2:0] PHY_TX_IDLE    = 3'd0;
    localparam [2:0] PHY_TX_CMD     = 3'd1;
    localparam [2:0] PHY_TX_DATA    = 3'd2;
    localparam [2:0] PHY_TX_DONE    = 3'd3;

    reg [2:0] phy_tx_state;
    reg       phy_tx_triggered;
    reg [7:0] phy_tx_byte_cnt;
    reg [7:0] phy_tx_total_bytes;

    // DPCD memory initialization
    initial begin
        for (i = 0; i < 256; i = i + 1)
            dpcd_mem[i] = 8'h00;
        dpcd_mem[0] = 8'h01;  // DPCD_REV
        dpcd_mem[1] = 8'h02;  // MAX_LINK_RATE
        dpcd_mem[2] = 8'h03;  // MAX_LANE_COUNT
        dpcd_mem[3] = 8'h04;  // MAX_DOWNSPREAD
    end

    // Host request capture
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            req_pending <= 1'b0;
            resp_ready  <= 1'b0;
            aux_busy    <= 1'b0;
            aux_resp_valid <= 1'b0;
            aux_resp_reply <= 2'd0;
            aux_resp_data  <= 8'h00;
            aux_resp_last  <= 1'b0;
            host_type <= 2'd0;
            host_addr <= 20'd0;
            host_len  <= 8'd0;
            host_wdata <= 8'h00;
            host_wdata_valid <= 1'b0;
            host_last <= 1'b0;
            resp_reply_reg <= 2'd0;
            resp_data_reg <= 8'h00;
            resp_last_reg <= 1'b0;
        end else begin
            aux_resp_valid <= 1'b0;

            if (aux_req_valid && !req_pending && !aux_busy) begin
                host_type <= aux_req_type;
                host_addr <= aux_req_addr;
                host_len  <= aux_req_len;
                host_wdata <= aux_req_data;
                host_wdata_valid <= aux_req_data_valid;
                host_last <= aux_req_last;
                req_pending  <= 1'b1;
                aux_busy     <= 1'b1;
            end

            if (resp_ready) begin
                resp_ready    <= 1'b0;
                req_pending   <= 1'b0;
                aux_busy      <= 1'b0;
                aux_resp_valid <= 1'b1;
                aux_resp_reply <= resp_reply_reg;
                aux_resp_data  <= resp_data_reg;
                aux_resp_last  <= resp_last_reg;
            end
        end
    end

    // PHY TX state machine - formats and sends DP 1.2 transaction
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phy_tx_state       <= PHY_TX_IDLE;
            phy_tx_start       <= 1'b0;
            phy_tx_type        <= 2'd0;
            phy_tx_addr        <= 20'd0;
            phy_tx_len         <= 8'd0;
            phy_tx_data        <= 8'h00;
            phy_tx_data_valid  <= 1'b0;
            phy_tx_last        <= 1'b0;
            phy_tx_triggered   <= 1'b0;
            phy_tx_byte_cnt    <= 8'd0;
            phy_tx_total_bytes <= 8'd0;
        end else begin
            phy_tx_start <= 1'b0;
            phy_tx_data_valid <= 1'b0;

            case (phy_tx_state)
                PHY_TX_IDLE: begin
                    if (resp_ready && !phy_tx_triggered) begin
                        phy_tx_triggered <= 1'b1;
                        phy_tx_type    <= host_type;
                        phy_tx_addr    <= host_addr;
                        phy_tx_len     <= host_len;
                        phy_tx_total_bytes <= host_len + 1;
                        phy_tx_byte_cnt <= 8'd0;
                        phy_tx_state   <= PHY_TX_CMD;
                    end else if (!resp_ready) begin
                        phy_tx_triggered <= 1'b0;
                    end
                end

                PHY_TX_CMD: begin
                    if (phy_tx_ready) begin
                        phy_tx_start <= 1'b1;
                        phy_tx_state <= PHY_TX_DATA;
                        phy_tx_byte_cnt <= 8'd0;
                    end
                end

                PHY_TX_DATA: begin
                    if (phy_tx_ready) begin
                        if (phy_tx_byte_cnt < phy_tx_total_bytes) begin
                            phy_tx_start <= 1'b1;
                            phy_tx_data <= dpcd_mem[phy_tx_addr + phy_tx_byte_cnt];
                            phy_tx_data_valid <= 1'b1;
                            phy_tx_last <= (phy_tx_byte_cnt == phy_tx_total_bytes - 1);
                            phy_tx_byte_cnt <= phy_tx_byte_cnt + 1;
                        end else begin
                            phy_tx_state <= PHY_TX_DONE;
                        end
                    end
                end

                PHY_TX_DONE: begin
                    if (phy_tx_done) begin
                        phy_tx_state <= PHY_TX_IDLE;
                    end
                end
            endcase
        end
    end

    // RX from PHY - capture reply
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            resp_reply_reg <= 2'd0;
            resp_data_reg <= 8'h00;
            resp_last_reg <= 1'b0;
        end else if (phy_rx_valid) begin
            resp_reply_reg <= phy_rx_reply;
            resp_data_reg <= phy_rx_data;
            resp_last_reg <= phy_rx_last;
            resp_ready <= 1'b1;
        end
    end

    // synthesis translate_off
    `ifndef SIM_QUIET
    always @(posedge clk) begin
        if (cpu_valid && cpu_wstrb == 4'b0000 && cpu_addr >= 32'h10000100 && cpu_addr < 32'h10000200)
            $display("DPCD READ  addr=0x%08X data=0x%02X", cpu_addr, dpcd_mem[cpu_addr[7:0]]);
        if (cpu_valid && cpu_wstrb != 4'b0000 && cpu_addr >= 32'h10000100 && cpu_addr < 32'h10000200)
            $display("DPCD WRITE addr=0x%08X data=0x%02X wstrb=%b", cpu_addr, cpu_wdata[7:0], cpu_wstrb);
        if (cpu_valid && cpu_wstrb == 4'b0000 && cpu_addr[11:0] == 12'h000)
            $display("AUX_CTRL  read req_pending=%b", req_pending);
        if (cpu_valid && cpu_wstrb != 4'b0000 && cpu_addr[11:0] == 12'h000)
            $display("AUX_CTRL  write val=0x%08X (resp_ready=%b)", cpu_wdata, cpu_wdata[1]);
    end
    `endif
    // synthesis translate_on

    // RISC-V CPU register interface
    // Address map:
    // 0x00: AUX_CTRL      (RW) [0]=req_pending(RO), [1]=resp_ready(WO)
    // 0x04: AUX_REQ_TYPE  (RO) {6'h0, type[1:0]}
    // 0x08: AUX_REQ_ADDR  (RO) 20-bit address
    // 0x0C: AUX_REQ_LEN   (RO) length-1
    // 0x10: AUX_REQ_WDATA (RO) write data
    // 0x14: AUX_RESP_REPLY (WO) reply code
    // 0x18: AUX_RESP_DATA (WO) response data
    // 0x100-0x1FF: DPCD memory (256 bytes)

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cpu_rdata <= 32'h00000000;
        end else begin
            if (cpu_valid) begin
                if (cpu_wstrb == 4'b0000) begin
                    case (cpu_addr[11:0])
                        12'h000: cpu_rdata <= { 30'h00000000, req_pending };
                        12'h004: cpu_rdata <= { 30'h00000000, host_type };
                        12'h008: cpu_rdata <= { 12'h000, host_addr };
                        12'h00C: cpu_rdata <= { 24'h000000, host_len };
                        12'h010: cpu_rdata <= { 24'h000000, host_wdata };
                        default: cpu_rdata <= 32'h00000000;
                    endcase
                end else begin
                    case (cpu_addr[11:0])
                        12'h000: begin
                            if (cpu_wstrb[0]) resp_ready <= cpu_wdata[1];
                        end
                        12'h014: begin
                            if (cpu_wstrb[0]) resp_reply_reg <= cpu_wdata[1:0];
                        end
                        12'h018: begin
                            if (cpu_wstrb[0]) resp_data_reg <= cpu_wdata[7:0];
                        end
                    endcase
                end

                // DPCD memory access (0x100-0x1FF)
                if (cpu_addr[11:8] == 4'h1) begin
                    if (cpu_wstrb != 4'b0000) begin
                        if (cpu_wstrb[0]) dpcd_mem[cpu_addr[7:0]] <= cpu_wdata[7:0];
                        if (cpu_wstrb[1]) dpcd_mem[cpu_addr[7:0] + 8'h01] <= cpu_wdata[15:8];
                        if (cpu_wstrb[2]) dpcd_mem[cpu_addr[7:0] + 8'h02] <= cpu_wdata[23:16];
                        if (cpu_wstrb[3]) dpcd_mem[cpu_addr[7:0] + 8'h03] <= cpu_wdata[31:24];
                    end
                    cpu_rdata <= dpcd_mem[cpu_addr[7:0]];
                end
            end
        end
    end

endmodule