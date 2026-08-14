module dp_tx_8b10b_enc (
    input  wire [7:0]  data_in,
    input  wire        is_k,
    input  wire        disp_in,
    output reg  [9:0]  code_out,
    output reg         disp_out
);

    wire [4:0] abcde = data_in[4:0];
    wire [2:0] fgh   = data_in[7:5];

    reg [5:0] six;
    reg [3:0] four;

    reg [2:0] cnt6, cnt4;

    always @(*) begin
        six = 6'b0;
        four = 4'b0;

        if (is_k) begin
            case ({fgh, abcde})
                8'b101_11100: begin six = disp_in ? 6'b001111 : 6'b110000; four = disp_in ? 4'b1010 : 4'b0101; end  // K28.5
                8'b000_11100: begin six = disp_in ? 6'b001111 : 6'b110000; four = disp_in ? 4'b1010 : 4'b0101; end  // K28.0
                8'b100_11100: begin six = disp_in ? 6'b001111 : 6'b110000; four = disp_in ? 4'b1100 : 4'b0011; end  // K28.4
                8'b001_11100: begin six = disp_in ? 6'b001111 : 6'b110000; four = disp_in ? 4'b1001 : 4'b0110; end  // K28.1
                8'b010_11100: begin six = disp_in ? 6'b001111 : 6'b110000; four = disp_in ? 4'b0101 : 4'b1010; end  // K28.2
                8'b110_11100: begin six = disp_in ? 6'b001111 : 6'b110000; four = disp_in ? 4'b1100 : 4'b0011; end  // K28.6
                8'b011_11100: begin six = disp_in ? 6'b001111 : 6'b110000; four = disp_in ? 4'b1100 : 4'b0011; end  // K28.3
                8'b111_11100: begin six = disp_in ? 6'b001111 : 6'b110000; four = disp_in ? 4'b0101 : 4'b1010; end  // K28.7
                8'b000_11011: begin six = disp_in ? 6'b001110 : 6'b110001; four = 4'b1001; end
                8'b001_11011: begin six = disp_in ? 6'b001110 : 6'b110001; four = 4'b0101; end
                8'b010_11011: begin six = disp_in ? 6'b001110 : 6'b110001; four = 4'b1100; end
                8'b011_11011: begin six = disp_in ? 6'b001110 : 6'b110001; four = 4'b0011; end
                8'b100_11011: begin six = disp_in ? 6'b001110 : 6'b110001; four = 4'b1010; end
                8'b101_11011: begin six = disp_in ? 6'b001110 : 6'b110001; four = 4'b0110; end
                8'b110_11011: begin six = disp_in ? 6'b001110 : 6'b110001; four = 4'b0101; end
                8'b111_11011: begin six = disp_in ? 6'b001110 : 6'b110001; four = disp_in ? 4'b1001 : 4'b0110; end
                default: begin six = 6'b0; four = 4'b0; end
            endcase
        end else begin
            case (abcde)
                5'd0:  six = disp_in ? 6'b011000 : 6'b100111;
                5'd1:  six = disp_in ? 6'b100010 : 6'b011101;
                5'd2:  six = disp_in ? 6'b010010 : 6'b101101;
                5'd3:  six = 6'b110001;
                5'd4:  six = disp_in ? 6'b001010 : 6'b110101;
                5'd5:  six = 6'b101001;
                5'd6:  six = 6'b011001;
                5'd7:  six = disp_in ? 6'b000111 : 6'b111000;
                5'd8:  six = disp_in ? 6'b000110 : 6'b111001;
                5'd9:  six = 6'b100101;
                5'd10: six = 6'b010101;
                5'd11: six = 6'b110100;
                5'd12: six = 6'b001101;
                5'd13: six = 6'b101100;
                5'd14: six = 6'b011100;
                5'd15: six = disp_in ? 6'b101000 : 6'b010111;
                5'd16: six = disp_in ? 6'b100100 : 6'b011011;
                5'd17: six = 6'b100011;
                5'd18: six = 6'b010011;
                5'd19: six = 6'b110010;
                5'd20: six = 6'b001011;
                5'd21: six = 6'b101010;
                5'd22: six = 6'b011010;
                5'd23: six = disp_in ? 6'b000101 : 6'b111010;
                5'd24: six = disp_in ? 6'b001100 : 6'b110011;
                5'd25: six = 6'b100110;
                5'd26: six = 6'b010110;
                5'd27: six = disp_in ? 6'b001001 : 6'b110110;
                5'd28: six = 6'b001110;
                5'd29: six = 6'b010001;
                5'd30: six = 6'b100001;
                5'd31: six = disp_in ? 6'b101000 : 6'b010111;
            endcase

            case (fgh)
                3'd0: four = disp_in ? 4'b0100 : 4'b1011;
                3'd1: four = 4'b1001;
                3'd2: four = 4'b0101;
                3'd3: four = disp_in ? 4'b0011 : 4'b1100;
                3'd4: four = disp_in ? 4'b0010 : 4'b1101;
                3'd5: four = 4'b1010;
                3'd6: four = 4'b0110;
                3'd7: four = disp_in ? 4'b0001 : 4'b1110;
            endcase
        end

        code_out = {four, six};
        cnt6 = {3'd0, six[0]} + {3'd0, six[1]} + {3'd0, six[2]}
             + {3'd0, six[3]} + {3'd0, six[4]} + {3'd0, six[5]};
        cnt4 = {3'd0, four[0]} + {3'd0, four[1]} + {3'd0, four[2]} + {3'd0, four[3]};
        if (cnt6 > 3'd3)
            disp_out = 1'b1;
        else if (cnt6 < 3'd3)
            disp_out = 1'b0;
        else if (cnt4 > 3'd2)
            disp_out = 1'b1;
        else if (cnt4 < 3'd2)
            disp_out = 1'b0;
        else
            disp_out = disp_in;
    end

endmodule
