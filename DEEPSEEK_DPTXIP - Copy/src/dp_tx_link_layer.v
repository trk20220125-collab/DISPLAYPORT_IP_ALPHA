module dp_tx_link_layer (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [23:0] pixel_in,
    input  wire        pixel_valid,
    input  wire        pixel_sof,
    output wire [7:0]  link_byte,
    output wire        link_valid,
    output wire        link_sof
);

    wire [7:0] packed_byte;
    wire       packed_valid;
    wire       packed_sof;
    wire [7:0] scrambled_byte;
    wire       scrambled_valid;

    reg [7:0] msa_table [0:7];
    reg [3:0] msa_index;
    reg       msa_active;

    reg [7:0] link_byte_r;
    reg       link_valid_r;
    reg       link_sof_r;

    dp_tx_video_packer packer (
        .clk        (clk),
        .rst_n      (rst_n),
        .pixel_in   (pixel_in),
        .pixel_valid(pixel_valid),
        .pixel_sof  (pixel_sof),
        .byte_out   (packed_byte),
        .byte_valid (packed_valid),
        .byte_sof   (packed_sof)
    );

    dp_tx_scrambler scrambler (
        .clk          (clk),
        .rst_n        (rst_n),
        .data_in      (packed_byte),
        .data_valid   (packed_valid),
        .data_out     (scrambled_byte),
        .data_out_valid(scrambled_valid)
    );

    initial begin
        msa_table[0] = 8'hBC;
        msa_table[1] = 8'h5A;
        msa_table[2] = 8'h01;
        msa_table[3] = 8'h02;
        msa_table[4] = 8'h03;
        msa_table[5] = 8'h04;
        msa_table[6] = 8'h05;
        msa_table[7] = 8'h06;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            msa_index   <= 4'd0;
            msa_active  <= 1'b1;
            link_byte_r <= 8'h00;
            link_valid_r <= 1'b0;
            link_sof_r   <= 1'b0;
        end else begin
            link_valid_r <= 1'b0;
            link_sof_r   <= 1'b0;

            if (msa_active) begin
                link_byte_r  <= msa_table[msa_index];
                link_valid_r <= 1'b1;
                link_sof_r   <= (msa_index == 4'd0);

                if (msa_index == 4'd7) begin
                    msa_active <= 1'b0;
                    msa_index  <= 4'd0;
                end else begin
                    msa_index <= msa_index + 1'b1;
                end
            end else if (scrambled_valid) begin
                link_byte_r  <= scrambled_byte;
                link_valid_r <= 1'b1;
                link_sof_r   <= packed_sof;
            end
        end
    end

    assign link_byte  = link_byte_r;
    assign link_valid = link_valid_r;
    assign link_sof   = link_sof_r;
endmodule
