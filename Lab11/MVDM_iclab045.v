module MVDM(
    // input signals
    clk,
    rst_n,
    in_valid, 
    in_valid2,
    in_data,
    // output signals
    out_valid,
    out_sad
    );

input clk;
input rst_n;
input in_valid;
input in_valid2;
input [11:0] in_data;

output reg out_valid;
output reg out_sad;
//=======================================================
//                   Reg/Wire
//=======================================================
wire[13:0] A[1:0];
wire[7:0] Dout[1:0], Din;
wire[1:0] WEB;
wire[3:0]frac_out[1:0][1:0];
reg[7:0] Dout_reg[1:0], calc_reg[1:0][1:0][1:0];
reg[13:0] img_cnt, img_addr[1:0], next_img_addr[1:0];
reg[2:0] in_mv_cnt;
reg[1:0] BI_two_cnt;
reg[5:0] move_pat_cnt, spot_cnt;
reg[6:0] BI_sum_cnt, BI_wrt_idx;
reg cnt;
reg pt_cnt, pt2_cnt;
genvar i,j;
reg[11:0] mv_int_frac[8:1];
reg[17:0] BI[99:0], BI_reg[1:0];
reg[17:0] A1[1:0], A2[1:0];
reg[23:0] sad[8:0];
reg[23:0] min_sad_reg[3:1];
wire[23:0] min_sad[3:0];
reg[3:0] min_sad_idx_reg[3:1];
wire[3:0] min_sad_idx[3:0];
reg[27:0] output_reg;
reg[5:0] output_cnt;
reg output_flip_cnt;
reg[6:0] BI0_A;
wire[17:0] BI0_DOA = 18'bz;
reg[17:0] BI0_DIA;
reg BI0_WEN_A;
wire[6:0] BI0_B = BI_sum_cnt;
wire[17:0] BI0_DOB;
wire[17:0] BI0_DIB = 18'bz;
wire BI0_WEN_B = 1;
reg[17:0] BI0_DOB_reg;
reg[8:0] BI_compare;
reg[17:0] sad_sel[8:0];
//=======================================================
//                   Design
//=======================================================
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        BI0_WEN_A <= 1;
        BI0_DIA <= 18'b0;
        BI0_A <= 7'b0;
    end else begin
        BI0_WEN_A <= (BI_wrt_idx == 7'd100);
        BI0_DIA <= BI_reg[0];
        BI0_A <= BI_wrt_idx;
    end
end
assign A[0] = (in_valid)? img_cnt:img_addr[0];
assign A[1] = (in_valid)? img_cnt:img_addr[1];
assign Din = in_data[11:4];
assign WEB[0] = !in_valid |  cnt;
assign WEB[1] = !in_valid | !cnt;
always @(*) begin
    if(pt_cnt && output_cnt != 6'd56)begin
        out_valid = 1;
        out_sad = (output_flip_cnt)? output_reg[output_cnt - 5'd28]:output_reg[output_cnt];
    end else begin
        out_valid = 0;
        out_sad = 0;
    end
end
always @(posedge clk) begin
    if(in_valid2)
        output_flip_cnt <= 0;
    else if(output_cnt == 6'd27)
        output_flip_cnt <= 1;
    else
        output_flip_cnt <= output_flip_cnt;
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        output_cnt <= 6'd56;
    else if(in_valid)
        output_cnt <= 6'd56;
    else if(pt_cnt && pt2_cnt && BI_sum_cnt == 7'd75)
        output_cnt <= 6'b0;
    else if(output_cnt != 6'd56)
        output_cnt <= output_cnt + 1'b1;
    else
        output_cnt <= output_cnt;
end
always @(posedge clk) begin
    Dout_reg[0] <= Dout[0];
    Dout_reg[1] <= Dout[1];
    BI0_DOB_reg <= BI0_DOB;
end
always @(posedge clk) begin
    if(in_valid)
        img_cnt <= img_cnt + 1'b1;
    else
        img_cnt <= 8'b0;
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        in_mv_cnt <= 3'b0;
    else if(in_valid2)
        in_mv_cnt <= in_mv_cnt + 1'b1;
    else
        in_mv_cnt <= 3'b0;
end
always @(posedge clk) begin
    if(!in_valid)
        cnt <= 0;
    else if(&img_cnt)
        cnt <= 1;
    else
        cnt <= cnt;
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        pt_cnt <= 0;
    else if(in_valid2 | in_valid)
        pt_cnt <= 0;
    else if(BI_wrt_idx == 7'd99)//todo optimized
        pt_cnt <= 1;
    else
        pt_cnt <= pt_cnt;
end
always @(posedge clk) begin
    if(!pt_cnt)
        pt2_cnt <= 0;
    else if(pt_cnt && BI_wrt_idx[4])//todo optimized
        pt2_cnt <= 1;
    else
        pt2_cnt <= pt2_cnt;
end
always @(posedge clk) begin
    if(in_valid2)
        mv_int_frac[8] <= in_data;
    else
        mv_int_frac[8] <= mv_int_frac[8];
end
generate
    for(i = 1; i < 8; i = i + 1)begin
        always @(posedge clk) begin
            if(in_valid2)
                mv_int_frac[i] <= mv_int_frac[i+1];
            else
                mv_int_frac[i] <= mv_int_frac[i];
        end
    end
endgenerate
generate
    for(i = 0; i < 100; i = i + 1)begin
        always @(posedge clk) begin
            if(i == BI_wrt_idx)begin
                BI[i] <= BI_reg[1];
            end else begin
                BI[i] <= BI[i];
            end
        end
    end
endgenerate
assign frac_out[0][0] = (pt_cnt)? mv_int_frac[5][3:0]:mv_int_frac[1][3:0];
assign frac_out[0][1] = (pt_cnt)? mv_int_frac[6][3:0]:mv_int_frac[2][3:0];
assign frac_out[1][0] = (pt_cnt)? mv_int_frac[7][3:0]:mv_int_frac[3][3:0];
assign frac_out[1][1] = (pt_cnt)? mv_int_frac[8][3:0]:mv_int_frac[4][3:0];
always @(posedge clk) begin
    if(calc_reg[0][0][1] < calc_reg[0][0][0])begin
        A1[0] <= {calc_reg[0][0][0], 4'b0} - (frac_out[0][0]*(calc_reg[0][0][0] - calc_reg[0][0][1]));
    end else begin
        A1[0] <= {calc_reg[0][0][0], 4'b0} + (frac_out[0][0]*(calc_reg[0][0][1] - calc_reg[0][0][0]));
    end
end
always @(posedge clk) begin
    if(calc_reg[1][0][1] < calc_reg[1][0][0])begin
        A1[1] <= {calc_reg[1][0][0], 4'b0} - (frac_out[1][0]*(calc_reg[1][0][0] - calc_reg[1][0][1]));
    end else begin
        A1[1] <= {calc_reg[1][0][0], 4'b0} + (frac_out[1][0]*(calc_reg[1][0][1] - calc_reg[1][0][0]));
    end
end
always @(posedge clk) begin
    if(calc_reg[0][1][1] < calc_reg[0][1][0])begin
        A2[0] <= {calc_reg[0][1][0], 4'b0} - (frac_out[0][0]*(calc_reg[0][1][0] - calc_reg[0][1][1]));
    end else begin
        A2[0] <= {calc_reg[0][1][0], 4'b0} + (frac_out[0][0]*(calc_reg[0][1][1] - calc_reg[0][1][0]));
    end
end
always @(posedge clk) begin
    if(calc_reg[1][1][1] < calc_reg[1][1][0])begin
        A2[1] <= {calc_reg[1][1][0], 4'b0} - (frac_out[1][0]*(calc_reg[1][1][0] - calc_reg[1][1][1]));
    end else begin
        A2[1] <= {calc_reg[1][1][0], 4'b0} + (frac_out[1][0]*(calc_reg[1][1][1] - calc_reg[1][1][0]));
    end
end
always @(posedge clk) begin
    if(A2[0] < A1[0])begin
        BI_reg[0] <= {A1[0], 4'b0} - frac_out[0][1]*(A1[0] - A2[0]);
    end else begin
        BI_reg[0] <= {A1[0], 4'b0} + frac_out[0][1]*(A2[0] - A1[0]);
    end
end
always @(posedge clk) begin
    if(A2[1] < A1[1])begin
        BI_reg[1] <= {A1[1], 4'b0} - frac_out[1][1]*(A1[1] - A2[1]);
    end else begin
        BI_reg[1] <= {A1[1], 4'b0} + frac_out[1][1]*(A2[1] - A1[1]);
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        img_addr[0] <= 14'b0;
        img_addr[1] <= 14'b0;
    end else if(in_mv_cnt == 3'd3)begin
        img_addr[0] <= mv_int_frac[6][11:4] + (mv_int_frac[7][11:4] << 7);
        img_addr[1] <= mv_int_frac[8][11:4] + (in_data[11:4] << 7);
    end else if(pt_cnt && BI_sum_cnt == 7'd75)begin // todo: opt
        img_addr[0] <= mv_int_frac[5][11:4] + (mv_int_frac[6][11:4] << 7);
        img_addr[1] <= mv_int_frac[7][11:4] + (mv_int_frac[8][11:4] << 7);
    end else
        {img_addr[0], img_addr[1]} <= {next_img_addr[0], next_img_addr[1]};
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        move_pat_cnt <= 6'b0;
    else if(in_mv_cnt == 3'd3)
        move_pat_cnt <= 6'b0;
    else if(pt_cnt && BI_sum_cnt == 7'd75) // todo: opt
        move_pat_cnt <= 6'b0;
    else if(move_pat_cnt == 6'd42)
        move_pat_cnt <= 6'd3;
    else
        move_pat_cnt <= move_pat_cnt + 6'b1;
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        spot_cnt <= 6'd44;
    else if(move_pat_cnt == 6'b1)
        spot_cnt <= 6'b0;
    else if(spot_cnt == 6'd43)
        spot_cnt <= 6'd4;
    else
        spot_cnt <= spot_cnt + 6'b1;
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        BI_two_cnt <= 2'd3;
    else if(move_pat_cnt == 6'd5 && spot_cnt == 6'd3)
        BI_two_cnt <= 2'd3;
    else if(BI_two_cnt == 2'd1)
        BI_two_cnt <= 2'b0;
    else
        BI_two_cnt <= BI_two_cnt + 1'b1;
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        BI_wrt_idx <= 7'b100;
    else if(move_pat_cnt == 6'd5 && spot_cnt == 6'd3)
        BI_wrt_idx <= 7'b0;
    else if(BI_two_cnt == 2'd1 && BI_wrt_idx != 7'd100)
        BI_wrt_idx <= BI_wrt_idx + 1'b1;
    else
        BI_wrt_idx <= BI_wrt_idx;
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        BI_sum_cnt <= 7'd104;
    else if(BI_wrt_idx == 7'd61)
        BI_sum_cnt <= 0;
    else if(BI_sum_cnt != 7'd104)
        BI_sum_cnt <= BI_sum_cnt + 1'b1;
    else
        BI_sum_cnt <= BI_sum_cnt;
end
find_min m1(.sad1(sad[0]), .sad2(sad[1]), .sad3(sad[2]), .idx1(4'd0), .idx2(4'd1), .idx3(4'd2),
            .min_sad(min_sad[1]), .min_idx(min_sad_idx[1]));
find_min m2(.sad1(sad[3]), .sad2(sad[4]), .sad3(sad[5]), .idx1(4'd3), .idx2(4'd4), .idx3(4'd5),
            .min_sad(min_sad[2]), .min_idx(min_sad_idx[2]));
find_min m3(.sad1(sad[6]), .sad2(sad[7]), .sad3(sad[8]), .idx1(4'd6), .idx2(4'd7), .idx3(4'd8),
            .min_sad(min_sad[3]), .min_idx(min_sad_idx[3]));
find_min m4(.sad1(min_sad_reg[1]), .sad2(min_sad_reg[2]), .sad3(min_sad_reg[3]), .idx1(min_sad_idx_reg[1]), 
            .idx2(min_sad_idx_reg[2]), .idx3(min_sad_idx_reg[3]), .min_sad(min_sad[0]), .min_idx(min_sad_idx[0]));
generate
    for(i = 1;i < 4;i = i + 1)begin
        always @(posedge clk) begin
            min_sad_reg[i] <= min_sad[i];
            min_sad_idx_reg[i] <= min_sad_idx[i];
        end
    end
endgenerate
always @(posedge clk) begin
    if(BI_sum_cnt == 7'd103) // todo
        output_reg <= {min_sad_idx[0], min_sad[0]}; // output_reg <= {min_sad_idx[0], min_sad[0], output_reg[55:28]};
    else
        output_reg <= output_reg;
end
always @(posedge clk) begin
    case (spot_cnt)
        6'd0: {calc_reg[0][0][0], calc_reg[1][0][0]} <= {Dout_reg[0], Dout_reg[1]};
        4, 6, 8, 10, 12, 14, 16, 18, 20: {calc_reg[0][0][0], calc_reg[1][0][0]} <= {calc_reg[0][0][1], calc_reg[1][0][1]};
        22, 42:{calc_reg[0][0][0], calc_reg[1][0][0]} <= {calc_reg[0][1][0], calc_reg[1][1][0]};
        24, 26, 28, 30, 32, 34, 36, 38, 40:{calc_reg[0][0][0], calc_reg[1][0][0]} <= {Dout_reg[0], Dout_reg[1]};
        default:{calc_reg[0][0][0], calc_reg[1][0][0]} <= {calc_reg[0][0][0], calc_reg[1][0][0]};
    endcase
end
always @(posedge clk) begin
    case (spot_cnt)
        2, 4, 6, 8, 10, 12, 14, 16, 18, 20: {calc_reg[0][0][1], calc_reg[1][0][1]} <= {Dout_reg[0], Dout_reg[1]};
        22, 42:{calc_reg[0][0][1], calc_reg[1][0][1]} <= {calc_reg[0][1][1], calc_reg[1][1][1]};
        24, 26, 28, 30, 32, 34, 36, 38, 40:{calc_reg[0][0][1], calc_reg[1][0][1]} <= {calc_reg[0][0][0], calc_reg[1][0][0]};
        default:{calc_reg[0][0][1], calc_reg[1][0][1]} <= {calc_reg[0][0][1], calc_reg[1][0][1]};
    endcase
end
always @(posedge clk) begin
    case (spot_cnt)
        1, 23, 25, 27, 29, 31, 33, 35, 37, 39, 41, 42:{calc_reg[0][1][0], calc_reg[1][1][0]} <= {Dout_reg[0], Dout_reg[1]};
        4, 6, 8, 10, 12, 14, 16, 18, 20: {calc_reg[0][1][0], calc_reg[1][1][0]} <= {calc_reg[0][1][1], calc_reg[1][1][1]};
        default:{calc_reg[0][1][0], calc_reg[1][1][0]} <= {calc_reg[0][1][0], calc_reg[1][1][0]};
    endcase
end
always @(posedge clk) begin
    case (spot_cnt)
        3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 22, 43: {calc_reg[0][1][1], calc_reg[1][1][1]} <= {Dout_reg[0], Dout_reg[1]};
        24, 26, 28, 30, 32, 34, 36, 38, 40, 43:{calc_reg[0][1][1], calc_reg[1][1][1]} <= {calc_reg[0][1][0], calc_reg[1][1][0]};
        default:{calc_reg[0][1][1], calc_reg[1][1][1]} <= {calc_reg[0][1][1], calc_reg[1][1][1]};
    endcase
end
always @(*) begin
    case(move_pat_cnt) //synopsys parallel_case
        6'd22:{next_img_addr[0], next_img_addr[1]} = {img_addr[0] - 1'b1, img_addr[1] - 1'b1};
        6'd42:{next_img_addr[0], next_img_addr[1]} = {img_addr[0] + 1'b1, img_addr[1] + 1'b1};
        1, 3, 5, 7, 9, 11, 13, 15, 17, 19: {next_img_addr[0], next_img_addr[1]} = {img_addr[0] - 8'd127, img_addr[1] - 8'd127};
        23, 25, 27, 29, 31, 33, 35, 37, 39:{next_img_addr[0], next_img_addr[1]} = {img_addr[0] - 8'd129, img_addr[1] - 8'd129};
        default:{next_img_addr[0], next_img_addr[1]} = {img_addr[0] + 8'd128, img_addr[1] + 8'd128};
    endcase
end
always @(*) begin
    case (BI_sum_cnt)
        7'd2: sad_sel[0] = BI[22];
        7'd3: sad_sel[0] = BI[23];
        7'd4: sad_sel[0] = BI[24];
        7'd5: sad_sel[0] = BI[25];
        7'd6: sad_sel[0] = BI[26];
        7'd7: sad_sel[0] = BI[27];
        7'd8: sad_sel[0] = BI[28];
        7'd9: sad_sel[0] = BI[29];
        7'd21: sad_sel[0] = BI[37];
        7'd20: sad_sel[0] = BI[36];
        7'd19: sad_sel[0] = BI[35];
        7'd18: sad_sel[0] = BI[34];
        7'd17: sad_sel[0] = BI[33];
        7'd16: sad_sel[0] = BI[32];
        7'd15: sad_sel[0] = BI[31];
        7'd14: sad_sel[0] = BI[30];
        7'd22: sad_sel[0] = BI[42];
        7'd23: sad_sel[0] = BI[43];
        7'd24: sad_sel[0] = BI[44];
        7'd25: sad_sel[0] = BI[45];
        7'd26: sad_sel[0] = BI[46];
        7'd27: sad_sel[0] = BI[47];
        7'd28: sad_sel[0] = BI[48];
        7'd29: sad_sel[0] = BI[49];
        7'd41: sad_sel[0] = BI[57];
        7'd40: sad_sel[0] = BI[56];
        7'd39: sad_sel[0] = BI[55];
        7'd38: sad_sel[0] = BI[54];
        7'd37: sad_sel[0] = BI[53];
        7'd36: sad_sel[0] = BI[52];
        7'd35: sad_sel[0] = BI[51];
        7'd34: sad_sel[0] = BI[50];
        7'd42: sad_sel[0] = BI[62];
        7'd43: sad_sel[0] = BI[63];
        7'd44: sad_sel[0] = BI[64];
        7'd45: sad_sel[0] = BI[65];
        7'd46: sad_sel[0] = BI[66];
        7'd47: sad_sel[0] = BI[67];
        7'd48: sad_sel[0] = BI[68];
        7'd49: sad_sel[0] = BI[69];
        7'd61: sad_sel[0] = BI[77];
        7'd60: sad_sel[0] = BI[76];
        7'd59: sad_sel[0] = BI[75];
        7'd58: sad_sel[0] = BI[74];
        7'd57: sad_sel[0] = BI[73];
        7'd56: sad_sel[0] = BI[72];
        7'd55: sad_sel[0] = BI[71];
        7'd54: sad_sel[0] = BI[70];
        7'd62: sad_sel[0] = BI[82];
        7'd63: sad_sel[0] = BI[83];
        7'd64: sad_sel[0] = BI[84];
        7'd65: sad_sel[0] = BI[85];
        7'd66: sad_sel[0] = BI[86];
        7'd67: sad_sel[0] = BI[87];
        7'd68: sad_sel[0] = BI[88];
        7'd69: sad_sel[0] = BI[89];
        7'd81: sad_sel[0] = BI[97];
        7'd80: sad_sel[0] = BI[96];
        7'd79: sad_sel[0] = BI[95];
        7'd78: sad_sel[0] = BI[94];
        7'd77: sad_sel[0] = BI[93];
        7'd76: sad_sel[0] = BI[92];
        7'd75: sad_sel[0] = BI[91];
        7'd74: sad_sel[0] = BI[90];
        default: sad_sel[0] = BI0_DOB_reg;
    endcase
end
always @(*) begin
    case (BI_sum_cnt)
        7'd21: sad_sel[1] = BI[17];
        7'd20: sad_sel[1] = BI[16];
        7'd19: sad_sel[1] = BI[15];
        7'd18: sad_sel[1] = BI[14];
        7'd17: sad_sel[1] = BI[13];
        7'd16: sad_sel[1] = BI[12];
        7'd15: sad_sel[1] = BI[11];
        7'd14: sad_sel[1] = BI[10];
        7'd22: sad_sel[1] = BI[22];
        7'd23: sad_sel[1] = BI[23];
        7'd24: sad_sel[1] = BI[24];
        7'd25: sad_sel[1] = BI[25];
        7'd26: sad_sel[1] = BI[26];
        7'd27: sad_sel[1] = BI[27];
        7'd28: sad_sel[1] = BI[28];
        7'd29: sad_sel[1] = BI[29];
        7'd41: sad_sel[1] = BI[37];
        7'd40: sad_sel[1] = BI[36];
        7'd39: sad_sel[1] = BI[35];
        7'd38: sad_sel[1] = BI[34];
        7'd37: sad_sel[1] = BI[33];
        7'd36: sad_sel[1] = BI[32];
        7'd35: sad_sel[1] = BI[31];
        7'd34: sad_sel[1] = BI[30];
        7'd42: sad_sel[1] = BI[42];
        7'd43: sad_sel[1] = BI[43];
        7'd44: sad_sel[1] = BI[44];
        7'd45: sad_sel[1] = BI[45];
        7'd46: sad_sel[1] = BI[46];
        7'd47: sad_sel[1] = BI[47];
        7'd48: sad_sel[1] = BI[48];
        7'd49: sad_sel[1] = BI[49];
        7'd61: sad_sel[1] = BI[57];
        7'd60: sad_sel[1] = BI[56];
        7'd59: sad_sel[1] = BI[55];
        7'd58: sad_sel[1] = BI[54];
        7'd57: sad_sel[1] = BI[53];
        7'd56: sad_sel[1] = BI[52];
        7'd55: sad_sel[1] = BI[51];
        7'd54: sad_sel[1] = BI[50];
        7'd62: sad_sel[1] = BI[62];
        7'd63: sad_sel[1] = BI[63];
        7'd64: sad_sel[1] = BI[64];
        7'd65: sad_sel[1] = BI[65];
        7'd66: sad_sel[1] = BI[66];
        7'd67: sad_sel[1] = BI[67];
        7'd68: sad_sel[1] = BI[68];
        7'd69: sad_sel[1] = BI[69];
        7'd81: sad_sel[1] = BI[77];
        7'd80: sad_sel[1] = BI[76];
        7'd79: sad_sel[1] = BI[75];
        7'd78: sad_sel[1] = BI[74];
        7'd77: sad_sel[1] = BI[73];
        7'd76: sad_sel[1] = BI[72];
        7'd75: sad_sel[1] = BI[71];
        7'd74: sad_sel[1] = BI[70];
        7'd82: sad_sel[1] = BI[82];
        7'd83: sad_sel[1] = BI[83];
        7'd84: sad_sel[1] = BI[84];
        7'd85: sad_sel[1] = BI[85];
        7'd86: sad_sel[1] = BI[86];
        7'd87: sad_sel[1] = BI[87];
        7'd88: sad_sel[1] = BI[88];
        7'd89: sad_sel[1] = BI[89];
        default: sad_sel[1] = BI0_DOB_reg;
    endcase
end
always @(*) begin
    case (BI_sum_cnt)
        7'd22: sad_sel[2] = BI[2];
        7'd23: sad_sel[2] = BI[3];
        7'd24: sad_sel[2] = BI[4];
        7'd25: sad_sel[2] = BI[5];
        7'd26: sad_sel[2] = BI[6];
        7'd27: sad_sel[2] = BI[7];
        7'd28: sad_sel[2] = BI[8];
        7'd29: sad_sel[2] = BI[9];
        7'd41: sad_sel[2] = BI[17];
        7'd40: sad_sel[2] = BI[16];
        7'd39: sad_sel[2] = BI[15];
        7'd38: sad_sel[2] = BI[14];
        7'd37: sad_sel[2] = BI[13];
        7'd36: sad_sel[2] = BI[12];
        7'd35: sad_sel[2] = BI[11];
        7'd34: sad_sel[2] = BI[10];
        7'd42: sad_sel[2] = BI[22];
        7'd43: sad_sel[2] = BI[23];
        7'd44: sad_sel[2] = BI[24];
        7'd45: sad_sel[2] = BI[25];
        7'd46: sad_sel[2] = BI[26];
        7'd47: sad_sel[2] = BI[27];
        7'd48: sad_sel[2] = BI[28];
        7'd49: sad_sel[2] = BI[29];
        7'd61: sad_sel[2] = BI[37];
        7'd60: sad_sel[2] = BI[36];
        7'd59: sad_sel[2] = BI[35];
        7'd58: sad_sel[2] = BI[34];
        7'd57: sad_sel[2] = BI[33];
        7'd56: sad_sel[2] = BI[32];
        7'd55: sad_sel[2] = BI[31];
        7'd54: sad_sel[2] = BI[30];
        7'd62: sad_sel[2] = BI[42];
        7'd63: sad_sel[2] = BI[43];
        7'd64: sad_sel[2] = BI[44];
        7'd65: sad_sel[2] = BI[45];
        7'd66: sad_sel[2] = BI[46];
        7'd67: sad_sel[2] = BI[47];
        7'd68: sad_sel[2] = BI[48];
        7'd69: sad_sel[2] = BI[49];
        7'd81: sad_sel[2] = BI[57];
        7'd80: sad_sel[2] = BI[56];
        7'd79: sad_sel[2] = BI[55];
        7'd78: sad_sel[2] = BI[54];
        7'd77: sad_sel[2] = BI[53];
        7'd76: sad_sel[2] = BI[52];
        7'd75: sad_sel[2] = BI[51];
        7'd74: sad_sel[2] = BI[50];
        7'd82: sad_sel[2] = BI[62];
        7'd83: sad_sel[2] = BI[63];
        7'd84: sad_sel[2] = BI[64];
        7'd85: sad_sel[2] = BI[65];
        7'd86: sad_sel[2] = BI[66];
        7'd87: sad_sel[2] = BI[67];
        7'd88: sad_sel[2] = BI[68];
        7'd89: sad_sel[2] = BI[69];
        7'd101:sad_sel[2] = BI[77];
        7'd100:sad_sel[2] = BI[76];
        7'd99: sad_sel[2] = BI[75];
        7'd98: sad_sel[2] = BI[74];
        7'd97: sad_sel[2] = BI[73];
        7'd96: sad_sel[2] = BI[72];
        7'd95: sad_sel[2] = BI[71];
        7'd94: sad_sel[2] = BI[70];
        default: sad_sel[2] = BI0_DOB_reg;
    endcase
end
always @(*) begin
    case (BI_sum_cnt)
        7'd3: sad_sel[3] = BI[21];
        7'd4: sad_sel[3] = BI[22];
        7'd5: sad_sel[3] = BI[23];
        7'd6: sad_sel[3] = BI[24];
        7'd7: sad_sel[3] = BI[25];
        7'd8: sad_sel[3] = BI[26];
        7'd9: sad_sel[3] = BI[27];
        7'd10: sad_sel[3] = BI[28];
        7'd20: sad_sel[3] = BI[38];
        7'd19: sad_sel[3] = BI[37];
        7'd18: sad_sel[3] = BI[36];
        7'd17: sad_sel[3] = BI[35];
        7'd16: sad_sel[3] = BI[34];
        7'd15: sad_sel[3] = BI[33];
        7'd14: sad_sel[3] = BI[32];
        7'd13: sad_sel[3] = BI[31];
        7'd23: sad_sel[3] = BI[41];
        7'd24: sad_sel[3] = BI[42];
        7'd25: sad_sel[3] = BI[43];
        7'd26: sad_sel[3] = BI[44];
        7'd27: sad_sel[3] = BI[45];
        7'd28: sad_sel[3] = BI[46];
        7'd29: sad_sel[3] = BI[47];
        7'd30: sad_sel[3] = BI[48];
        7'd40: sad_sel[3] = BI[58];
        7'd39: sad_sel[3] = BI[57];
        7'd38: sad_sel[3] = BI[56];
        7'd37: sad_sel[3] = BI[55];
        7'd36: sad_sel[3] = BI[54];
        7'd35: sad_sel[3] = BI[53];
        7'd34: sad_sel[3] = BI[52];
        7'd33: sad_sel[3] = BI[51];
        7'd43: sad_sel[3] = BI[61];
        7'd44: sad_sel[3] = BI[62];
        7'd45: sad_sel[3] = BI[63];
        7'd46: sad_sel[3] = BI[64];
        7'd47: sad_sel[3] = BI[65];
        7'd48: sad_sel[3] = BI[66];
        7'd49: sad_sel[3] = BI[67];
        7'd50: sad_sel[3] = BI[68];
        7'd60: sad_sel[3] = BI[78];
        7'd59: sad_sel[3] = BI[77];
        7'd58: sad_sel[3] = BI[76];
        7'd57: sad_sel[3] = BI[75];
        7'd56: sad_sel[3] = BI[74];
        7'd55: sad_sel[3] = BI[73];
        7'd54: sad_sel[3] = BI[72];
        7'd53: sad_sel[3] = BI[71];
        7'd63: sad_sel[3] = BI[81];
        7'd64: sad_sel[3] = BI[82];
        7'd65: sad_sel[3] = BI[83];
        7'd66: sad_sel[3] = BI[84];
        7'd67: sad_sel[3] = BI[85];
        7'd68: sad_sel[3] = BI[86];
        7'd69: sad_sel[3] = BI[87];
        7'd70: sad_sel[3] = BI[88];
        7'd80: sad_sel[3] = BI[98];
        7'd79: sad_sel[3] = BI[97];
        7'd78: sad_sel[3] = BI[96];
        7'd77: sad_sel[3] = BI[95];
        7'd76: sad_sel[3] = BI[94];
        7'd75: sad_sel[3] = BI[93];
        7'd74: sad_sel[3] = BI[92];
        7'd73: sad_sel[3] = BI[91];
        default: sad_sel[3] = BI0_DOB_reg;
    endcase
end
always @(*) begin
    case (BI_sum_cnt)
        7'd20: sad_sel[4] = BI[18];
        7'd19: sad_sel[4] = BI[17];
        7'd18: sad_sel[4] = BI[16];
        7'd17: sad_sel[4] = BI[15];
        7'd16: sad_sel[4] = BI[14];
        7'd15: sad_sel[4] = BI[13];
        7'd14: sad_sel[4] = BI[12];
        7'd13: sad_sel[4] = BI[11];
        7'd23: sad_sel[4] = BI[21];
        7'd24: sad_sel[4] = BI[22];
        7'd25: sad_sel[4] = BI[23];
        7'd26: sad_sel[4] = BI[24];
        7'd27: sad_sel[4] = BI[25];
        7'd28: sad_sel[4] = BI[26];
        7'd29: sad_sel[4] = BI[27];
        7'd30: sad_sel[4] = BI[28];
        7'd40: sad_sel[4] = BI[38];
        7'd39: sad_sel[4] = BI[37];
        7'd38: sad_sel[4] = BI[36];
        7'd37: sad_sel[4] = BI[35];
        7'd36: sad_sel[4] = BI[34];
        7'd35: sad_sel[4] = BI[33];
        7'd34: sad_sel[4] = BI[32];
        7'd33: sad_sel[4] = BI[31];
        7'd43: sad_sel[4] = BI[41];
        7'd44: sad_sel[4] = BI[42];
        7'd45: sad_sel[4] = BI[43];
        7'd46: sad_sel[4] = BI[44];
        7'd47: sad_sel[4] = BI[45];
        7'd48: sad_sel[4] = BI[46];
        7'd49: sad_sel[4] = BI[47];
        7'd50: sad_sel[4] = BI[48];
        7'd60: sad_sel[4] = BI[58];
        7'd59: sad_sel[4] = BI[57];
        7'd58: sad_sel[4] = BI[56];
        7'd57: sad_sel[4] = BI[55];
        7'd56: sad_sel[4] = BI[54];
        7'd55: sad_sel[4] = BI[53];
        7'd54: sad_sel[4] = BI[52];
        7'd53: sad_sel[4] = BI[51];
        7'd63: sad_sel[4] = BI[61];
        7'd64: sad_sel[4] = BI[62];
        7'd65: sad_sel[4] = BI[63];
        7'd66: sad_sel[4] = BI[64];
        7'd67: sad_sel[4] = BI[65];
        7'd68: sad_sel[4] = BI[66];
        7'd69: sad_sel[4] = BI[67];
        7'd70: sad_sel[4] = BI[68];
        7'd80: sad_sel[4] = BI[78];
        7'd79: sad_sel[4] = BI[77];
        7'd78: sad_sel[4] = BI[76];
        7'd77: sad_sel[4] = BI[75];
        7'd76: sad_sel[4] = BI[74];
        7'd75: sad_sel[4] = BI[73];
        7'd74: sad_sel[4] = BI[72];
        7'd73: sad_sel[4] = BI[71];
        7'd83: sad_sel[4] = BI[81];
        7'd84: sad_sel[4] = BI[82];
        7'd85: sad_sel[4] = BI[83];
        7'd86: sad_sel[4] = BI[84];
        7'd87: sad_sel[4] = BI[85];
        7'd88: sad_sel[4] = BI[86];
        7'd89: sad_sel[4] = BI[87];
        7'd90: sad_sel[4] = BI[88];
        default: sad_sel[4] = BI0_DOB_reg;
    endcase
end
always @(*) begin
    case (BI_sum_cnt)
        7'd23: sad_sel[5] = BI[1];
        7'd24: sad_sel[5] = BI[2];
        7'd25: sad_sel[5] = BI[3];
        7'd26: sad_sel[5] = BI[4];
        7'd27: sad_sel[5] = BI[5];
        7'd28: sad_sel[5] = BI[6];
        7'd29: sad_sel[5] = BI[7];
        7'd30: sad_sel[5] = BI[8];
        7'd40: sad_sel[5] = BI[18];
        7'd39: sad_sel[5] = BI[17];
        7'd38: sad_sel[5] = BI[16];
        7'd37: sad_sel[5] = BI[15];
        7'd36: sad_sel[5] = BI[14];
        7'd35: sad_sel[5] = BI[13];
        7'd34: sad_sel[5] = BI[12];
        7'd33: sad_sel[5] = BI[11];
        7'd43: sad_sel[5] = BI[21];
        7'd44: sad_sel[5] = BI[22];
        7'd45: sad_sel[5] = BI[23];
        7'd46: sad_sel[5] = BI[24];
        7'd47: sad_sel[5] = BI[25];
        7'd48: sad_sel[5] = BI[26];
        7'd49: sad_sel[5] = BI[27];
        7'd50: sad_sel[5] = BI[28];
        7'd60: sad_sel[5] = BI[38];
        7'd59: sad_sel[5] = BI[37];
        7'd58: sad_sel[5] = BI[36];
        7'd57: sad_sel[5] = BI[35];
        7'd56: sad_sel[5] = BI[34];
        7'd55: sad_sel[5] = BI[33];
        7'd54: sad_sel[5] = BI[32];
        7'd53: sad_sel[5] = BI[31];
        7'd63: sad_sel[5] = BI[41];
        7'd64: sad_sel[5] = BI[42];
        7'd65: sad_sel[5] = BI[43];
        7'd66: sad_sel[5] = BI[44];
        7'd67: sad_sel[5] = BI[45];
        7'd68: sad_sel[5] = BI[46];
        7'd69: sad_sel[5] = BI[47];
        7'd70: sad_sel[5] = BI[48];
        7'd80: sad_sel[5] = BI[58];
        7'd79: sad_sel[5] = BI[57];
        7'd78: sad_sel[5] = BI[56];
        7'd77: sad_sel[5] = BI[55];
        7'd76: sad_sel[5] = BI[54];
        7'd75: sad_sel[5] = BI[53];
        7'd74: sad_sel[5] = BI[52];
        7'd73: sad_sel[5] = BI[51];
        7'd83: sad_sel[5] = BI[61];
        7'd84: sad_sel[5] = BI[62];
        7'd85: sad_sel[5] = BI[63];
        7'd86: sad_sel[5] = BI[64];
        7'd87: sad_sel[5] = BI[65];
        7'd88: sad_sel[5] = BI[66];
        7'd89: sad_sel[5] = BI[67];
        7'd90: sad_sel[5] = BI[68];
        7'd100:sad_sel[5] = BI[78];
        7'd99: sad_sel[5] = BI[77];
        7'd98: sad_sel[5] = BI[76];
        7'd97: sad_sel[5] = BI[75];
        7'd96: sad_sel[5] = BI[74];
        7'd95: sad_sel[5] = BI[73];
        7'd94: sad_sel[5] = BI[72];
        7'd93: sad_sel[5] = BI[71];
        default: sad_sel[5] = BI0_DOB_reg;
    endcase
end
always @(*) begin
    case (BI_sum_cnt)
        7'd4: sad_sel[6] = BI[20];
        7'd5: sad_sel[6] = BI[21];
        7'd6: sad_sel[6] = BI[22];
        7'd7: sad_sel[6] = BI[23];
        7'd8: sad_sel[6] = BI[24];
        7'd9: sad_sel[6] = BI[25];
        7'd10: sad_sel[6] = BI[26];
        7'd11: sad_sel[6] = BI[27];
        7'd19: sad_sel[6] = BI[39];
        7'd18: sad_sel[6] = BI[38];
        7'd17: sad_sel[6] = BI[37];
        7'd16: sad_sel[6] = BI[36];
        7'd15: sad_sel[6] = BI[35];
        7'd14: sad_sel[6] = BI[34];
        7'd13: sad_sel[6] = BI[33];
        7'd12: sad_sel[6] = BI[32];
        7'd24: sad_sel[6] = BI[40];
        7'd25: sad_sel[6] = BI[41];
        7'd26: sad_sel[6] = BI[42];
        7'd27: sad_sel[6] = BI[43];
        7'd28: sad_sel[6] = BI[44];
        7'd29: sad_sel[6] = BI[45];
        7'd30: sad_sel[6] = BI[46];
        7'd31: sad_sel[6] = BI[47];
        7'd39: sad_sel[6] = BI[59];
        7'd38: sad_sel[6] = BI[58];
        7'd37: sad_sel[6] = BI[57];
        7'd36: sad_sel[6] = BI[56];
        7'd35: sad_sel[6] = BI[55];
        7'd34: sad_sel[6] = BI[54];
        7'd33: sad_sel[6] = BI[53];
        7'd32: sad_sel[6] = BI[52];
        7'd44: sad_sel[6] = BI[60];
        7'd45: sad_sel[6] = BI[61];
        7'd46: sad_sel[6] = BI[62];
        7'd47: sad_sel[6] = BI[63];
        7'd48: sad_sel[6] = BI[64];
        7'd49: sad_sel[6] = BI[65];
        7'd50: sad_sel[6] = BI[66];
        7'd51: sad_sel[6] = BI[67];
        7'd59: sad_sel[6] = BI[79];
        7'd58: sad_sel[6] = BI[78];
        7'd57: sad_sel[6] = BI[77];
        7'd56: sad_sel[6] = BI[76];
        7'd55: sad_sel[6] = BI[75];
        7'd54: sad_sel[6] = BI[74];
        7'd53: sad_sel[6] = BI[73];
        7'd52: sad_sel[6] = BI[72];
        7'd64: sad_sel[6] = BI[80];
        7'd65: sad_sel[6] = BI[81];
        7'd66: sad_sel[6] = BI[82];
        7'd67: sad_sel[6] = BI[83];
        7'd68: sad_sel[6] = BI[84];
        7'd69: sad_sel[6] = BI[85];
        7'd70: sad_sel[6] = BI[86];
        7'd71: sad_sel[6] = BI[87];
        7'd79: sad_sel[6] = BI[99];
        7'd78: sad_sel[6] = BI[98];
        7'd77: sad_sel[6] = BI[97];
        7'd76: sad_sel[6] = BI[96];
        7'd75: sad_sel[6] = BI[95];
        7'd74: sad_sel[6] = BI[94];
        7'd73: sad_sel[6] = BI[93];
        7'd72: sad_sel[6] = BI[92];
        default: sad_sel[6] = BI0_DOB_reg;
    endcase
end
always @(*) begin
    case (BI_sum_cnt)
        7'd19: sad_sel[7] = BI[19];
        7'd18: sad_sel[7] = BI[18];
        7'd17: sad_sel[7] = BI[17];
        7'd16: sad_sel[7] = BI[16];
        7'd15: sad_sel[7] = BI[15];
        7'd14: sad_sel[7] = BI[14];
        7'd13: sad_sel[7] = BI[13];
        7'd12: sad_sel[7] = BI[12];
        7'd24: sad_sel[7] = BI[20];
        7'd25: sad_sel[7] = BI[21];
        7'd26: sad_sel[7] = BI[22];
        7'd27: sad_sel[7] = BI[23];
        7'd28: sad_sel[7] = BI[24];
        7'd29: sad_sel[7] = BI[25];
        7'd30: sad_sel[7] = BI[26];
        7'd31: sad_sel[7] = BI[27];
        7'd39: sad_sel[7] = BI[39];
        7'd38: sad_sel[7] = BI[38];
        7'd37: sad_sel[7] = BI[37];
        7'd36: sad_sel[7] = BI[36];
        7'd35: sad_sel[7] = BI[35];
        7'd34: sad_sel[7] = BI[34];
        7'd33: sad_sel[7] = BI[33];
        7'd32: sad_sel[7] = BI[32];
        7'd44: sad_sel[7] = BI[40];
        7'd45: sad_sel[7] = BI[41];
        7'd46: sad_sel[7] = BI[42];
        7'd47: sad_sel[7] = BI[43];
        7'd48: sad_sel[7] = BI[44];
        7'd49: sad_sel[7] = BI[45];
        7'd50: sad_sel[7] = BI[46];
        7'd51: sad_sel[7] = BI[47];
        7'd59: sad_sel[7] = BI[59];
        7'd58: sad_sel[7] = BI[58];
        7'd57: sad_sel[7] = BI[57];
        7'd56: sad_sel[7] = BI[56];
        7'd55: sad_sel[7] = BI[55];
        7'd54: sad_sel[7] = BI[54];
        7'd53: sad_sel[7] = BI[53];
        7'd52: sad_sel[7] = BI[52];
        7'd64: sad_sel[7] = BI[60];
        7'd65: sad_sel[7] = BI[61];
        7'd66: sad_sel[7] = BI[62];
        7'd67: sad_sel[7] = BI[63];
        7'd68: sad_sel[7] = BI[64];
        7'd69: sad_sel[7] = BI[65];
        7'd70: sad_sel[7] = BI[66];
        7'd71: sad_sel[7] = BI[67];
        7'd79: sad_sel[7] = BI[79];
        7'd78: sad_sel[7] = BI[78];
        7'd77: sad_sel[7] = BI[77];
        7'd76: sad_sel[7] = BI[76];
        7'd75: sad_sel[7] = BI[75];
        7'd74: sad_sel[7] = BI[74];
        7'd73: sad_sel[7] = BI[73];
        7'd72: sad_sel[7] = BI[72];
        7'd84: sad_sel[7] = BI[80];
        7'd85: sad_sel[7] = BI[81];
        7'd86: sad_sel[7] = BI[82];
        7'd87: sad_sel[7] = BI[83];
        7'd88: sad_sel[7] = BI[84];
        7'd89: sad_sel[7] = BI[85];
        7'd90: sad_sel[7] = BI[86];
        7'd91: sad_sel[7] = BI[87];
        default: sad_sel[7] = BI0_DOB_reg;
    endcase
end
always @(*) begin
    case (BI_sum_cnt)
        7'd24: sad_sel[8] = BI[0];
        7'd25: sad_sel[8] = BI[1];
        7'd26: sad_sel[8] = BI[2];
        7'd27: sad_sel[8] = BI[3];
        7'd28: sad_sel[8] = BI[4];
        7'd29: sad_sel[8] = BI[5];
        7'd30: sad_sel[8] = BI[6];
        7'd31: sad_sel[8] = BI[7];
        7'd39: sad_sel[8] = BI[19];
        7'd38: sad_sel[8] = BI[18];
        7'd37: sad_sel[8] = BI[17];
        7'd36: sad_sel[8] = BI[16];
        7'd35: sad_sel[8] = BI[15];
        7'd34: sad_sel[8] = BI[14];
        7'd33: sad_sel[8] = BI[13];
        7'd32: sad_sel[8] = BI[12];
        7'd44: sad_sel[8] = BI[20];
        7'd45: sad_sel[8] = BI[21];
        7'd46: sad_sel[8] = BI[22];
        7'd47: sad_sel[8] = BI[23];
        7'd48: sad_sel[8] = BI[24];
        7'd49: sad_sel[8] = BI[25];
        7'd50: sad_sel[8] = BI[26];
        7'd51: sad_sel[8] = BI[27];
        7'd59: sad_sel[8] = BI[39];
        7'd58: sad_sel[8] = BI[38];
        7'd57: sad_sel[8] = BI[37];
        7'd56: sad_sel[8] = BI[36];
        7'd55: sad_sel[8] = BI[35];
        7'd54: sad_sel[8] = BI[34];
        7'd53: sad_sel[8] = BI[33];
        7'd52: sad_sel[8] = BI[32];
        7'd64: sad_sel[8] = BI[40];
        7'd65: sad_sel[8] = BI[41];
        7'd66: sad_sel[8] = BI[42];
        7'd67: sad_sel[8] = BI[43];
        7'd68: sad_sel[8] = BI[44];
        7'd69: sad_sel[8] = BI[45];
        7'd70: sad_sel[8] = BI[46];
        7'd71: sad_sel[8] = BI[47];
        7'd79: sad_sel[8] = BI[59];
        7'd78: sad_sel[8] = BI[58];
        7'd77: sad_sel[8] = BI[57];
        7'd76: sad_sel[8] = BI[56];
        7'd75: sad_sel[8] = BI[55];
        7'd74: sad_sel[8] = BI[54];
        7'd73: sad_sel[8] = BI[53];
        7'd72: sad_sel[8] = BI[52];
        7'd84: sad_sel[8] = BI[60];
        7'd85: sad_sel[8] = BI[61];
        7'd86: sad_sel[8] = BI[62];
        7'd87: sad_sel[8] = BI[63];
        7'd88: sad_sel[8] = BI[64];
        7'd89: sad_sel[8] = BI[65];
        7'd90: sad_sel[8] = BI[66];
        7'd91: sad_sel[8] = BI[67];
        7'd99: sad_sel[8] = BI[79];
        7'd98: sad_sel[8] = BI[78];
        7'd97: sad_sel[8] = BI[77];
        7'd96: sad_sel[8] = BI[76];
        7'd95: sad_sel[8] = BI[75];
        7'd94: sad_sel[8] = BI[74];
        7'd93: sad_sel[8] = BI[73];
        7'd92: sad_sel[8] = BI[72];
        default: sad_sel[8] = BI0_DOB_reg;
    endcase
end
always @(posedge clk) begin
    case (BI_sum_cnt)
        7'd2: sad[0] <= BI_compare[0]? sad_sel[0] - BI0_DOB_reg:BI0_DOB_reg - sad_sel[0];
        default: sad[0] <= BI_compare[0]? sad[0] + (sad_sel[0] - BI0_DOB_reg):sad[0] + (BI0_DOB_reg - sad_sel[0]);
    endcase
end
always @(posedge clk) begin
    case (BI_sum_cnt)
        7'd14: sad[1] <= BI_compare[1]? sad_sel[1] - BI0_DOB_reg:BI0_DOB_reg - sad_sel[1];
        default: sad[1] <= BI_compare[1]? sad[1] + (sad_sel[1] - BI0_DOB_reg):sad[1] + (BI0_DOB_reg - sad_sel[1]);
    endcase
end
always @(posedge clk) begin
    case (BI_sum_cnt)
        7'd22: sad[2] <= BI_compare[2]? sad_sel[2] - BI0_DOB_reg:BI0_DOB_reg - sad_sel[2];
        default: sad[2] <= BI_compare[2]? sad[2] + (sad_sel[2] - BI0_DOB_reg):sad[2] + (BI0_DOB_reg - sad_sel[2]);
    endcase
end
always @(posedge clk) begin
    case (BI_sum_cnt)
        7'd3: sad[3] <= BI_compare[3]? sad_sel[3] - BI0_DOB_reg:BI0_DOB_reg - sad_sel[3];
        default: sad[3] <= BI_compare[3]? sad[3] + (sad_sel[3] - BI0_DOB_reg):sad[3] + (BI0_DOB_reg - sad_sel[3]);
    endcase
end
always @(posedge clk) begin
    case (BI_sum_cnt)
        7'd13: sad[4] <= BI_compare[4]? sad_sel[4] - BI0_DOB_reg:BI0_DOB_reg - sad_sel[4];
        default: sad[4] <= BI_compare[4]? sad[4] + (sad_sel[4] - BI0_DOB_reg):sad[4] + (BI0_DOB_reg - sad_sel[4]);
    endcase
end
always @(posedge clk) begin
    case (BI_sum_cnt)
        7'd23: sad[5] <= BI_compare[5]? sad_sel[5] - BI0_DOB_reg:BI0_DOB_reg - sad_sel[5];
        default: sad[5] <= BI_compare[5]? sad[5] + (sad_sel[5] - BI0_DOB_reg):sad[5] + (BI0_DOB_reg - sad_sel[5]);
    endcase
end
always @(posedge clk) begin
    case (BI_sum_cnt)
        7'd4: sad[6] <= BI_compare[6]? sad_sel[6] - BI0_DOB_reg:BI0_DOB_reg - sad_sel[6];
        default: sad[6] <= BI_compare[6]? sad[6] + (sad_sel[6] - BI0_DOB_reg):sad[6] + (BI0_DOB_reg - sad_sel[6]);
    endcase
end
always @(posedge clk) begin
    case (BI_sum_cnt)
        7'd12: sad[7] <= BI_compare[7]? sad_sel[7] - BI0_DOB_reg:BI0_DOB_reg - sad_sel[7];
        default: sad[7] <= BI_compare[7]? sad[7] + (sad_sel[7] - BI0_DOB_reg):sad[7] + (BI0_DOB_reg - sad_sel[7]);
    endcase
end
always @(posedge clk) begin
    case (BI_sum_cnt)
        7'd24: sad[8] <= BI_compare[8]? sad_sel[8] - BI0_DOB_reg:BI0_DOB_reg - sad_sel[8];
        default: sad[8] <= BI_compare[8]? sad[8] + (sad_sel[8] - BI0_DOB_reg):sad[8] + (BI0_DOB_reg - sad_sel[8]);
    endcase
end
generate
    for(i = 0; i < 9; i = i + 1)begin
        always @(*) begin  
            BI_compare[i] = BI0_DOB_reg < sad_sel[i];
        end
    end
endgenerate
sram16384x8 img0(.A0(A[0][0]),     .A1(A[0][1]),           .A2(A[0][2]),           .A3(A[0][3]),
             .A4(A[0][4]),         .A5(A[0][5]),           .A6(A[0][6]),           .A7(A[0][7]),
             .A8(A[0][8]),         .A9(A[0][9]),           .A10(A[0][10]),         .A11(A[0][11]),
             .A12(A[0][12]),       .A13(A[0][13]),
             .DO0(Dout[0][0]),     .DO1(Dout[0][1]),       .DO2(Dout[0][2]),       .DO3(Dout[0][3]),
             .DO4(Dout[0][4]),     .DO5(Dout[0][5]),       .DO6(Dout[0][6]),       .DO7(Dout[0][7]),
             .DI0(Din[0]),         .DI1(Din[1]),           .DI2(Din[2]),           .DI3(Din[3]),
             .DI4(Din[4]),         .DI5(Din[5]),           .DI6(Din[6]),           .DI7(Din[7]),
             .CK(clk),             .WEB(WEB[0]),           .OE(1'b1),              .CS(1'b1));
sram16384x8 img1(.A0(A[1][0]),     .A1(A[1][1]),           .A2(A[1][2]),           .A3(A[1][3]),
             .A4(A[1][4]),         .A5(A[1][5]),           .A6(A[1][6]),           .A7(A[1][7]),
             .A8(A[1][8]),         .A9(A[1][9]),           .A10(A[1][10]),         .A11(A[1][11]),
             .A12(A[1][12]),       .A13(A[1][13]),
             .DO0(Dout[1][0]),     .DO1(Dout[1][1]),       .DO2(Dout[1][2]),       .DO3(Dout[1][3]),
             .DO4(Dout[1][4]),     .DO5(Dout[1][5]),       .DO6(Dout[1][6]),       .DO7(Dout[1][7]),
             .DI0(Din[0]),         .DI1(Din[1]),           .DI2(Din[2]),           .DI3(Din[3]),
             .DI4(Din[4]),         .DI5(Din[5]),           .DI6(Din[6]),           .DI7(Din[7]),
             .CK(clk),             .WEB(WEB[1]),           .OE(1'b1),              .CS(1'b1));
sram100x18 BI0(.A0(BI0_A[0]),.A1(BI0_A[1]),.A2(BI0_A[2]),.A3(BI0_A[3]),.A4(BI0_A[4]),.A5(BI0_A[5]),.A6(BI0_A[6]),
             .B0(BI0_B[0]),.B1(BI0_B[1]),.B2(BI0_B[2]),.B3(BI0_B[3]),.B4(BI0_B[4]),.B5(BI0_B[5]),.B6(BI0_B[6]),
             .DOA0(BI0_DOA[0]),.DOA1(BI0_DOA[1]),.DOA2(BI0_DOA[2]),.DOA3(BI0_DOA[3]),.DOA4(BI0_DOA[4]),.DOA5(BI0_DOA[5]),.DOA6(BI0_DOA[6]),.DOA7(BI0_DOA[7]),.DOA8(BI0_DOA[8]),.DOA9(BI0_DOA[9]),
             .DOA10(BI0_DOA[10]),.DOA11(BI0_DOA[11]),.DOA12(BI0_DOA[12]),.DOA13(BI0_DOA[13]),.DOA14(BI0_DOA[14]),.DOA15(BI0_DOA[15]),.DOA16(BI0_DOA[16]),
             .DOA17(BI0_DOA[17]),.DOB0(BI0_DOB[0]),.DOB1(BI0_DOB[1]),.DOB2(BI0_DOB[2]),.DOB3(BI0_DOB[3]),.DOB4(BI0_DOB[4]),.DOB5(BI0_DOB[5]),.DOB6(BI0_DOB[6]),
             .DOB7(BI0_DOB[7]),.DOB8(BI0_DOB[8]),.DOB9(BI0_DOB[9]),.DOB10(BI0_DOB[10]),.DOB11(BI0_DOB[11]),.DOB12(BI0_DOB[12]),.DOB13(BI0_DOB[13]),
             .DOB14(BI0_DOB[14]),.DOB15(BI0_DOB[15]),.DOB16(BI0_DOB[16]),.DOB17(BI0_DOB[17]),.DIA0(BI0_DIA[0]),.DIA1(BI0_DIA[1]),.DIA2(BI0_DIA[2]),
             .DIA3(BI0_DIA[3]),.DIA4(BI0_DIA[4]),.DIA5(BI0_DIA[5]),.DIA6(BI0_DIA[6]),.DIA7(BI0_DIA[7]),.DIA8(BI0_DIA[8]),.DIA9(BI0_DIA[9]),.DIA10(BI0_DIA[10]),
             .DIA11(BI0_DIA[11]),.DIA12(BI0_DIA[12]),.DIA13(BI0_DIA[13]),.DIA14(BI0_DIA[14]),.DIA15(BI0_DIA[15]),.DIA16(BI0_DIA[16]),.DIA17(BI0_DIA[17]),
             .DIB0(BI0_DIB[0]),.DIB1(BI0_DIB[1]),.DIB2(BI0_DIB[2]),.DIB3(BI0_DIB[3]),.DIB4(BI0_DIB[4]),.DIB5(BI0_DIB[5]),.DIB6(BI0_DIB[6]),.DIB7(BI0_DIB[7]),
             .DIB8(BI0_DIB[8]),.DIB9(BI0_DIB[9]),.DIB10(BI0_DIB[10]),.DIB11(BI0_DIB[11]),.DIB12(BI0_DIB[12]),.DIB13(BI0_DIB[13]),.DIB14(BI0_DIB[14]),
             .DIB15(BI0_DIB[15]),.DIB16(BI0_DIB[16]),.DIB17(BI0_DIB[17]),.WEAN(BI0_WEN_A),.WEBN(BI0_WEN_B),.CKA(clk),.CKB(clk),.CSA(1'b1),.CSB(1'b1),.OEA(1'b1),.OEB(1'b1));
endmodule

module find_min(
    input[23:0] sad1,
    input[23:0] sad2,
    input[23:0] sad3,
    input[3:0] idx1,
    input[3:0] idx2,
    input[3:0] idx3,
    output[23:0] min_sad,
    output reg[3:0] min_idx
);
    wire[23:0] m_sad;
    reg[3:0] m_idx;
    assign m_sad = (sad1 < sad2)? sad1:sad2;
    assign min_sad = (m_sad < sad3)? m_sad:sad3;
    always @(*) begin
        if(sad1 < sad2)
            m_idx = idx1;
        else if(sad1 > sad2)
            m_idx = idx2;
        else if(idx1 < idx2)
            m_idx = idx1;
        else
            m_idx = idx2;
    end
    always @(*) begin
        if(m_sad < sad3)
            min_idx = m_idx;
        else if(m_sad > sad3)
            min_idx = idx3;
        else if(m_idx < idx3)
            min_idx = m_idx;
        else
            min_idx = idx3;
    end
endmodule
