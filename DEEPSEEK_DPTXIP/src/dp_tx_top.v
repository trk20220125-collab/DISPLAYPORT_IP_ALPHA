module dp_tx_top (
    input  wire        clk,          // byte clock (link domain)
    input  wire        pixel_clk,    // pixel clock (video domain)
    input  wire        rst_n,
    input  wire [23:0] pixel_in,
    input  wire        pixel_valid,
    input  wire        pixel_sof,
    input  wire        aux_req_valid,
    input  wire [7:0]  aux_req_opcode,
    input  wire [7:0]  aux_req_addr_hi,
    input  wire [7:0]  aux_req_addr_lo,
    input  wire [7:0]  aux_req_len,
    input  wire [7:0]  aux_req_data,
    input  wire [15:0] h_active,
    input  wire [15:0] v_active,
    input  wire [15:0] h_total,
    input  wire [15:0] v_total,
    input  wire [15:0] h_sw,
    input  wire [15:0] v_sw,
    input  wire [15:0] h_bp,
    input  wire [15:0] v_bp,
    input  wire [7:0]  bpc,
    input  wire [7:0]  color_fmt,
    input  wire        h_pol,
    input  wire        v_pol,
    output wire [3:0]  txp,
    output wire [3:0]  txn,
    output wire        aux_busy,
    output wire        aux_resp_valid,
    output wire        aux_resp_ack,
    output wire [7:0]  aux_resp_data,
    output wire [7:0]  aux_resp_code
);

    wire [7:0] packed_byte;
    wire       packed_valid;
    wire       packed_sof;
    wire [7:0] scrambled_byte;
    wire       scrambled_valid;
    wire [7:0] msa_byte;
    wire       msa_valid;
    wire       msa_sof;
    wire       msa_busy;
    wire [7:0] mux_byte;
    wire       mux_valid;
    wire       mux_sof;
    wire       mux_k;
    wire       scrambler_rst;
    wire [31:0] lane_data;
    wire [3:0]  lane_k_mask;
    wire        lane_valid;
    wire        lane_sof;
    wire [9:0]  tx_code0, tx_code1, tx_code2, tx_code3;

    wire [23:0] fifo_pixel;
    wire        fifo_sof;
    wire        fifo_empty;
    wire        packer_pixel_ready;
    wire        pixel_consumed;

    assign pixel_consumed = packer_pixel_ready && !fifo_empty;

    reg [15:0] h_count, v_count;
    reg        in_vblank, prev_vblank;
    wire       blanking;
    wire       msa_trig;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h_count <= 16'd0;
            v_count <= 16'd0;
        end else if (pixel_consumed) begin
            if (h_count == h_total - 1) begin
                h_count <= 16'd0;
                if (v_count == v_total - 1)
                    v_count <= 16'd0;
                else
                    v_count <= v_count + 1;
            end else begin
                h_count <= h_count + 1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            in_vblank <= 1'b1;
        else if (pixel_consumed) begin
            if (v_count >= v_active)
                in_vblank <= 1'b1;
            else if (v_count == 0 && h_count == 0)
                in_vblank <= 1'b0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            prev_vblank <= 1'b0;
        else
            prev_vblank <= in_vblank;
    end

    assign blanking = (h_count >= h_active);
    assign msa_trig = in_vblank && !prev_vblank;

    dp_tx_pixel_fifo #(.WIDTH(25)) fifo (
        .wr_clk    (pixel_clk),
        .wr_rst_n  (rst_n),
        .wr_en     (pixel_valid),
        .wr_data   ({pixel_sof, pixel_in[23:0]}),
        .full      (),
        .rd_clk    (clk),
        .rd_rst_n  (rst_n),
        .rd_en     (pixel_consumed),
        .rd_data   ({fifo_sof, fifo_pixel}),
        .empty     (fifo_empty)
    );

    dp_tx_video_packer packer (
        .clk        (clk),
        .rst_n      (rst_n),
        .pixel_in   (fifo_pixel),
        .pixel_valid(!fifo_empty),
        .pixel_sof  (fifo_sof),
        .pixel_ready(packer_pixel_ready),
        .byte_out   (packed_byte),
        .byte_valid (packed_valid),
        .byte_sof   (packed_sof)
    );

    dp_tx_scrambler scrambler (
        .clk           (clk),
        .rst_n         (rst_n),
        .scrambler_rst (scrambler_rst),
        .data_in       (packed_byte),
        .data_valid    (packed_valid),
        .data_out      (scrambled_byte),
        .data_out_valid(scrambled_valid)
    );

    dp_tx_msa_gen msa_gen (
        .clk       (clk),
        .rst_n     (rst_n),
        .h_active  (h_active),
        .v_active  (v_active),
        .h_total   (h_total),
        .v_total   (v_total),
        .h_sw      (h_sw),
        .v_sw      (v_sw),
        .h_bp      (h_bp),
        .v_bp      (v_bp),
        .bpc       (bpc),
        .color_fmt (color_fmt),
        .h_pol     (h_pol),
        .v_pol     (v_pol),
        .trig      (msa_trig),
        .busy      (msa_busy),
        .byte_out  (msa_byte),
        .byte_valid(msa_valid),
        .byte_sof  (msa_sof)
    );

    dp_tx_stream_mux stream_mux (
        .clk        (clk),
        .rst_n      (rst_n),
        .blanking   (blanking),
        .in_vblank  (in_vblank),
        .msa_byte   (msa_byte),
        .msa_valid  (msa_valid),
        .msa_sof    (msa_sof),
        .video_byte (scrambled_byte),
        .video_valid(scrambled_valid),
        .video_sof  (packed_sof),
        .out_byte      (mux_byte),
        .out_valid     (mux_valid),
        .out_sof       (mux_sof),
        .out_k         (mux_k),
        .scrambler_rst (scrambler_rst)
    );

    riscv_soc riscv_aux_ctrl (
        .clk             (clk),
        .rst_n           (rst_n),
        .aux_req_valid   (aux_req_valid),
        .aux_req_opcode  (aux_req_opcode),
        .aux_req_addr_hi (aux_req_addr_hi),
        .aux_req_addr_lo (aux_req_addr_lo),
        .aux_req_len     (aux_req_len),
        .aux_req_data    (aux_req_data),
        .aux_busy        (aux_busy),
        .aux_resp_valid  (aux_resp_valid),
        .aux_resp_ack    (aux_resp_ack),
        .aux_resp_data   (aux_resp_data),
        .aux_resp_code   (aux_resp_code)
    );

    dp_tx_lane_mapper #(.LANE_COUNT(4)) lane_map (
        .clk        (clk),
        .rst_n      (rst_n),
        .in_byte    (mux_byte),
        .in_valid   (mux_valid),
        .in_sof     (mux_sof),
        .in_k       (mux_k),
        .out_data   (lane_data),
        .out_k_mask (lane_k_mask),
        .out_valid  (lane_valid),
        .out_sof    (lane_sof)
    );

    dp_tx_phy_7series phy (
        .clk       (clk),
        .rst_n     (rst_n),
        .tx_data   (lane_data),
        .tx_k_mask (lane_k_mask),
        .tx_valid  (lane_valid),
        .tx_sof    (lane_sof),
        .tx_code0  (tx_code0),
        .tx_code1  (tx_code1),
        .tx_code2  (tx_code2),
        .tx_code3  (tx_code3),
        .txp       (txp),
        .txn       (txn)
    );
endmodule
