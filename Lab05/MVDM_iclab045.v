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
reg[17:0] BI[1:0][99:0], BI_reg[1:0];
reg[17:0] A1[1:0], A2[1:0];
reg[23:0] sad[8:0];
reg[23:0] min_sad_reg[3:1];
wire[23:0] min_sad[3:0];
reg[3:0] min_sad_idx_reg[3:1];
wire[3:0] min_sad_idx[3:0];
reg[55:0] output_reg;
reg[5:0] output_cnt;
//=======================================================
//                   Design
//=======================================================
assign A[0] = (in_valid)? img_cnt:img_addr[0];
assign A[1] = (in_valid)? img_cnt:img_addr[1];
assign Din = in_data[11:4];
assign WEB[0] = !in_valid |  cnt;
assign WEB[1] = !in_valid | !cnt;
always @(*) begin
    if(pt_cnt && output_cnt != 6'd56)begin
        out_valid = 1;
        out_sad = output_reg[output_cnt];
    end else begin
        out_valid = 0;
        out_sad = 0;
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        output_cnt <= 6'd56;
    else if(in_valid)
        output_cnt <= 6'd56;
    else if(pt_cnt && pt2_cnt && BI_sum_cnt == 7'd101)
        output_cnt <= 6'b0;
    else if(output_cnt != 6'd56)
        output_cnt <= output_cnt + 1'b1;
    else
        output_cnt <= output_cnt;
end
always @(posedge clk) begin
    Dout_reg[0] <= Dout[0];
    Dout_reg[1] <= Dout[1];
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
                BI[0][i] <= BI_reg[0];
                BI[1][i] <= BI_reg[1];
            end else begin
                BI[0][i] <= BI[0][i];
                BI[1][i] <= BI[1][i];
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
always @(posedge clk) begin
    if(in_mv_cnt == 3'd3)begin
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
        BI_sum_cnt <= 7'd102;
    else if(BI_wrt_idx == 7'd61)
        BI_sum_cnt <= 0;
    else if(BI_sum_cnt != 7'd102)
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
    if(BI_sum_cnt == 7'd101) // todo
        output_reg <= {min_sad_idx[0], min_sad[0], output_reg[55:28]};
    else
        output_reg <= output_reg;
end
always @(posedge clk) begin
    case (spot_cnt)
        6'd0: {calc_reg[0][0][0], calc_reg[1][0][0]} <= {Dout_reg[0], Dout_reg[1]};
        6'd4: {calc_reg[0][0][0], calc_reg[1][0][0]} <= {calc_reg[0][0][1], calc_reg[1][0][1]};
        6'd6: {calc_reg[0][0][0], calc_reg[1][0][0]} <= {calc_reg[0][0][1], calc_reg[1][0][1]};
        6'd8: {calc_reg[0][0][0], calc_reg[1][0][0]} <= {calc_reg[0][0][1], calc_reg[1][0][1]};
        6'd10:{calc_reg[0][0][0], calc_reg[1][0][0]} <= {calc_reg[0][0][1], calc_reg[1][0][1]};
        6'd12:{calc_reg[0][0][0], calc_reg[1][0][0]} <= {calc_reg[0][0][1], calc_reg[1][0][1]};
        6'd14:{calc_reg[0][0][0], calc_reg[1][0][0]} <= {calc_reg[0][0][1], calc_reg[1][0][1]};
        6'd16:{calc_reg[0][0][0], calc_reg[1][0][0]} <= {calc_reg[0][0][1], calc_reg[1][0][1]};
        6'd18:{calc_reg[0][0][0], calc_reg[1][0][0]} <= {calc_reg[0][0][1], calc_reg[1][0][1]};
        6'd20:{calc_reg[0][0][0], calc_reg[1][0][0]} <= {calc_reg[0][0][1], calc_reg[1][0][1]};
        6'd22:{calc_reg[0][0][0], calc_reg[1][0][0]} <= {calc_reg[0][1][0], calc_reg[1][1][0]};
        6'd24:{calc_reg[0][0][0], calc_reg[1][0][0]} <= {Dout_reg[0], Dout_reg[1]};
        6'd26:{calc_reg[0][0][0], calc_reg[1][0][0]} <= {Dout_reg[0], Dout_reg[1]};
        6'd28:{calc_reg[0][0][0], calc_reg[1][0][0]} <= {Dout_reg[0], Dout_reg[1]};
        6'd30:{calc_reg[0][0][0], calc_reg[1][0][0]} <= {Dout_reg[0], Dout_reg[1]};
        6'd32:{calc_reg[0][0][0], calc_reg[1][0][0]} <= {Dout_reg[0], Dout_reg[1]};
        6'd34:{calc_reg[0][0][0], calc_reg[1][0][0]} <= {Dout_reg[0], Dout_reg[1]};
        6'd36:{calc_reg[0][0][0], calc_reg[1][0][0]} <= {Dout_reg[0], Dout_reg[1]};
        6'd38:{calc_reg[0][0][0], calc_reg[1][0][0]} <= {Dout_reg[0], Dout_reg[1]};
        6'd40:{calc_reg[0][0][0], calc_reg[1][0][0]} <= {Dout_reg[0], Dout_reg[1]};
        6'd42:{calc_reg[0][0][0], calc_reg[1][0][0]} <= {calc_reg[0][1][0], calc_reg[1][1][0]};
        default:{calc_reg[0][0][0], calc_reg[1][0][0]} <= {calc_reg[0][0][0], calc_reg[1][0][0]};
    endcase
end
always @(posedge clk) begin
    case (spot_cnt)
        6'd2: {calc_reg[0][0][1], calc_reg[1][0][1]} <= {Dout_reg[0], Dout_reg[1]};
        6'd4: {calc_reg[0][0][1], calc_reg[1][0][1]} <= {Dout_reg[0], Dout_reg[1]};
        6'd6: {calc_reg[0][0][1], calc_reg[1][0][1]} <= {Dout_reg[0], Dout_reg[1]};
        6'd8: {calc_reg[0][0][1], calc_reg[1][0][1]} <= {Dout_reg[0], Dout_reg[1]};
        6'd10:{calc_reg[0][0][1], calc_reg[1][0][1]} <= {Dout_reg[0], Dout_reg[1]};
        6'd12:{calc_reg[0][0][1], calc_reg[1][0][1]} <= {Dout_reg[0], Dout_reg[1]};
        6'd14:{calc_reg[0][0][1], calc_reg[1][0][1]} <= {Dout_reg[0], Dout_reg[1]};
        6'd16:{calc_reg[0][0][1], calc_reg[1][0][1]} <= {Dout_reg[0], Dout_reg[1]};
        6'd18:{calc_reg[0][0][1], calc_reg[1][0][1]} <= {Dout_reg[0], Dout_reg[1]};
        6'd20:{calc_reg[0][0][1], calc_reg[1][0][1]} <= {Dout_reg[0], Dout_reg[1]};
        6'd22:{calc_reg[0][0][1], calc_reg[1][0][1]} <= {calc_reg[0][1][1], calc_reg[1][1][1]};
        6'd24:{calc_reg[0][0][1], calc_reg[1][0][1]} <= {calc_reg[0][0][0], calc_reg[1][0][0]};
        6'd26:{calc_reg[0][0][1], calc_reg[1][0][1]} <= {calc_reg[0][0][0], calc_reg[1][0][0]};
        6'd28:{calc_reg[0][0][1], calc_reg[1][0][1]} <= {calc_reg[0][0][0], calc_reg[1][0][0]};
        6'd30:{calc_reg[0][0][1], calc_reg[1][0][1]} <= {calc_reg[0][0][0], calc_reg[1][0][0]};
        6'd32:{calc_reg[0][0][1], calc_reg[1][0][1]} <= {calc_reg[0][0][0], calc_reg[1][0][0]};
        6'd34:{calc_reg[0][0][1], calc_reg[1][0][1]} <= {calc_reg[0][0][0], calc_reg[1][0][0]};
        6'd36:{calc_reg[0][0][1], calc_reg[1][0][1]} <= {calc_reg[0][0][0], calc_reg[1][0][0]};
        6'd38:{calc_reg[0][0][1], calc_reg[1][0][1]} <= {calc_reg[0][0][0], calc_reg[1][0][0]};
        6'd40:{calc_reg[0][0][1], calc_reg[1][0][1]} <= {calc_reg[0][0][0], calc_reg[1][0][0]};
        6'd42:{calc_reg[0][0][1], calc_reg[1][0][1]} <= {calc_reg[0][1][1], calc_reg[1][1][1]};
        default:{calc_reg[0][0][1], calc_reg[1][0][1]} <= {calc_reg[0][0][1], calc_reg[1][0][1]};
    endcase
end
always @(posedge clk) begin
    case (spot_cnt)
        6'd1: {calc_reg[0][1][0], calc_reg[1][1][0]} <= {Dout_reg[0], Dout_reg[1]};
        6'd4: {calc_reg[0][1][0], calc_reg[1][1][0]} <= {calc_reg[0][1][1], calc_reg[1][1][1]};
        6'd6: {calc_reg[0][1][0], calc_reg[1][1][0]} <= {calc_reg[0][1][1], calc_reg[1][1][1]};
        6'd8: {calc_reg[0][1][0], calc_reg[1][1][0]} <= {calc_reg[0][1][1], calc_reg[1][1][1]};
        6'd10:{calc_reg[0][1][0], calc_reg[1][1][0]} <= {calc_reg[0][1][1], calc_reg[1][1][1]};
        6'd12:{calc_reg[0][1][0], calc_reg[1][1][0]} <= {calc_reg[0][1][1], calc_reg[1][1][1]};
        6'd14:{calc_reg[0][1][0], calc_reg[1][1][0]} <= {calc_reg[0][1][1], calc_reg[1][1][1]};
        6'd16:{calc_reg[0][1][0], calc_reg[1][1][0]} <= {calc_reg[0][1][1], calc_reg[1][1][1]};
        6'd18:{calc_reg[0][1][0], calc_reg[1][1][0]} <= {calc_reg[0][1][1], calc_reg[1][1][1]};
        6'd20:{calc_reg[0][1][0], calc_reg[1][1][0]} <= {calc_reg[0][1][1], calc_reg[1][1][1]};
        6'd23:{calc_reg[0][1][0], calc_reg[1][1][0]} <= {Dout_reg[0], Dout_reg[1]};
        6'd25:{calc_reg[0][1][0], calc_reg[1][1][0]} <= {Dout_reg[0], Dout_reg[1]};
        6'd27:{calc_reg[0][1][0], calc_reg[1][1][0]} <= {Dout_reg[0], Dout_reg[1]};
        6'd29:{calc_reg[0][1][0], calc_reg[1][1][0]} <= {Dout_reg[0], Dout_reg[1]};
        6'd31:{calc_reg[0][1][0], calc_reg[1][1][0]} <= {Dout_reg[0], Dout_reg[1]};
        6'd33:{calc_reg[0][1][0], calc_reg[1][1][0]} <= {Dout_reg[0], Dout_reg[1]};
        6'd35:{calc_reg[0][1][0], calc_reg[1][1][0]} <= {Dout_reg[0], Dout_reg[1]};
        6'd37:{calc_reg[0][1][0], calc_reg[1][1][0]} <= {Dout_reg[0], Dout_reg[1]};
        6'd39:{calc_reg[0][1][0], calc_reg[1][1][0]} <= {Dout_reg[0], Dout_reg[1]};
        6'd41:{calc_reg[0][1][0], calc_reg[1][1][0]} <= {Dout_reg[0], Dout_reg[1]};
        6'd42:{calc_reg[0][1][0], calc_reg[1][1][0]} <= {Dout_reg[0], Dout_reg[1]};
        default:{calc_reg[0][1][0], calc_reg[1][1][0]} <= {calc_reg[0][1][0], calc_reg[1][1][0]};
    endcase
end
always @(posedge clk) begin
    case (spot_cnt)
        6'd3: {calc_reg[0][1][1], calc_reg[1][1][1]} <= {Dout_reg[0], Dout_reg[1]};
        6'd5: {calc_reg[0][1][1], calc_reg[1][1][1]} <= {Dout_reg[0], Dout_reg[1]};
        6'd7: {calc_reg[0][1][1], calc_reg[1][1][1]} <= {Dout_reg[0], Dout_reg[1]};
        6'd9: {calc_reg[0][1][1], calc_reg[1][1][1]} <= {Dout_reg[0], Dout_reg[1]};
        6'd11:{calc_reg[0][1][1], calc_reg[1][1][1]} <= {Dout_reg[0], Dout_reg[1]};
        6'd13:{calc_reg[0][1][1], calc_reg[1][1][1]} <= {Dout_reg[0], Dout_reg[1]};
        6'd15:{calc_reg[0][1][1], calc_reg[1][1][1]} <= {Dout_reg[0], Dout_reg[1]};
        6'd17:{calc_reg[0][1][1], calc_reg[1][1][1]} <= {Dout_reg[0], Dout_reg[1]};
        6'd19:{calc_reg[0][1][1], calc_reg[1][1][1]} <= {Dout_reg[0], Dout_reg[1]};
        6'd21:{calc_reg[0][1][1], calc_reg[1][1][1]} <= {Dout_reg[0], Dout_reg[1]};
        6'd22:{calc_reg[0][1][1], calc_reg[1][1][1]} <= {Dout_reg[0], Dout_reg[1]};
        6'd24:{calc_reg[0][1][1], calc_reg[1][1][1]} <= {calc_reg[0][1][0], calc_reg[1][1][0]};
        6'd26:{calc_reg[0][1][1], calc_reg[1][1][1]} <= {calc_reg[0][1][0], calc_reg[1][1][0]};
        6'd28:{calc_reg[0][1][1], calc_reg[1][1][1]} <= {calc_reg[0][1][0], calc_reg[1][1][0]};
        6'd30:{calc_reg[0][1][1], calc_reg[1][1][1]} <= {calc_reg[0][1][0], calc_reg[1][1][0]};
        6'd32:{calc_reg[0][1][1], calc_reg[1][1][1]} <= {calc_reg[0][1][0], calc_reg[1][1][0]};
        6'd34:{calc_reg[0][1][1], calc_reg[1][1][1]} <= {calc_reg[0][1][0], calc_reg[1][1][0]};
        6'd36:{calc_reg[0][1][1], calc_reg[1][1][1]} <= {calc_reg[0][1][0], calc_reg[1][1][0]};
        6'd38:{calc_reg[0][1][1], calc_reg[1][1][1]} <= {calc_reg[0][1][0], calc_reg[1][1][0]};
        6'd40:{calc_reg[0][1][1], calc_reg[1][1][1]} <= {calc_reg[0][1][0], calc_reg[1][1][0]};
        6'd43:{calc_reg[0][1][1], calc_reg[1][1][1]} <= {Dout_reg[0], Dout_reg[1]};
        default:{calc_reg[0][1][1], calc_reg[1][1][1]} <= {calc_reg[0][1][1], calc_reg[1][1][1]};
    endcase
end
always @(*) begin
    case(move_pat_cnt) //synopsys parallel_case
        6'd22:{next_img_addr[0], next_img_addr[1]} = {img_addr[0] - 1'b1, img_addr[1] - 1'b1};
        6'd42:{next_img_addr[0], next_img_addr[1]} = {img_addr[0] + 1'b1, img_addr[1] + 1'b1};
        6'd1: {next_img_addr[0], next_img_addr[1]} = {img_addr[0] - 8'd127, img_addr[1] - 8'd127};
        6'd3: {next_img_addr[0], next_img_addr[1]} = {img_addr[0] - 8'd127, img_addr[1] - 8'd127};
        6'd5: {next_img_addr[0], next_img_addr[1]} = {img_addr[0] - 8'd127, img_addr[1] - 8'd127};
        6'd7: {next_img_addr[0], next_img_addr[1]} = {img_addr[0] - 8'd127, img_addr[1] - 8'd127};
        6'd9: {next_img_addr[0], next_img_addr[1]} = {img_addr[0] - 8'd127, img_addr[1] - 8'd127};
        6'd11:{next_img_addr[0], next_img_addr[1]} = {img_addr[0] - 8'd127, img_addr[1] - 8'd127};
        6'd13:{next_img_addr[0], next_img_addr[1]} = {img_addr[0] - 8'd127, img_addr[1] - 8'd127};
        6'd15:{next_img_addr[0], next_img_addr[1]} = {img_addr[0] - 8'd127, img_addr[1] - 8'd127};
        6'd17:{next_img_addr[0], next_img_addr[1]} = {img_addr[0] - 8'd127, img_addr[1] - 8'd127};
        6'd19:{next_img_addr[0], next_img_addr[1]} = {img_addr[0] - 8'd127, img_addr[1] - 8'd127};
        6'd23:{next_img_addr[0], next_img_addr[1]} = {img_addr[0] - 8'd129, img_addr[1] - 8'd129};
        6'd25:{next_img_addr[0], next_img_addr[1]} = {img_addr[0] - 8'd129, img_addr[1] - 8'd129};
        6'd27:{next_img_addr[0], next_img_addr[1]} = {img_addr[0] - 8'd129, img_addr[1] - 8'd129};
        6'd29:{next_img_addr[0], next_img_addr[1]} = {img_addr[0] - 8'd129, img_addr[1] - 8'd129};
        6'd31:{next_img_addr[0], next_img_addr[1]} = {img_addr[0] - 8'd129, img_addr[1] - 8'd129};
        6'd33:{next_img_addr[0], next_img_addr[1]} = {img_addr[0] - 8'd129, img_addr[1] - 8'd129};
        6'd35:{next_img_addr[0], next_img_addr[1]} = {img_addr[0] - 8'd129, img_addr[1] - 8'd129};
        6'd37:{next_img_addr[0], next_img_addr[1]} = {img_addr[0] - 8'd129, img_addr[1] - 8'd129};
        6'd39:{next_img_addr[0], next_img_addr[1]} = {img_addr[0] - 8'd129, img_addr[1] - 8'd129};
        default:{next_img_addr[0], next_img_addr[1]} = {img_addr[0] + 8'd128, img_addr[1] + 8'd128};
    endcase
end
always @(posedge clk) begin
    case (BI_sum_cnt)
        7'd0: sad[0] <= (BI[0][0] < BI[1][22])? BI[1][22] - BI[0][0]:BI[0][0] - BI[1][22];
        7'd1: sad[0] <= (BI[0][1] < BI[1][23])? sad[0] + (BI[1][23] - BI[0][1]):sad[0] + (BI[0][1] - BI[1][23]);
        7'd2: sad[0] <= (BI[0][2] < BI[1][24])? sad[0] + (BI[1][24] - BI[0][2]):sad[0] + (BI[0][2] - BI[1][24]);
        7'd3: sad[0] <= (BI[0][3] < BI[1][25])? sad[0] + (BI[1][25] - BI[0][3]):sad[0] + (BI[0][3] - BI[1][25]);
        7'd4: sad[0] <= (BI[0][4] < BI[1][26])? sad[0] + (BI[1][26] - BI[0][4]):sad[0] + (BI[0][4] - BI[1][26]);
        7'd5: sad[0] <= (BI[0][5] < BI[1][27])? sad[0] + (BI[1][27] - BI[0][5]):sad[0] + (BI[0][5] - BI[1][27]);
        7'd6: sad[0] <= (BI[0][6] < BI[1][28])? sad[0] + (BI[1][28] - BI[0][6]):sad[0] + (BI[0][6] - BI[1][28]);
        7'd7: sad[0] <= (BI[0][7] < BI[1][29])? sad[0] + (BI[1][29] - BI[0][7]):sad[0] + (BI[0][7] - BI[1][29]);
        7'd19: sad[0] <= (BI[0][19] < BI[1][37])? sad[0] + (BI[1][37] - BI[0][19]):sad[0] + (BI[0][19] - BI[1][37]);
        7'd18: sad[0] <= (BI[0][18] < BI[1][36])? sad[0] + (BI[1][36] - BI[0][18]):sad[0] + (BI[0][18] - BI[1][36]);
        7'd17: sad[0] <= (BI[0][17] < BI[1][35])? sad[0] + (BI[1][35] - BI[0][17]):sad[0] + (BI[0][17] - BI[1][35]);
        7'd16: sad[0] <= (BI[0][16] < BI[1][34])? sad[0] + (BI[1][34] - BI[0][16]):sad[0] + (BI[0][16] - BI[1][34]);
        7'd15: sad[0] <= (BI[0][15] < BI[1][33])? sad[0] + (BI[1][33] - BI[0][15]):sad[0] + (BI[0][15] - BI[1][33]);
        7'd14: sad[0] <= (BI[0][14] < BI[1][32])? sad[0] + (BI[1][32] - BI[0][14]):sad[0] + (BI[0][14] - BI[1][32]);
        7'd13: sad[0] <= (BI[0][13] < BI[1][31])? sad[0] + (BI[1][31] - BI[0][13]):sad[0] + (BI[0][13] - BI[1][31]);
        7'd12: sad[0] <= (BI[0][12] < BI[1][30])? sad[0] + (BI[1][30] - BI[0][12]):sad[0] + (BI[0][12] - BI[1][30]);
        7'd20: sad[0] <= (BI[0][20] < BI[1][42])? sad[0] + (BI[1][42] - BI[0][20]):sad[0] + (BI[0][20] - BI[1][42]);
        7'd21: sad[0] <= (BI[0][21] < BI[1][43])? sad[0] + (BI[1][43] - BI[0][21]):sad[0] + (BI[0][21] - BI[1][43]);
        7'd22: sad[0] <= (BI[0][22] < BI[1][44])? sad[0] + (BI[1][44] - BI[0][22]):sad[0] + (BI[0][22] - BI[1][44]);
        7'd23: sad[0] <= (BI[0][23] < BI[1][45])? sad[0] + (BI[1][45] - BI[0][23]):sad[0] + (BI[0][23] - BI[1][45]);
        7'd24: sad[0] <= (BI[0][24] < BI[1][46])? sad[0] + (BI[1][46] - BI[0][24]):sad[0] + (BI[0][24] - BI[1][46]);
        7'd25: sad[0] <= (BI[0][25] < BI[1][47])? sad[0] + (BI[1][47] - BI[0][25]):sad[0] + (BI[0][25] - BI[1][47]);
        7'd26: sad[0] <= (BI[0][26] < BI[1][48])? sad[0] + (BI[1][48] - BI[0][26]):sad[0] + (BI[0][26] - BI[1][48]);
        7'd27: sad[0] <= (BI[0][27] < BI[1][49])? sad[0] + (BI[1][49] - BI[0][27]):sad[0] + (BI[0][27] - BI[1][49]);
        7'd39: sad[0] <= (BI[0][39] < BI[1][57])? sad[0] + (BI[1][57] - BI[0][39]):sad[0] + (BI[0][39] - BI[1][57]);
        7'd38: sad[0] <= (BI[0][38] < BI[1][56])? sad[0] + (BI[1][56] - BI[0][38]):sad[0] + (BI[0][38] - BI[1][56]);
        7'd37: sad[0] <= (BI[0][37] < BI[1][55])? sad[0] + (BI[1][55] - BI[0][37]):sad[0] + (BI[0][37] - BI[1][55]);
        7'd36: sad[0] <= (BI[0][36] < BI[1][54])? sad[0] + (BI[1][54] - BI[0][36]):sad[0] + (BI[0][36] - BI[1][54]);
        7'd35: sad[0] <= (BI[0][35] < BI[1][53])? sad[0] + (BI[1][53] - BI[0][35]):sad[0] + (BI[0][35] - BI[1][53]);
        7'd34: sad[0] <= (BI[0][34] < BI[1][52])? sad[0] + (BI[1][52] - BI[0][34]):sad[0] + (BI[0][34] - BI[1][52]);
        7'd33: sad[0] <= (BI[0][33] < BI[1][51])? sad[0] + (BI[1][51] - BI[0][33]):sad[0] + (BI[0][33] - BI[1][51]);
        7'd32: sad[0] <= (BI[0][32] < BI[1][50])? sad[0] + (BI[1][50] - BI[0][32]):sad[0] + (BI[0][32] - BI[1][50]);
        7'd40: sad[0] <= (BI[0][40] < BI[1][62])? sad[0] + (BI[1][62] - BI[0][40]):sad[0] + (BI[0][40] - BI[1][62]);
        7'd41: sad[0] <= (BI[0][41] < BI[1][63])? sad[0] + (BI[1][63] - BI[0][41]):sad[0] + (BI[0][41] - BI[1][63]);
        7'd42: sad[0] <= (BI[0][42] < BI[1][64])? sad[0] + (BI[1][64] - BI[0][42]):sad[0] + (BI[0][42] - BI[1][64]);
        7'd43: sad[0] <= (BI[0][43] < BI[1][65])? sad[0] + (BI[1][65] - BI[0][43]):sad[0] + (BI[0][43] - BI[1][65]);
        7'd44: sad[0] <= (BI[0][44] < BI[1][66])? sad[0] + (BI[1][66] - BI[0][44]):sad[0] + (BI[0][44] - BI[1][66]);
        7'd45: sad[0] <= (BI[0][45] < BI[1][67])? sad[0] + (BI[1][67] - BI[0][45]):sad[0] + (BI[0][45] - BI[1][67]);
        7'd46: sad[0] <= (BI[0][46] < BI[1][68])? sad[0] + (BI[1][68] - BI[0][46]):sad[0] + (BI[0][46] - BI[1][68]);
        7'd47: sad[0] <= (BI[0][47] < BI[1][69])? sad[0] + (BI[1][69] - BI[0][47]):sad[0] + (BI[0][47] - BI[1][69]);
        7'd59: sad[0] <= (BI[0][59] < BI[1][77])? sad[0] + (BI[1][77] - BI[0][59]):sad[0] + (BI[0][59] - BI[1][77]);
        7'd58: sad[0] <= (BI[0][58] < BI[1][76])? sad[0] + (BI[1][76] - BI[0][58]):sad[0] + (BI[0][58] - BI[1][76]);
        7'd57: sad[0] <= (BI[0][57] < BI[1][75])? sad[0] + (BI[1][75] - BI[0][57]):sad[0] + (BI[0][57] - BI[1][75]);
        7'd56: sad[0] <= (BI[0][56] < BI[1][74])? sad[0] + (BI[1][74] - BI[0][56]):sad[0] + (BI[0][56] - BI[1][74]);
        7'd55: sad[0] <= (BI[0][55] < BI[1][73])? sad[0] + (BI[1][73] - BI[0][55]):sad[0] + (BI[0][55] - BI[1][73]);
        7'd54: sad[0] <= (BI[0][54] < BI[1][72])? sad[0] + (BI[1][72] - BI[0][54]):sad[0] + (BI[0][54] - BI[1][72]);
        7'd53: sad[0] <= (BI[0][53] < BI[1][71])? sad[0] + (BI[1][71] - BI[0][53]):sad[0] + (BI[0][53] - BI[1][71]);
        7'd52: sad[0] <= (BI[0][52] < BI[1][70])? sad[0] + (BI[1][70] - BI[0][52]):sad[0] + (BI[0][52] - BI[1][70]);
        7'd60: sad[0] <= (BI[0][60] < BI[1][82])? sad[0] + (BI[1][82] - BI[0][60]):sad[0] + (BI[0][60] - BI[1][82]);
        7'd61: sad[0] <= (BI[0][61] < BI[1][83])? sad[0] + (BI[1][83] - BI[0][61]):sad[0] + (BI[0][61] - BI[1][83]);
        7'd62: sad[0] <= (BI[0][62] < BI[1][84])? sad[0] + (BI[1][84] - BI[0][62]):sad[0] + (BI[0][62] - BI[1][84]);
        7'd63: sad[0] <= (BI[0][63] < BI[1][85])? sad[0] + (BI[1][85] - BI[0][63]):sad[0] + (BI[0][63] - BI[1][85]);
        7'd64: sad[0] <= (BI[0][64] < BI[1][86])? sad[0] + (BI[1][86] - BI[0][64]):sad[0] + (BI[0][64] - BI[1][86]);
        7'd65: sad[0] <= (BI[0][65] < BI[1][87])? sad[0] + (BI[1][87] - BI[0][65]):sad[0] + (BI[0][65] - BI[1][87]);
        7'd66: sad[0] <= (BI[0][66] < BI[1][88])? sad[0] + (BI[1][88] - BI[0][66]):sad[0] + (BI[0][66] - BI[1][88]);
        7'd67: sad[0] <= (BI[0][67] < BI[1][89])? sad[0] + (BI[1][89] - BI[0][67]):sad[0] + (BI[0][67] - BI[1][89]);
        7'd79: sad[0] <= (BI[0][79] < BI[1][97])? sad[0] + (BI[1][97] - BI[0][79]):sad[0] + (BI[0][79] - BI[1][97]);
        7'd78: sad[0] <= (BI[0][78] < BI[1][96])? sad[0] + (BI[1][96] - BI[0][78]):sad[0] + (BI[0][78] - BI[1][96]);
        7'd77: sad[0] <= (BI[0][77] < BI[1][95])? sad[0] + (BI[1][95] - BI[0][77]):sad[0] + (BI[0][77] - BI[1][95]);
        7'd76: sad[0] <= (BI[0][76] < BI[1][94])? sad[0] + (BI[1][94] - BI[0][76]):sad[0] + (BI[0][76] - BI[1][94]);
        7'd75: sad[0] <= (BI[0][75] < BI[1][93])? sad[0] + (BI[1][93] - BI[0][75]):sad[0] + (BI[0][75] - BI[1][93]);
        7'd74: sad[0] <= (BI[0][74] < BI[1][92])? sad[0] + (BI[1][92] - BI[0][74]):sad[0] + (BI[0][74] - BI[1][92]);
        7'd73: sad[0] <= (BI[0][73] < BI[1][91])? sad[0] + (BI[1][91] - BI[0][73]):sad[0] + (BI[0][73] - BI[1][91]);
        7'd72: sad[0] <= (BI[0][72] < BI[1][90])? sad[0] + (BI[1][90] - BI[0][72]):sad[0] + (BI[0][72] - BI[1][90]);
        default: sad[0] <= sad[0];
    endcase
end
always @(posedge clk) begin
    case (BI_sum_cnt)
        7'd19: sad[1] <= (BI[0][19] < BI[1][17])? sad[1] + (BI[1][17] - BI[0][19]):sad[1] + (BI[0][19] - BI[1][17]);
        7'd18: sad[1] <= (BI[0][18] < BI[1][16])? sad[1] + (BI[1][16] - BI[0][18]):sad[1] + (BI[0][18] - BI[1][16]);
        7'd17: sad[1] <= (BI[0][17] < BI[1][15])? sad[1] + (BI[1][15] - BI[0][17]):sad[1] + (BI[0][17] - BI[1][15]);
        7'd16: sad[1] <= (BI[0][16] < BI[1][14])? sad[1] + (BI[1][14] - BI[0][16]):sad[1] + (BI[0][16] - BI[1][14]);
        7'd15: sad[1] <= (BI[0][15] < BI[1][13])? sad[1] + (BI[1][13] - BI[0][15]):sad[1] + (BI[0][15] - BI[1][13]);
        7'd14: sad[1] <= (BI[0][14] < BI[1][12])? sad[1] + (BI[1][12] - BI[0][14]):sad[1] + (BI[0][14] - BI[1][12]);
        7'd13: sad[1] <= (BI[0][13] < BI[1][11])? sad[1] + (BI[1][11] - BI[0][13]):sad[1] + (BI[0][13] - BI[1][11]);
        7'd12: sad[1] <= (BI[0][12] < BI[1][10])? BI[1][10] - BI[0][12]:BI[0][12] - BI[1][10];
        7'd20: sad[1] <= (BI[0][20] < BI[1][22])? sad[1] + (BI[1][22] - BI[0][20]):sad[1] + (BI[0][20] - BI[1][22]);
        7'd21: sad[1] <= (BI[0][21] < BI[1][23])? sad[1] + (BI[1][23] - BI[0][21]):sad[1] + (BI[0][21] - BI[1][23]);
        7'd22: sad[1] <= (BI[0][22] < BI[1][24])? sad[1] + (BI[1][24] - BI[0][22]):sad[1] + (BI[0][22] - BI[1][24]);
        7'd23: sad[1] <= (BI[0][23] < BI[1][25])? sad[1] + (BI[1][25] - BI[0][23]):sad[1] + (BI[0][23] - BI[1][25]);
        7'd24: sad[1] <= (BI[0][24] < BI[1][26])? sad[1] + (BI[1][26] - BI[0][24]):sad[1] + (BI[0][24] - BI[1][26]);
        7'd25: sad[1] <= (BI[0][25] < BI[1][27])? sad[1] + (BI[1][27] - BI[0][25]):sad[1] + (BI[0][25] - BI[1][27]);
        7'd26: sad[1] <= (BI[0][26] < BI[1][28])? sad[1] + (BI[1][28] - BI[0][26]):sad[1] + (BI[0][26] - BI[1][28]);
        7'd27: sad[1] <= (BI[0][27] < BI[1][29])? sad[1] + (BI[1][29] - BI[0][27]):sad[1] + (BI[0][27] - BI[1][29]);
        7'd39: sad[1] <= (BI[0][39] < BI[1][37])? sad[1] + (BI[1][37] - BI[0][39]):sad[1] + (BI[0][39] - BI[1][37]);
        7'd38: sad[1] <= (BI[0][38] < BI[1][36])? sad[1] + (BI[1][36] - BI[0][38]):sad[1] + (BI[0][38] - BI[1][36]);
        7'd37: sad[1] <= (BI[0][37] < BI[1][35])? sad[1] + (BI[1][35] - BI[0][37]):sad[1] + (BI[0][37] - BI[1][35]);
        7'd36: sad[1] <= (BI[0][36] < BI[1][34])? sad[1] + (BI[1][34] - BI[0][36]):sad[1] + (BI[0][36] - BI[1][34]);
        7'd35: sad[1] <= (BI[0][35] < BI[1][33])? sad[1] + (BI[1][33] - BI[0][35]):sad[1] + (BI[0][35] - BI[1][33]);
        7'd34: sad[1] <= (BI[0][34] < BI[1][32])? sad[1] + (BI[1][32] - BI[0][34]):sad[1] + (BI[0][34] - BI[1][32]);
        7'd33: sad[1] <= (BI[0][33] < BI[1][31])? sad[1] + (BI[1][31] - BI[0][33]):sad[1] + (BI[0][33] - BI[1][31]);
        7'd32: sad[1] <= (BI[0][32] < BI[1][30])? sad[1] + (BI[1][30] - BI[0][32]):sad[1] + (BI[0][32] - BI[1][30]);
        7'd40: sad[1] <= (BI[0][40] < BI[1][42])? sad[1] + (BI[1][42] - BI[0][40]):sad[1] + (BI[0][40] - BI[1][42]);
        7'd41: sad[1] <= (BI[0][41] < BI[1][43])? sad[1] + (BI[1][43] - BI[0][41]):sad[1] + (BI[0][41] - BI[1][43]);
        7'd42: sad[1] <= (BI[0][42] < BI[1][44])? sad[1] + (BI[1][44] - BI[0][42]):sad[1] + (BI[0][42] - BI[1][44]);
        7'd43: sad[1] <= (BI[0][43] < BI[1][45])? sad[1] + (BI[1][45] - BI[0][43]):sad[1] + (BI[0][43] - BI[1][45]);
        7'd44: sad[1] <= (BI[0][44] < BI[1][46])? sad[1] + (BI[1][46] - BI[0][44]):sad[1] + (BI[0][44] - BI[1][46]);
        7'd45: sad[1] <= (BI[0][45] < BI[1][47])? sad[1] + (BI[1][47] - BI[0][45]):sad[1] + (BI[0][45] - BI[1][47]);
        7'd46: sad[1] <= (BI[0][46] < BI[1][48])? sad[1] + (BI[1][48] - BI[0][46]):sad[1] + (BI[0][46] - BI[1][48]);
        7'd47: sad[1] <= (BI[0][47] < BI[1][49])? sad[1] + (BI[1][49] - BI[0][47]):sad[1] + (BI[0][47] - BI[1][49]);
        7'd59: sad[1] <= (BI[0][59] < BI[1][57])? sad[1] + (BI[1][57] - BI[0][59]):sad[1] + (BI[0][59] - BI[1][57]);
        7'd58: sad[1] <= (BI[0][58] < BI[1][56])? sad[1] + (BI[1][56] - BI[0][58]):sad[1] + (BI[0][58] - BI[1][56]);
        7'd57: sad[1] <= (BI[0][57] < BI[1][55])? sad[1] + (BI[1][55] - BI[0][57]):sad[1] + (BI[0][57] - BI[1][55]);
        7'd56: sad[1] <= (BI[0][56] < BI[1][54])? sad[1] + (BI[1][54] - BI[0][56]):sad[1] + (BI[0][56] - BI[1][54]);
        7'd55: sad[1] <= (BI[0][55] < BI[1][53])? sad[1] + (BI[1][53] - BI[0][55]):sad[1] + (BI[0][55] - BI[1][53]);
        7'd54: sad[1] <= (BI[0][54] < BI[1][52])? sad[1] + (BI[1][52] - BI[0][54]):sad[1] + (BI[0][54] - BI[1][52]);
        7'd53: sad[1] <= (BI[0][53] < BI[1][51])? sad[1] + (BI[1][51] - BI[0][53]):sad[1] + (BI[0][53] - BI[1][51]);
        7'd52: sad[1] <= (BI[0][52] < BI[1][50])? sad[1] + (BI[1][50] - BI[0][52]):sad[1] + (BI[0][52] - BI[1][50]);
        7'd60: sad[1] <= (BI[0][60] < BI[1][62])? sad[1] + (BI[1][62] - BI[0][60]):sad[1] + (BI[0][60] - BI[1][62]);
        7'd61: sad[1] <= (BI[0][61] < BI[1][63])? sad[1] + (BI[1][63] - BI[0][61]):sad[1] + (BI[0][61] - BI[1][63]);
        7'd62: sad[1] <= (BI[0][62] < BI[1][64])? sad[1] + (BI[1][64] - BI[0][62]):sad[1] + (BI[0][62] - BI[1][64]);
        7'd63: sad[1] <= (BI[0][63] < BI[1][65])? sad[1] + (BI[1][65] - BI[0][63]):sad[1] + (BI[0][63] - BI[1][65]);
        7'd64: sad[1] <= (BI[0][64] < BI[1][66])? sad[1] + (BI[1][66] - BI[0][64]):sad[1] + (BI[0][64] - BI[1][66]);
        7'd65: sad[1] <= (BI[0][65] < BI[1][67])? sad[1] + (BI[1][67] - BI[0][65]):sad[1] + (BI[0][65] - BI[1][67]);
        7'd66: sad[1] <= (BI[0][66] < BI[1][68])? sad[1] + (BI[1][68] - BI[0][66]):sad[1] + (BI[0][66] - BI[1][68]);
        7'd67: sad[1] <= (BI[0][67] < BI[1][69])? sad[1] + (BI[1][69] - BI[0][67]):sad[1] + (BI[0][67] - BI[1][69]);
        7'd79: sad[1] <= (BI[0][79] < BI[1][77])? sad[1] + (BI[1][77] - BI[0][79]):sad[1] + (BI[0][79] - BI[1][77]);
        7'd78: sad[1] <= (BI[0][78] < BI[1][76])? sad[1] + (BI[1][76] - BI[0][78]):sad[1] + (BI[0][78] - BI[1][76]);
        7'd77: sad[1] <= (BI[0][77] < BI[1][75])? sad[1] + (BI[1][75] - BI[0][77]):sad[1] + (BI[0][77] - BI[1][75]);
        7'd76: sad[1] <= (BI[0][76] < BI[1][74])? sad[1] + (BI[1][74] - BI[0][76]):sad[1] + (BI[0][76] - BI[1][74]);
        7'd75: sad[1] <= (BI[0][75] < BI[1][73])? sad[1] + (BI[1][73] - BI[0][75]):sad[1] + (BI[0][75] - BI[1][73]);
        7'd74: sad[1] <= (BI[0][74] < BI[1][72])? sad[1] + (BI[1][72] - BI[0][74]):sad[1] + (BI[0][74] - BI[1][72]);
        7'd73: sad[1] <= (BI[0][73] < BI[1][71])? sad[1] + (BI[1][71] - BI[0][73]):sad[1] + (BI[0][73] - BI[1][71]);
        7'd72: sad[1] <= (BI[0][72] < BI[1][70])? sad[1] + (BI[1][70] - BI[0][72]):sad[1] + (BI[0][72] - BI[1][70]);
        7'd80: sad[1] <= (BI[0][80] < BI[1][82])? sad[1] + (BI[1][82] - BI[0][80]):sad[1] + (BI[0][80] - BI[1][82]);
        7'd81: sad[1] <= (BI[0][81] < BI[1][83])? sad[1] + (BI[1][83] - BI[0][81]):sad[1] + (BI[0][81] - BI[1][83]);
        7'd82: sad[1] <= (BI[0][82] < BI[1][84])? sad[1] + (BI[1][84] - BI[0][82]):sad[1] + (BI[0][82] - BI[1][84]);
        7'd83: sad[1] <= (BI[0][83] < BI[1][85])? sad[1] + (BI[1][85] - BI[0][83]):sad[1] + (BI[0][83] - BI[1][85]);
        7'd84: sad[1] <= (BI[0][84] < BI[1][86])? sad[1] + (BI[1][86] - BI[0][84]):sad[1] + (BI[0][84] - BI[1][86]);
        7'd85: sad[1] <= (BI[0][85] < BI[1][87])? sad[1] + (BI[1][87] - BI[0][85]):sad[1] + (BI[0][85] - BI[1][87]);
        7'd86: sad[1] <= (BI[0][86] < BI[1][88])? sad[1] + (BI[1][88] - BI[0][86]):sad[1] + (BI[0][86] - BI[1][88]);
        7'd87: sad[1] <= (BI[0][87] < BI[1][89])? sad[1] + (BI[1][89] - BI[0][87]):sad[1] + (BI[0][87] - BI[1][89]);
        default: sad[1] <= sad[1];
    endcase
end
always @(posedge clk) begin
    case (BI_sum_cnt)
        7'd20: sad[2] <= (BI[0][20] < BI[1][2])? BI[1][2] - BI[0][20]:BI[0][20] - BI[1][2];
        7'd21: sad[2] <= (BI[0][21] < BI[1][3])? sad[2] + (BI[1][3] - BI[0][21]):sad[2] + (BI[0][21] - BI[1][3]);
        7'd22: sad[2] <= (BI[0][22] < BI[1][4])? sad[2] + (BI[1][4] - BI[0][22]):sad[2] + (BI[0][22] - BI[1][4]);
        7'd23: sad[2] <= (BI[0][23] < BI[1][5])? sad[2] + (BI[1][5] - BI[0][23]):sad[2] + (BI[0][23] - BI[1][5]);
        7'd24: sad[2] <= (BI[0][24] < BI[1][6])? sad[2] + (BI[1][6] - BI[0][24]):sad[2] + (BI[0][24] - BI[1][6]);
        7'd25: sad[2] <= (BI[0][25] < BI[1][7])? sad[2] + (BI[1][7] - BI[0][25]):sad[2] + (BI[0][25] - BI[1][7]);
        7'd26: sad[2] <= (BI[0][26] < BI[1][8])? sad[2] + (BI[1][8] - BI[0][26]):sad[2] + (BI[0][26] - BI[1][8]);
        7'd27: sad[2] <= (BI[0][27] < BI[1][9])? sad[2] + (BI[1][9] - BI[0][27]):sad[2] + (BI[0][27] - BI[1][9]);
        7'd39: sad[2] <= (BI[0][39] < BI[1][17])? sad[2] + (BI[1][17] - BI[0][39]):sad[2] + (BI[0][39] - BI[1][17]);
        7'd38: sad[2] <= (BI[0][38] < BI[1][16])? sad[2] + (BI[1][16] - BI[0][38]):sad[2] + (BI[0][38] - BI[1][16]);
        7'd37: sad[2] <= (BI[0][37] < BI[1][15])? sad[2] + (BI[1][15] - BI[0][37]):sad[2] + (BI[0][37] - BI[1][15]);
        7'd36: sad[2] <= (BI[0][36] < BI[1][14])? sad[2] + (BI[1][14] - BI[0][36]):sad[2] + (BI[0][36] - BI[1][14]);
        7'd35: sad[2] <= (BI[0][35] < BI[1][13])? sad[2] + (BI[1][13] - BI[0][35]):sad[2] + (BI[0][35] - BI[1][13]);
        7'd34: sad[2] <= (BI[0][34] < BI[1][12])? sad[2] + (BI[1][12] - BI[0][34]):sad[2] + (BI[0][34] - BI[1][12]);
        7'd33: sad[2] <= (BI[0][33] < BI[1][11])? sad[2] + (BI[1][11] - BI[0][33]):sad[2] + (BI[0][33] - BI[1][11]);
        7'd32: sad[2] <= (BI[0][32] < BI[1][10])? sad[2] + (BI[1][10] - BI[0][32]):sad[2] + (BI[0][32] - BI[1][10]);
        7'd40: sad[2] <= (BI[0][40] < BI[1][22])? sad[2] + (BI[1][22] - BI[0][40]):sad[2] + (BI[0][40] - BI[1][22]);
        7'd41: sad[2] <= (BI[0][41] < BI[1][23])? sad[2] + (BI[1][23] - BI[0][41]):sad[2] + (BI[0][41] - BI[1][23]);
        7'd42: sad[2] <= (BI[0][42] < BI[1][24])? sad[2] + (BI[1][24] - BI[0][42]):sad[2] + (BI[0][42] - BI[1][24]);
        7'd43: sad[2] <= (BI[0][43] < BI[1][25])? sad[2] + (BI[1][25] - BI[0][43]):sad[2] + (BI[0][43] - BI[1][25]);
        7'd44: sad[2] <= (BI[0][44] < BI[1][26])? sad[2] + (BI[1][26] - BI[0][44]):sad[2] + (BI[0][44] - BI[1][26]);
        7'd45: sad[2] <= (BI[0][45] < BI[1][27])? sad[2] + (BI[1][27] - BI[0][45]):sad[2] + (BI[0][45] - BI[1][27]);
        7'd46: sad[2] <= (BI[0][46] < BI[1][28])? sad[2] + (BI[1][28] - BI[0][46]):sad[2] + (BI[0][46] - BI[1][28]);
        7'd47: sad[2] <= (BI[0][47] < BI[1][29])? sad[2] + (BI[1][29] - BI[0][47]):sad[2] + (BI[0][47] - BI[1][29]);
        7'd59: sad[2] <= (BI[0][59] < BI[1][37])? sad[2] + (BI[1][37] - BI[0][59]):sad[2] + (BI[0][59] - BI[1][37]);
        7'd58: sad[2] <= (BI[0][58] < BI[1][36])? sad[2] + (BI[1][36] - BI[0][58]):sad[2] + (BI[0][58] - BI[1][36]);
        7'd57: sad[2] <= (BI[0][57] < BI[1][35])? sad[2] + (BI[1][35] - BI[0][57]):sad[2] + (BI[0][57] - BI[1][35]);
        7'd56: sad[2] <= (BI[0][56] < BI[1][34])? sad[2] + (BI[1][34] - BI[0][56]):sad[2] + (BI[0][56] - BI[1][34]);
        7'd55: sad[2] <= (BI[0][55] < BI[1][33])? sad[2] + (BI[1][33] - BI[0][55]):sad[2] + (BI[0][55] - BI[1][33]);
        7'd54: sad[2] <= (BI[0][54] < BI[1][32])? sad[2] + (BI[1][32] - BI[0][54]):sad[2] + (BI[0][54] - BI[1][32]);
        7'd53: sad[2] <= (BI[0][53] < BI[1][31])? sad[2] + (BI[1][31] - BI[0][53]):sad[2] + (BI[0][53] - BI[1][31]);
        7'd52: sad[2] <= (BI[0][52] < BI[1][30])? sad[2] + (BI[1][30] - BI[0][52]):sad[2] + (BI[0][52] - BI[1][30]);
        7'd60: sad[2] <= (BI[0][60] < BI[1][42])? sad[2] + (BI[1][42] - BI[0][60]):sad[2] + (BI[0][60] - BI[1][42]);
        7'd61: sad[2] <= (BI[0][61] < BI[1][43])? sad[2] + (BI[1][43] - BI[0][61]):sad[2] + (BI[0][61] - BI[1][43]);
        7'd62: sad[2] <= (BI[0][62] < BI[1][44])? sad[2] + (BI[1][44] - BI[0][62]):sad[2] + (BI[0][62] - BI[1][44]);
        7'd63: sad[2] <= (BI[0][63] < BI[1][45])? sad[2] + (BI[1][45] - BI[0][63]):sad[2] + (BI[0][63] - BI[1][45]);
        7'd64: sad[2] <= (BI[0][64] < BI[1][46])? sad[2] + (BI[1][46] - BI[0][64]):sad[2] + (BI[0][64] - BI[1][46]);
        7'd65: sad[2] <= (BI[0][65] < BI[1][47])? sad[2] + (BI[1][47] - BI[0][65]):sad[2] + (BI[0][65] - BI[1][47]);
        7'd66: sad[2] <= (BI[0][66] < BI[1][48])? sad[2] + (BI[1][48] - BI[0][66]):sad[2] + (BI[0][66] - BI[1][48]);
        7'd67: sad[2] <= (BI[0][67] < BI[1][49])? sad[2] + (BI[1][49] - BI[0][67]):sad[2] + (BI[0][67] - BI[1][49]);
        7'd79: sad[2] <= (BI[0][79] < BI[1][57])? sad[2] + (BI[1][57] - BI[0][79]):sad[2] + (BI[0][79] - BI[1][57]);
        7'd78: sad[2] <= (BI[0][78] < BI[1][56])? sad[2] + (BI[1][56] - BI[0][78]):sad[2] + (BI[0][78] - BI[1][56]);
        7'd77: sad[2] <= (BI[0][77] < BI[1][55])? sad[2] + (BI[1][55] - BI[0][77]):sad[2] + (BI[0][77] - BI[1][55]);
        7'd76: sad[2] <= (BI[0][76] < BI[1][54])? sad[2] + (BI[1][54] - BI[0][76]):sad[2] + (BI[0][76] - BI[1][54]);
        7'd75: sad[2] <= (BI[0][75] < BI[1][53])? sad[2] + (BI[1][53] - BI[0][75]):sad[2] + (BI[0][75] - BI[1][53]);
        7'd74: sad[2] <= (BI[0][74] < BI[1][52])? sad[2] + (BI[1][52] - BI[0][74]):sad[2] + (BI[0][74] - BI[1][52]);
        7'd73: sad[2] <= (BI[0][73] < BI[1][51])? sad[2] + (BI[1][51] - BI[0][73]):sad[2] + (BI[0][73] - BI[1][51]);
        7'd72: sad[2] <= (BI[0][72] < BI[1][50])? sad[2] + (BI[1][50] - BI[0][72]):sad[2] + (BI[0][72] - BI[1][50]);
        7'd80: sad[2] <= (BI[0][80] < BI[1][62])? sad[2] + (BI[1][62] - BI[0][80]):sad[2] + (BI[0][80] - BI[1][62]);
        7'd81: sad[2] <= (BI[0][81] < BI[1][63])? sad[2] + (BI[1][63] - BI[0][81]):sad[2] + (BI[0][81] - BI[1][63]);
        7'd82: sad[2] <= (BI[0][82] < BI[1][64])? sad[2] + (BI[1][64] - BI[0][82]):sad[2] + (BI[0][82] - BI[1][64]);
        7'd83: sad[2] <= (BI[0][83] < BI[1][65])? sad[2] + (BI[1][65] - BI[0][83]):sad[2] + (BI[0][83] - BI[1][65]);
        7'd84: sad[2] <= (BI[0][84] < BI[1][66])? sad[2] + (BI[1][66] - BI[0][84]):sad[2] + (BI[0][84] - BI[1][66]);
        7'd85: sad[2] <= (BI[0][85] < BI[1][67])? sad[2] + (BI[1][67] - BI[0][85]):sad[2] + (BI[0][85] - BI[1][67]);
        7'd86: sad[2] <= (BI[0][86] < BI[1][68])? sad[2] + (BI[1][68] - BI[0][86]):sad[2] + (BI[0][86] - BI[1][68]);
        7'd87: sad[2] <= (BI[0][87] < BI[1][69])? sad[2] + (BI[1][69] - BI[0][87]):sad[2] + (BI[0][87] - BI[1][69]);
        7'd99: sad[2] <= (BI[0][99] < BI[1][77])? sad[2] + (BI[1][77] - BI[0][99]):sad[2] + (BI[0][99] - BI[1][77]);
        7'd98: sad[2] <= (BI[0][98] < BI[1][76])? sad[2] + (BI[1][76] - BI[0][98]):sad[2] + (BI[0][98] - BI[1][76]);
        7'd97: sad[2] <= (BI[0][97] < BI[1][75])? sad[2] + (BI[1][75] - BI[0][97]):sad[2] + (BI[0][97] - BI[1][75]);
        7'd96: sad[2] <= (BI[0][96] < BI[1][74])? sad[2] + (BI[1][74] - BI[0][96]):sad[2] + (BI[0][96] - BI[1][74]);
        7'd95: sad[2] <= (BI[0][95] < BI[1][73])? sad[2] + (BI[1][73] - BI[0][95]):sad[2] + (BI[0][95] - BI[1][73]);
        7'd94: sad[2] <= (BI[0][94] < BI[1][72])? sad[2] + (BI[1][72] - BI[0][94]):sad[2] + (BI[0][94] - BI[1][72]);
        7'd93: sad[2] <= (BI[0][93] < BI[1][71])? sad[2] + (BI[1][71] - BI[0][93]):sad[2] + (BI[0][93] - BI[1][71]);
        7'd92: sad[2] <= (BI[0][92] < BI[1][70])? sad[2] + (BI[1][70] - BI[0][92]):sad[2] + (BI[0][92] - BI[1][70]);
        default: sad[2] <= sad[2];
    endcase
end
always @(posedge clk) begin
    case (BI_sum_cnt)
        7'd1: sad[3] <= (BI[0][1] < BI[1][21])? BI[1][21] - BI[0][1]:BI[0][1] - BI[1][21];
        7'd2: sad[3] <= (BI[0][2] < BI[1][22])? sad[3] + (BI[1][22] - BI[0][2]):sad[3] + (BI[0][2] - BI[1][22]);
        7'd3: sad[3] <= (BI[0][3] < BI[1][23])? sad[3] + (BI[1][23] - BI[0][3]):sad[3] + (BI[0][3] - BI[1][23]);
        7'd4: sad[3] <= (BI[0][4] < BI[1][24])? sad[3] + (BI[1][24] - BI[0][4]):sad[3] + (BI[0][4] - BI[1][24]);
        7'd5: sad[3] <= (BI[0][5] < BI[1][25])? sad[3] + (BI[1][25] - BI[0][5]):sad[3] + (BI[0][5] - BI[1][25]);
        7'd6: sad[3] <= (BI[0][6] < BI[1][26])? sad[3] + (BI[1][26] - BI[0][6]):sad[3] + (BI[0][6] - BI[1][26]);
        7'd7: sad[3] <= (BI[0][7] < BI[1][27])? sad[3] + (BI[1][27] - BI[0][7]):sad[3] + (BI[0][7] - BI[1][27]);
        7'd8: sad[3] <= (BI[0][8] < BI[1][28])? sad[3] + (BI[1][28] - BI[0][8]):sad[3] + (BI[0][8] - BI[1][28]);
        7'd18: sad[3] <= (BI[0][18] < BI[1][38])? sad[3] + (BI[1][38] - BI[0][18]):sad[3] + (BI[0][18] - BI[1][38]);
        7'd17: sad[3] <= (BI[0][17] < BI[1][37])? sad[3] + (BI[1][37] - BI[0][17]):sad[3] + (BI[0][17] - BI[1][37]);
        7'd16: sad[3] <= (BI[0][16] < BI[1][36])? sad[3] + (BI[1][36] - BI[0][16]):sad[3] + (BI[0][16] - BI[1][36]);
        7'd15: sad[3] <= (BI[0][15] < BI[1][35])? sad[3] + (BI[1][35] - BI[0][15]):sad[3] + (BI[0][15] - BI[1][35]);
        7'd14: sad[3] <= (BI[0][14] < BI[1][34])? sad[3] + (BI[1][34] - BI[0][14]):sad[3] + (BI[0][14] - BI[1][34]);
        7'd13: sad[3] <= (BI[0][13] < BI[1][33])? sad[3] + (BI[1][33] - BI[0][13]):sad[3] + (BI[0][13] - BI[1][33]);
        7'd12: sad[3] <= (BI[0][12] < BI[1][32])? sad[3] + (BI[1][32] - BI[0][12]):sad[3] + (BI[0][12] - BI[1][32]);
        7'd11: sad[3] <= (BI[0][11] < BI[1][31])? sad[3] + (BI[1][31] - BI[0][11]):sad[3] + (BI[0][11] - BI[1][31]);
        7'd21: sad[3] <= (BI[0][21] < BI[1][41])? sad[3] + (BI[1][41] - BI[0][21]):sad[3] + (BI[0][21] - BI[1][41]);
        7'd22: sad[3] <= (BI[0][22] < BI[1][42])? sad[3] + (BI[1][42] - BI[0][22]):sad[3] + (BI[0][22] - BI[1][42]);
        7'd23: sad[3] <= (BI[0][23] < BI[1][43])? sad[3] + (BI[1][43] - BI[0][23]):sad[3] + (BI[0][23] - BI[1][43]);
        7'd24: sad[3] <= (BI[0][24] < BI[1][44])? sad[3] + (BI[1][44] - BI[0][24]):sad[3] + (BI[0][24] - BI[1][44]);
        7'd25: sad[3] <= (BI[0][25] < BI[1][45])? sad[3] + (BI[1][45] - BI[0][25]):sad[3] + (BI[0][25] - BI[1][45]);
        7'd26: sad[3] <= (BI[0][26] < BI[1][46])? sad[3] + (BI[1][46] - BI[0][26]):sad[3] + (BI[0][26] - BI[1][46]);
        7'd27: sad[3] <= (BI[0][27] < BI[1][47])? sad[3] + (BI[1][47] - BI[0][27]):sad[3] + (BI[0][27] - BI[1][47]);
        7'd28: sad[3] <= (BI[0][28] < BI[1][48])? sad[3] + (BI[1][48] - BI[0][28]):sad[3] + (BI[0][28] - BI[1][48]);
        7'd38: sad[3] <= (BI[0][38] < BI[1][58])? sad[3] + (BI[1][58] - BI[0][38]):sad[3] + (BI[0][38] - BI[1][58]);
        7'd37: sad[3] <= (BI[0][37] < BI[1][57])? sad[3] + (BI[1][57] - BI[0][37]):sad[3] + (BI[0][37] - BI[1][57]);
        7'd36: sad[3] <= (BI[0][36] < BI[1][56])? sad[3] + (BI[1][56] - BI[0][36]):sad[3] + (BI[0][36] - BI[1][56]);
        7'd35: sad[3] <= (BI[0][35] < BI[1][55])? sad[3] + (BI[1][55] - BI[0][35]):sad[3] + (BI[0][35] - BI[1][55]);
        7'd34: sad[3] <= (BI[0][34] < BI[1][54])? sad[3] + (BI[1][54] - BI[0][34]):sad[3] + (BI[0][34] - BI[1][54]);
        7'd33: sad[3] <= (BI[0][33] < BI[1][53])? sad[3] + (BI[1][53] - BI[0][33]):sad[3] + (BI[0][33] - BI[1][53]);
        7'd32: sad[3] <= (BI[0][32] < BI[1][52])? sad[3] + (BI[1][52] - BI[0][32]):sad[3] + (BI[0][32] - BI[1][52]);
        7'd31: sad[3] <= (BI[0][31] < BI[1][51])? sad[3] + (BI[1][51] - BI[0][31]):sad[3] + (BI[0][31] - BI[1][51]);
        7'd41: sad[3] <= (BI[0][41] < BI[1][61])? sad[3] + (BI[1][61] - BI[0][41]):sad[3] + (BI[0][41] - BI[1][61]);
        7'd42: sad[3] <= (BI[0][42] < BI[1][62])? sad[3] + (BI[1][62] - BI[0][42]):sad[3] + (BI[0][42] - BI[1][62]);
        7'd43: sad[3] <= (BI[0][43] < BI[1][63])? sad[3] + (BI[1][63] - BI[0][43]):sad[3] + (BI[0][43] - BI[1][63]);
        7'd44: sad[3] <= (BI[0][44] < BI[1][64])? sad[3] + (BI[1][64] - BI[0][44]):sad[3] + (BI[0][44] - BI[1][64]);
        7'd45: sad[3] <= (BI[0][45] < BI[1][65])? sad[3] + (BI[1][65] - BI[0][45]):sad[3] + (BI[0][45] - BI[1][65]);
        7'd46: sad[3] <= (BI[0][46] < BI[1][66])? sad[3] + (BI[1][66] - BI[0][46]):sad[3] + (BI[0][46] - BI[1][66]);
        7'd47: sad[3] <= (BI[0][47] < BI[1][67])? sad[3] + (BI[1][67] - BI[0][47]):sad[3] + (BI[0][47] - BI[1][67]);
        7'd48: sad[3] <= (BI[0][48] < BI[1][68])? sad[3] + (BI[1][68] - BI[0][48]):sad[3] + (BI[0][48] - BI[1][68]);
        7'd58: sad[3] <= (BI[0][58] < BI[1][78])? sad[3] + (BI[1][78] - BI[0][58]):sad[3] + (BI[0][58] - BI[1][78]);
        7'd57: sad[3] <= (BI[0][57] < BI[1][77])? sad[3] + (BI[1][77] - BI[0][57]):sad[3] + (BI[0][57] - BI[1][77]);
        7'd56: sad[3] <= (BI[0][56] < BI[1][76])? sad[3] + (BI[1][76] - BI[0][56]):sad[3] + (BI[0][56] - BI[1][76]);
        7'd55: sad[3] <= (BI[0][55] < BI[1][75])? sad[3] + (BI[1][75] - BI[0][55]):sad[3] + (BI[0][55] - BI[1][75]);
        7'd54: sad[3] <= (BI[0][54] < BI[1][74])? sad[3] + (BI[1][74] - BI[0][54]):sad[3] + (BI[0][54] - BI[1][74]);
        7'd53: sad[3] <= (BI[0][53] < BI[1][73])? sad[3] + (BI[1][73] - BI[0][53]):sad[3] + (BI[0][53] - BI[1][73]);
        7'd52: sad[3] <= (BI[0][52] < BI[1][72])? sad[3] + (BI[1][72] - BI[0][52]):sad[3] + (BI[0][52] - BI[1][72]);
        7'd51: sad[3] <= (BI[0][51] < BI[1][71])? sad[3] + (BI[1][71] - BI[0][51]):sad[3] + (BI[0][51] - BI[1][71]);
        7'd61: sad[3] <= (BI[0][61] < BI[1][81])? sad[3] + (BI[1][81] - BI[0][61]):sad[3] + (BI[0][61] - BI[1][81]);
        7'd62: sad[3] <= (BI[0][62] < BI[1][82])? sad[3] + (BI[1][82] - BI[0][62]):sad[3] + (BI[0][62] - BI[1][82]);
        7'd63: sad[3] <= (BI[0][63] < BI[1][83])? sad[3] + (BI[1][83] - BI[0][63]):sad[3] + (BI[0][63] - BI[1][83]);
        7'd64: sad[3] <= (BI[0][64] < BI[1][84])? sad[3] + (BI[1][84] - BI[0][64]):sad[3] + (BI[0][64] - BI[1][84]);
        7'd65: sad[3] <= (BI[0][65] < BI[1][85])? sad[3] + (BI[1][85] - BI[0][65]):sad[3] + (BI[0][65] - BI[1][85]);
        7'd66: sad[3] <= (BI[0][66] < BI[1][86])? sad[3] + (BI[1][86] - BI[0][66]):sad[3] + (BI[0][66] - BI[1][86]);
        7'd67: sad[3] <= (BI[0][67] < BI[1][87])? sad[3] + (BI[1][87] - BI[0][67]):sad[3] + (BI[0][67] - BI[1][87]);
        7'd68: sad[3] <= (BI[0][68] < BI[1][88])? sad[3] + (BI[1][88] - BI[0][68]):sad[3] + (BI[0][68] - BI[1][88]);
        7'd78: sad[3] <= (BI[0][78] < BI[1][98])? sad[3] + (BI[1][98] - BI[0][78]):sad[3] + (BI[0][78] - BI[1][98]);
        7'd77: sad[3] <= (BI[0][77] < BI[1][97])? sad[3] + (BI[1][97] - BI[0][77]):sad[3] + (BI[0][77] - BI[1][97]);
        7'd76: sad[3] <= (BI[0][76] < BI[1][96])? sad[3] + (BI[1][96] - BI[0][76]):sad[3] + (BI[0][76] - BI[1][96]);
        7'd75: sad[3] <= (BI[0][75] < BI[1][95])? sad[3] + (BI[1][95] - BI[0][75]):sad[3] + (BI[0][75] - BI[1][95]);
        7'd74: sad[3] <= (BI[0][74] < BI[1][94])? sad[3] + (BI[1][94] - BI[0][74]):sad[3] + (BI[0][74] - BI[1][94]);
        7'd73: sad[3] <= (BI[0][73] < BI[1][93])? sad[3] + (BI[1][93] - BI[0][73]):sad[3] + (BI[0][73] - BI[1][93]);
        7'd72: sad[3] <= (BI[0][72] < BI[1][92])? sad[3] + (BI[1][92] - BI[0][72]):sad[3] + (BI[0][72] - BI[1][92]);
        7'd71: sad[3] <= (BI[0][71] < BI[1][91])? sad[3] + (BI[1][91] - BI[0][71]):sad[3] + (BI[0][71] - BI[1][91]);
        default: sad[3] <= sad[3];
    endcase
end
always @(posedge clk) begin
    case (BI_sum_cnt)
        7'd18: sad[4] <= (BI[0][18] < BI[1][18])? sad[4] + (BI[1][18] - BI[0][18]):sad[4] + (BI[0][18] - BI[1][18]);
        7'd17: sad[4] <= (BI[0][17] < BI[1][17])? sad[4] + (BI[1][17] - BI[0][17]):sad[4] + (BI[0][17] - BI[1][17]);
        7'd16: sad[4] <= (BI[0][16] < BI[1][16])? sad[4] + (BI[1][16] - BI[0][16]):sad[4] + (BI[0][16] - BI[1][16]);
        7'd15: sad[4] <= (BI[0][15] < BI[1][15])? sad[4] + (BI[1][15] - BI[0][15]):sad[4] + (BI[0][15] - BI[1][15]);
        7'd14: sad[4] <= (BI[0][14] < BI[1][14])? sad[4] + (BI[1][14] - BI[0][14]):sad[4] + (BI[0][14] - BI[1][14]);
        7'd13: sad[4] <= (BI[0][13] < BI[1][13])? sad[4] + (BI[1][13] - BI[0][13]):sad[4] + (BI[0][13] - BI[1][13]);
        7'd12: sad[4] <= (BI[0][12] < BI[1][12])? sad[4] + (BI[1][12] - BI[0][12]):sad[4] + (BI[0][12] - BI[1][12]);
        7'd11: sad[4] <= (BI[0][11] < BI[1][11])? BI[1][11] - BI[0][11]:BI[0][11] - BI[1][11];
        7'd21: sad[4] <= (BI[0][21] < BI[1][21])? sad[4] + (BI[1][21] - BI[0][21]):sad[4] + (BI[0][21] - BI[1][21]);
        7'd22: sad[4] <= (BI[0][22] < BI[1][22])? sad[4] + (BI[1][22] - BI[0][22]):sad[4] + (BI[0][22] - BI[1][22]);
        7'd23: sad[4] <= (BI[0][23] < BI[1][23])? sad[4] + (BI[1][23] - BI[0][23]):sad[4] + (BI[0][23] - BI[1][23]);
        7'd24: sad[4] <= (BI[0][24] < BI[1][24])? sad[4] + (BI[1][24] - BI[0][24]):sad[4] + (BI[0][24] - BI[1][24]);
        7'd25: sad[4] <= (BI[0][25] < BI[1][25])? sad[4] + (BI[1][25] - BI[0][25]):sad[4] + (BI[0][25] - BI[1][25]);
        7'd26: sad[4] <= (BI[0][26] < BI[1][26])? sad[4] + (BI[1][26] - BI[0][26]):sad[4] + (BI[0][26] - BI[1][26]);
        7'd27: sad[4] <= (BI[0][27] < BI[1][27])? sad[4] + (BI[1][27] - BI[0][27]):sad[4] + (BI[0][27] - BI[1][27]);
        7'd28: sad[4] <= (BI[0][28] < BI[1][28])? sad[4] + (BI[1][28] - BI[0][28]):sad[4] + (BI[0][28] - BI[1][28]);
        7'd38: sad[4] <= (BI[0][38] < BI[1][38])? sad[4] + (BI[1][38] - BI[0][38]):sad[4] + (BI[0][38] - BI[1][38]);
        7'd37: sad[4] <= (BI[0][37] < BI[1][37])? sad[4] + (BI[1][37] - BI[0][37]):sad[4] + (BI[0][37] - BI[1][37]);
        7'd36: sad[4] <= (BI[0][36] < BI[1][36])? sad[4] + (BI[1][36] - BI[0][36]):sad[4] + (BI[0][36] - BI[1][36]);
        7'd35: sad[4] <= (BI[0][35] < BI[1][35])? sad[4] + (BI[1][35] - BI[0][35]):sad[4] + (BI[0][35] - BI[1][35]);
        7'd34: sad[4] <= (BI[0][34] < BI[1][34])? sad[4] + (BI[1][34] - BI[0][34]):sad[4] + (BI[0][34] - BI[1][34]);
        7'd33: sad[4] <= (BI[0][33] < BI[1][33])? sad[4] + (BI[1][33] - BI[0][33]):sad[4] + (BI[0][33] - BI[1][33]);
        7'd32: sad[4] <= (BI[0][32] < BI[1][32])? sad[4] + (BI[1][32] - BI[0][32]):sad[4] + (BI[0][32] - BI[1][32]);
        7'd31: sad[4] <= (BI[0][31] < BI[1][31])? sad[4] + (BI[1][31] - BI[0][31]):sad[4] + (BI[0][31] - BI[1][31]);
        7'd41: sad[4] <= (BI[0][41] < BI[1][41])? sad[4] + (BI[1][41] - BI[0][41]):sad[4] + (BI[0][41] - BI[1][41]);
        7'd42: sad[4] <= (BI[0][42] < BI[1][42])? sad[4] + (BI[1][42] - BI[0][42]):sad[4] + (BI[0][42] - BI[1][42]);
        7'd43: sad[4] <= (BI[0][43] < BI[1][43])? sad[4] + (BI[1][43] - BI[0][43]):sad[4] + (BI[0][43] - BI[1][43]);
        7'd44: sad[4] <= (BI[0][44] < BI[1][44])? sad[4] + (BI[1][44] - BI[0][44]):sad[4] + (BI[0][44] - BI[1][44]);
        7'd45: sad[4] <= (BI[0][45] < BI[1][45])? sad[4] + (BI[1][45] - BI[0][45]):sad[4] + (BI[0][45] - BI[1][45]);
        7'd46: sad[4] <= (BI[0][46] < BI[1][46])? sad[4] + (BI[1][46] - BI[0][46]):sad[4] + (BI[0][46] - BI[1][46]);
        7'd47: sad[4] <= (BI[0][47] < BI[1][47])? sad[4] + (BI[1][47] - BI[0][47]):sad[4] + (BI[0][47] - BI[1][47]);
        7'd48: sad[4] <= (BI[0][48] < BI[1][48])? sad[4] + (BI[1][48] - BI[0][48]):sad[4] + (BI[0][48] - BI[1][48]);
        7'd58: sad[4] <= (BI[0][58] < BI[1][58])? sad[4] + (BI[1][58] - BI[0][58]):sad[4] + (BI[0][58] - BI[1][58]);
        7'd57: sad[4] <= (BI[0][57] < BI[1][57])? sad[4] + (BI[1][57] - BI[0][57]):sad[4] + (BI[0][57] - BI[1][57]);
        7'd56: sad[4] <= (BI[0][56] < BI[1][56])? sad[4] + (BI[1][56] - BI[0][56]):sad[4] + (BI[0][56] - BI[1][56]);
        7'd55: sad[4] <= (BI[0][55] < BI[1][55])? sad[4] + (BI[1][55] - BI[0][55]):sad[4] + (BI[0][55] - BI[1][55]);
        7'd54: sad[4] <= (BI[0][54] < BI[1][54])? sad[4] + (BI[1][54] - BI[0][54]):sad[4] + (BI[0][54] - BI[1][54]);
        7'd53: sad[4] <= (BI[0][53] < BI[1][53])? sad[4] + (BI[1][53] - BI[0][53]):sad[4] + (BI[0][53] - BI[1][53]);
        7'd52: sad[4] <= (BI[0][52] < BI[1][52])? sad[4] + (BI[1][52] - BI[0][52]):sad[4] + (BI[0][52] - BI[1][52]);
        7'd51: sad[4] <= (BI[0][51] < BI[1][51])? sad[4] + (BI[1][51] - BI[0][51]):sad[4] + (BI[0][51] - BI[1][51]);
        7'd61: sad[4] <= (BI[0][61] < BI[1][61])? sad[4] + (BI[1][61] - BI[0][61]):sad[4] + (BI[0][61] - BI[1][61]);
        7'd62: sad[4] <= (BI[0][62] < BI[1][62])? sad[4] + (BI[1][62] - BI[0][62]):sad[4] + (BI[0][62] - BI[1][62]);
        7'd63: sad[4] <= (BI[0][63] < BI[1][63])? sad[4] + (BI[1][63] - BI[0][63]):sad[4] + (BI[0][63] - BI[1][63]);
        7'd64: sad[4] <= (BI[0][64] < BI[1][64])? sad[4] + (BI[1][64] - BI[0][64]):sad[4] + (BI[0][64] - BI[1][64]);
        7'd65: sad[4] <= (BI[0][65] < BI[1][65])? sad[4] + (BI[1][65] - BI[0][65]):sad[4] + (BI[0][65] - BI[1][65]);
        7'd66: sad[4] <= (BI[0][66] < BI[1][66])? sad[4] + (BI[1][66] - BI[0][66]):sad[4] + (BI[0][66] - BI[1][66]);
        7'd67: sad[4] <= (BI[0][67] < BI[1][67])? sad[4] + (BI[1][67] - BI[0][67]):sad[4] + (BI[0][67] - BI[1][67]);
        7'd68: sad[4] <= (BI[0][68] < BI[1][68])? sad[4] + (BI[1][68] - BI[0][68]):sad[4] + (BI[0][68] - BI[1][68]);
        7'd78: sad[4] <= (BI[0][78] < BI[1][78])? sad[4] + (BI[1][78] - BI[0][78]):sad[4] + (BI[0][78] - BI[1][78]);
        7'd77: sad[4] <= (BI[0][77] < BI[1][77])? sad[4] + (BI[1][77] - BI[0][77]):sad[4] + (BI[0][77] - BI[1][77]);
        7'd76: sad[4] <= (BI[0][76] < BI[1][76])? sad[4] + (BI[1][76] - BI[0][76]):sad[4] + (BI[0][76] - BI[1][76]);
        7'd75: sad[4] <= (BI[0][75] < BI[1][75])? sad[4] + (BI[1][75] - BI[0][75]):sad[4] + (BI[0][75] - BI[1][75]);
        7'd74: sad[4] <= (BI[0][74] < BI[1][74])? sad[4] + (BI[1][74] - BI[0][74]):sad[4] + (BI[0][74] - BI[1][74]);
        7'd73: sad[4] <= (BI[0][73] < BI[1][73])? sad[4] + (BI[1][73] - BI[0][73]):sad[4] + (BI[0][73] - BI[1][73]);
        7'd72: sad[4] <= (BI[0][72] < BI[1][72])? sad[4] + (BI[1][72] - BI[0][72]):sad[4] + (BI[0][72] - BI[1][72]);
        7'd71: sad[4] <= (BI[0][71] < BI[1][71])? sad[4] + (BI[1][71] - BI[0][71]):sad[4] + (BI[0][71] - BI[1][71]);
        7'd81: sad[4] <= (BI[0][81] < BI[1][81])? sad[4] + (BI[1][81] - BI[0][81]):sad[4] + (BI[0][81] - BI[1][81]);
        7'd82: sad[4] <= (BI[0][82] < BI[1][82])? sad[4] + (BI[1][82] - BI[0][82]):sad[4] + (BI[0][82] - BI[1][82]);
        7'd83: sad[4] <= (BI[0][83] < BI[1][83])? sad[4] + (BI[1][83] - BI[0][83]):sad[4] + (BI[0][83] - BI[1][83]);
        7'd84: sad[4] <= (BI[0][84] < BI[1][84])? sad[4] + (BI[1][84] - BI[0][84]):sad[4] + (BI[0][84] - BI[1][84]);
        7'd85: sad[4] <= (BI[0][85] < BI[1][85])? sad[4] + (BI[1][85] - BI[0][85]):sad[4] + (BI[0][85] - BI[1][85]);
        7'd86: sad[4] <= (BI[0][86] < BI[1][86])? sad[4] + (BI[1][86] - BI[0][86]):sad[4] + (BI[0][86] - BI[1][86]);
        7'd87: sad[4] <= (BI[0][87] < BI[1][87])? sad[4] + (BI[1][87] - BI[0][87]):sad[4] + (BI[0][87] - BI[1][87]);
        7'd88: sad[4] <= (BI[0][88] < BI[1][88])? sad[4] + (BI[1][88] - BI[0][88]):sad[4] + (BI[0][88] - BI[1][88]);
        default: sad[4] <= sad[4];
    endcase
end
always @(posedge clk) begin
    case (BI_sum_cnt)
        7'd21: sad[5] <= (BI[0][21] < BI[1][1])? BI[1][1] - BI[0][21]:BI[0][21] - BI[1][1];
        7'd22: sad[5] <= (BI[0][22] < BI[1][2])? sad[5] + (BI[1][2] - BI[0][22]):sad[5] + (BI[0][22] - BI[1][2]);
        7'd23: sad[5] <= (BI[0][23] < BI[1][3])? sad[5] + (BI[1][3] - BI[0][23]):sad[5] + (BI[0][23] - BI[1][3]);
        7'd24: sad[5] <= (BI[0][24] < BI[1][4])? sad[5] + (BI[1][4] - BI[0][24]):sad[5] + (BI[0][24] - BI[1][4]);
        7'd25: sad[5] <= (BI[0][25] < BI[1][5])? sad[5] + (BI[1][5] - BI[0][25]):sad[5] + (BI[0][25] - BI[1][5]);
        7'd26: sad[5] <= (BI[0][26] < BI[1][6])? sad[5] + (BI[1][6] - BI[0][26]):sad[5] + (BI[0][26] - BI[1][6]);
        7'd27: sad[5] <= (BI[0][27] < BI[1][7])? sad[5] + (BI[1][7] - BI[0][27]):sad[5] + (BI[0][27] - BI[1][7]);
        7'd28: sad[5] <= (BI[0][28] < BI[1][8])? sad[5] + (BI[1][8] - BI[0][28]):sad[5] + (BI[0][28] - BI[1][8]);
        7'd38: sad[5] <= (BI[0][38] < BI[1][18])? sad[5] + (BI[1][18] - BI[0][38]):sad[5] + (BI[0][38] - BI[1][18]);
        7'd37: sad[5] <= (BI[0][37] < BI[1][17])? sad[5] + (BI[1][17] - BI[0][37]):sad[5] + (BI[0][37] - BI[1][17]);
        7'd36: sad[5] <= (BI[0][36] < BI[1][16])? sad[5] + (BI[1][16] - BI[0][36]):sad[5] + (BI[0][36] - BI[1][16]);
        7'd35: sad[5] <= (BI[0][35] < BI[1][15])? sad[5] + (BI[1][15] - BI[0][35]):sad[5] + (BI[0][35] - BI[1][15]);
        7'd34: sad[5] <= (BI[0][34] < BI[1][14])? sad[5] + (BI[1][14] - BI[0][34]):sad[5] + (BI[0][34] - BI[1][14]);
        7'd33: sad[5] <= (BI[0][33] < BI[1][13])? sad[5] + (BI[1][13] - BI[0][33]):sad[5] + (BI[0][33] - BI[1][13]);
        7'd32: sad[5] <= (BI[0][32] < BI[1][12])? sad[5] + (BI[1][12] - BI[0][32]):sad[5] + (BI[0][32] - BI[1][12]);
        7'd31: sad[5] <= (BI[0][31] < BI[1][11])? sad[5] + (BI[1][11] - BI[0][31]):sad[5] + (BI[0][31] - BI[1][11]);
        7'd41: sad[5] <= (BI[0][41] < BI[1][21])? sad[5] + (BI[1][21] - BI[0][41]):sad[5] + (BI[0][41] - BI[1][21]);
        7'd42: sad[5] <= (BI[0][42] < BI[1][22])? sad[5] + (BI[1][22] - BI[0][42]):sad[5] + (BI[0][42] - BI[1][22]);
        7'd43: sad[5] <= (BI[0][43] < BI[1][23])? sad[5] + (BI[1][23] - BI[0][43]):sad[5] + (BI[0][43] - BI[1][23]);
        7'd44: sad[5] <= (BI[0][44] < BI[1][24])? sad[5] + (BI[1][24] - BI[0][44]):sad[5] + (BI[0][44] - BI[1][24]);
        7'd45: sad[5] <= (BI[0][45] < BI[1][25])? sad[5] + (BI[1][25] - BI[0][45]):sad[5] + (BI[0][45] - BI[1][25]);
        7'd46: sad[5] <= (BI[0][46] < BI[1][26])? sad[5] + (BI[1][26] - BI[0][46]):sad[5] + (BI[0][46] - BI[1][26]);
        7'd47: sad[5] <= (BI[0][47] < BI[1][27])? sad[5] + (BI[1][27] - BI[0][47]):sad[5] + (BI[0][47] - BI[1][27]);
        7'd48: sad[5] <= (BI[0][48] < BI[1][28])? sad[5] + (BI[1][28] - BI[0][48]):sad[5] + (BI[0][48] - BI[1][28]);
        7'd58: sad[5] <= (BI[0][58] < BI[1][38])? sad[5] + (BI[1][38] - BI[0][58]):sad[5] + (BI[0][58] - BI[1][38]);
        7'd57: sad[5] <= (BI[0][57] < BI[1][37])? sad[5] + (BI[1][37] - BI[0][57]):sad[5] + (BI[0][57] - BI[1][37]);
        7'd56: sad[5] <= (BI[0][56] < BI[1][36])? sad[5] + (BI[1][36] - BI[0][56]):sad[5] + (BI[0][56] - BI[1][36]);
        7'd55: sad[5] <= (BI[0][55] < BI[1][35])? sad[5] + (BI[1][35] - BI[0][55]):sad[5] + (BI[0][55] - BI[1][35]);
        7'd54: sad[5] <= (BI[0][54] < BI[1][34])? sad[5] + (BI[1][34] - BI[0][54]):sad[5] + (BI[0][54] - BI[1][34]);
        7'd53: sad[5] <= (BI[0][53] < BI[1][33])? sad[5] + (BI[1][33] - BI[0][53]):sad[5] + (BI[0][53] - BI[1][33]);
        7'd52: sad[5] <= (BI[0][52] < BI[1][32])? sad[5] + (BI[1][32] - BI[0][52]):sad[5] + (BI[0][52] - BI[1][32]);
        7'd51: sad[5] <= (BI[0][51] < BI[1][31])? sad[5] + (BI[1][31] - BI[0][51]):sad[5] + (BI[0][51] - BI[1][31]);
        7'd61: sad[5] <= (BI[0][61] < BI[1][41])? sad[5] + (BI[1][41] - BI[0][61]):sad[5] + (BI[0][61] - BI[1][41]);
        7'd62: sad[5] <= (BI[0][62] < BI[1][42])? sad[5] + (BI[1][42] - BI[0][62]):sad[5] + (BI[0][62] - BI[1][42]);
        7'd63: sad[5] <= (BI[0][63] < BI[1][43])? sad[5] + (BI[1][43] - BI[0][63]):sad[5] + (BI[0][63] - BI[1][43]);
        7'd64: sad[5] <= (BI[0][64] < BI[1][44])? sad[5] + (BI[1][44] - BI[0][64]):sad[5] + (BI[0][64] - BI[1][44]);
        7'd65: sad[5] <= (BI[0][65] < BI[1][45])? sad[5] + (BI[1][45] - BI[0][65]):sad[5] + (BI[0][65] - BI[1][45]);
        7'd66: sad[5] <= (BI[0][66] < BI[1][46])? sad[5] + (BI[1][46] - BI[0][66]):sad[5] + (BI[0][66] - BI[1][46]);
        7'd67: sad[5] <= (BI[0][67] < BI[1][47])? sad[5] + (BI[1][47] - BI[0][67]):sad[5] + (BI[0][67] - BI[1][47]);
        7'd68: sad[5] <= (BI[0][68] < BI[1][48])? sad[5] + (BI[1][48] - BI[0][68]):sad[5] + (BI[0][68] - BI[1][48]);
        7'd78: sad[5] <= (BI[0][78] < BI[1][58])? sad[5] + (BI[1][58] - BI[0][78]):sad[5] + (BI[0][78] - BI[1][58]);
        7'd77: sad[5] <= (BI[0][77] < BI[1][57])? sad[5] + (BI[1][57] - BI[0][77]):sad[5] + (BI[0][77] - BI[1][57]);
        7'd76: sad[5] <= (BI[0][76] < BI[1][56])? sad[5] + (BI[1][56] - BI[0][76]):sad[5] + (BI[0][76] - BI[1][56]);
        7'd75: sad[5] <= (BI[0][75] < BI[1][55])? sad[5] + (BI[1][55] - BI[0][75]):sad[5] + (BI[0][75] - BI[1][55]);
        7'd74: sad[5] <= (BI[0][74] < BI[1][54])? sad[5] + (BI[1][54] - BI[0][74]):sad[5] + (BI[0][74] - BI[1][54]);
        7'd73: sad[5] <= (BI[0][73] < BI[1][53])? sad[5] + (BI[1][53] - BI[0][73]):sad[5] + (BI[0][73] - BI[1][53]);
        7'd72: sad[5] <= (BI[0][72] < BI[1][52])? sad[5] + (BI[1][52] - BI[0][72]):sad[5] + (BI[0][72] - BI[1][52]);
        7'd71: sad[5] <= (BI[0][71] < BI[1][51])? sad[5] + (BI[1][51] - BI[0][71]):sad[5] + (BI[0][71] - BI[1][51]);
        7'd81: sad[5] <= (BI[0][81] < BI[1][61])? sad[5] + (BI[1][61] - BI[0][81]):sad[5] + (BI[0][81] - BI[1][61]);
        7'd82: sad[5] <= (BI[0][82] < BI[1][62])? sad[5] + (BI[1][62] - BI[0][82]):sad[5] + (BI[0][82] - BI[1][62]);
        7'd83: sad[5] <= (BI[0][83] < BI[1][63])? sad[5] + (BI[1][63] - BI[0][83]):sad[5] + (BI[0][83] - BI[1][63]);
        7'd84: sad[5] <= (BI[0][84] < BI[1][64])? sad[5] + (BI[1][64] - BI[0][84]):sad[5] + (BI[0][84] - BI[1][64]);
        7'd85: sad[5] <= (BI[0][85] < BI[1][65])? sad[5] + (BI[1][65] - BI[0][85]):sad[5] + (BI[0][85] - BI[1][65]);
        7'd86: sad[5] <= (BI[0][86] < BI[1][66])? sad[5] + (BI[1][66] - BI[0][86]):sad[5] + (BI[0][86] - BI[1][66]);
        7'd87: sad[5] <= (BI[0][87] < BI[1][67])? sad[5] + (BI[1][67] - BI[0][87]):sad[5] + (BI[0][87] - BI[1][67]);
        7'd88: sad[5] <= (BI[0][88] < BI[1][68])? sad[5] + (BI[1][68] - BI[0][88]):sad[5] + (BI[0][88] - BI[1][68]);
        7'd98: sad[5] <= (BI[0][98] < BI[1][78])? sad[5] + (BI[1][78] - BI[0][98]):sad[5] + (BI[0][98] - BI[1][78]);
        7'd97: sad[5] <= (BI[0][97] < BI[1][77])? sad[5] + (BI[1][77] - BI[0][97]):sad[5] + (BI[0][97] - BI[1][77]);
        7'd96: sad[5] <= (BI[0][96] < BI[1][76])? sad[5] + (BI[1][76] - BI[0][96]):sad[5] + (BI[0][96] - BI[1][76]);
        7'd95: sad[5] <= (BI[0][95] < BI[1][75])? sad[5] + (BI[1][75] - BI[0][95]):sad[5] + (BI[0][95] - BI[1][75]);
        7'd94: sad[5] <= (BI[0][94] < BI[1][74])? sad[5] + (BI[1][74] - BI[0][94]):sad[5] + (BI[0][94] - BI[1][74]);
        7'd93: sad[5] <= (BI[0][93] < BI[1][73])? sad[5] + (BI[1][73] - BI[0][93]):sad[5] + (BI[0][93] - BI[1][73]);
        7'd92: sad[5] <= (BI[0][92] < BI[1][72])? sad[5] + (BI[1][72] - BI[0][92]):sad[5] + (BI[0][92] - BI[1][72]);
        7'd91: sad[5] <= (BI[0][91] < BI[1][71])? sad[5] + (BI[1][71] - BI[0][91]):sad[5] + (BI[0][91] - BI[1][71]);
        default: sad[5] <= sad[5];
    endcase
end
always @(posedge clk) begin
    case (BI_sum_cnt)
        7'd2: sad[6] <= (BI[0][2] < BI[1][20])? BI[1][20] - BI[0][2]:BI[0][2] - BI[1][20];
        7'd3: sad[6] <= (BI[0][3] < BI[1][21])? sad[6] + (BI[1][21] - BI[0][3]):sad[6] + (BI[0][3] - BI[1][21]);
        7'd4: sad[6] <= (BI[0][4] < BI[1][22])? sad[6] + (BI[1][22] - BI[0][4]):sad[6] + (BI[0][4] - BI[1][22]);
        7'd5: sad[6] <= (BI[0][5] < BI[1][23])? sad[6] + (BI[1][23] - BI[0][5]):sad[6] + (BI[0][5] - BI[1][23]);
        7'd6: sad[6] <= (BI[0][6] < BI[1][24])? sad[6] + (BI[1][24] - BI[0][6]):sad[6] + (BI[0][6] - BI[1][24]);
        7'd7: sad[6] <= (BI[0][7] < BI[1][25])? sad[6] + (BI[1][25] - BI[0][7]):sad[6] + (BI[0][7] - BI[1][25]);
        7'd8: sad[6] <= (BI[0][8] < BI[1][26])? sad[6] + (BI[1][26] - BI[0][8]):sad[6] + (BI[0][8] - BI[1][26]);
        7'd9: sad[6] <= (BI[0][9] < BI[1][27])? sad[6] + (BI[1][27] - BI[0][9]):sad[6] + (BI[0][9] - BI[1][27]);
        7'd17: sad[6] <= (BI[0][17] < BI[1][39])? sad[6] + (BI[1][39] - BI[0][17]):sad[6] + (BI[0][17] - BI[1][39]);
        7'd16: sad[6] <= (BI[0][16] < BI[1][38])? sad[6] + (BI[1][38] - BI[0][16]):sad[6] + (BI[0][16] - BI[1][38]);
        7'd15: sad[6] <= (BI[0][15] < BI[1][37])? sad[6] + (BI[1][37] - BI[0][15]):sad[6] + (BI[0][15] - BI[1][37]);
        7'd14: sad[6] <= (BI[0][14] < BI[1][36])? sad[6] + (BI[1][36] - BI[0][14]):sad[6] + (BI[0][14] - BI[1][36]);
        7'd13: sad[6] <= (BI[0][13] < BI[1][35])? sad[6] + (BI[1][35] - BI[0][13]):sad[6] + (BI[0][13] - BI[1][35]);
        7'd12: sad[6] <= (BI[0][12] < BI[1][34])? sad[6] + (BI[1][34] - BI[0][12]):sad[6] + (BI[0][12] - BI[1][34]);
        7'd11: sad[6] <= (BI[0][11] < BI[1][33])? sad[6] + (BI[1][33] - BI[0][11]):sad[6] + (BI[0][11] - BI[1][33]);
        7'd10: sad[6] <= (BI[0][10] < BI[1][32])? sad[6] + (BI[1][32] - BI[0][10]):sad[6] + (BI[0][10] - BI[1][32]);
        7'd22: sad[6] <= (BI[0][22] < BI[1][40])? sad[6] + (BI[1][40] - BI[0][22]):sad[6] + (BI[0][22] - BI[1][40]);
        7'd23: sad[6] <= (BI[0][23] < BI[1][41])? sad[6] + (BI[1][41] - BI[0][23]):sad[6] + (BI[0][23] - BI[1][41]);
        7'd24: sad[6] <= (BI[0][24] < BI[1][42])? sad[6] + (BI[1][42] - BI[0][24]):sad[6] + (BI[0][24] - BI[1][42]);
        7'd25: sad[6] <= (BI[0][25] < BI[1][43])? sad[6] + (BI[1][43] - BI[0][25]):sad[6] + (BI[0][25] - BI[1][43]);
        7'd26: sad[6] <= (BI[0][26] < BI[1][44])? sad[6] + (BI[1][44] - BI[0][26]):sad[6] + (BI[0][26] - BI[1][44]);
        7'd27: sad[6] <= (BI[0][27] < BI[1][45])? sad[6] + (BI[1][45] - BI[0][27]):sad[6] + (BI[0][27] - BI[1][45]);
        7'd28: sad[6] <= (BI[0][28] < BI[1][46])? sad[6] + (BI[1][46] - BI[0][28]):sad[6] + (BI[0][28] - BI[1][46]);
        7'd29: sad[6] <= (BI[0][29] < BI[1][47])? sad[6] + (BI[1][47] - BI[0][29]):sad[6] + (BI[0][29] - BI[1][47]);
        7'd37: sad[6] <= (BI[0][37] < BI[1][59])? sad[6] + (BI[1][59] - BI[0][37]):sad[6] + (BI[0][37] - BI[1][59]);
        7'd36: sad[6] <= (BI[0][36] < BI[1][58])? sad[6] + (BI[1][58] - BI[0][36]):sad[6] + (BI[0][36] - BI[1][58]);
        7'd35: sad[6] <= (BI[0][35] < BI[1][57])? sad[6] + (BI[1][57] - BI[0][35]):sad[6] + (BI[0][35] - BI[1][57]);
        7'd34: sad[6] <= (BI[0][34] < BI[1][56])? sad[6] + (BI[1][56] - BI[0][34]):sad[6] + (BI[0][34] - BI[1][56]);
        7'd33: sad[6] <= (BI[0][33] < BI[1][55])? sad[6] + (BI[1][55] - BI[0][33]):sad[6] + (BI[0][33] - BI[1][55]);
        7'd32: sad[6] <= (BI[0][32] < BI[1][54])? sad[6] + (BI[1][54] - BI[0][32]):sad[6] + (BI[0][32] - BI[1][54]);
        7'd31: sad[6] <= (BI[0][31] < BI[1][53])? sad[6] + (BI[1][53] - BI[0][31]):sad[6] + (BI[0][31] - BI[1][53]);
        7'd30: sad[6] <= (BI[0][30] < BI[1][52])? sad[6] + (BI[1][52] - BI[0][30]):sad[6] + (BI[0][30] - BI[1][52]);
        7'd42: sad[6] <= (BI[0][42] < BI[1][60])? sad[6] + (BI[1][60] - BI[0][42]):sad[6] + (BI[0][42] - BI[1][60]);
        7'd43: sad[6] <= (BI[0][43] < BI[1][61])? sad[6] + (BI[1][61] - BI[0][43]):sad[6] + (BI[0][43] - BI[1][61]);
        7'd44: sad[6] <= (BI[0][44] < BI[1][62])? sad[6] + (BI[1][62] - BI[0][44]):sad[6] + (BI[0][44] - BI[1][62]);
        7'd45: sad[6] <= (BI[0][45] < BI[1][63])? sad[6] + (BI[1][63] - BI[0][45]):sad[6] + (BI[0][45] - BI[1][63]);
        7'd46: sad[6] <= (BI[0][46] < BI[1][64])? sad[6] + (BI[1][64] - BI[0][46]):sad[6] + (BI[0][46] - BI[1][64]);
        7'd47: sad[6] <= (BI[0][47] < BI[1][65])? sad[6] + (BI[1][65] - BI[0][47]):sad[6] + (BI[0][47] - BI[1][65]);
        7'd48: sad[6] <= (BI[0][48] < BI[1][66])? sad[6] + (BI[1][66] - BI[0][48]):sad[6] + (BI[0][48] - BI[1][66]);
        7'd49: sad[6] <= (BI[0][49] < BI[1][67])? sad[6] + (BI[1][67] - BI[0][49]):sad[6] + (BI[0][49] - BI[1][67]);
        7'd57: sad[6] <= (BI[0][57] < BI[1][79])? sad[6] + (BI[1][79] - BI[0][57]):sad[6] + (BI[0][57] - BI[1][79]);
        7'd56: sad[6] <= (BI[0][56] < BI[1][78])? sad[6] + (BI[1][78] - BI[0][56]):sad[6] + (BI[0][56] - BI[1][78]);
        7'd55: sad[6] <= (BI[0][55] < BI[1][77])? sad[6] + (BI[1][77] - BI[0][55]):sad[6] + (BI[0][55] - BI[1][77]);
        7'd54: sad[6] <= (BI[0][54] < BI[1][76])? sad[6] + (BI[1][76] - BI[0][54]):sad[6] + (BI[0][54] - BI[1][76]);
        7'd53: sad[6] <= (BI[0][53] < BI[1][75])? sad[6] + (BI[1][75] - BI[0][53]):sad[6] + (BI[0][53] - BI[1][75]);
        7'd52: sad[6] <= (BI[0][52] < BI[1][74])? sad[6] + (BI[1][74] - BI[0][52]):sad[6] + (BI[0][52] - BI[1][74]);
        7'd51: sad[6] <= (BI[0][51] < BI[1][73])? sad[6] + (BI[1][73] - BI[0][51]):sad[6] + (BI[0][51] - BI[1][73]);
        7'd50: sad[6] <= (BI[0][50] < BI[1][72])? sad[6] + (BI[1][72] - BI[0][50]):sad[6] + (BI[0][50] - BI[1][72]);
        7'd62: sad[6] <= (BI[0][62] < BI[1][80])? sad[6] + (BI[1][80] - BI[0][62]):sad[6] + (BI[0][62] - BI[1][80]);
        7'd63: sad[6] <= (BI[0][63] < BI[1][81])? sad[6] + (BI[1][81] - BI[0][63]):sad[6] + (BI[0][63] - BI[1][81]);
        7'd64: sad[6] <= (BI[0][64] < BI[1][82])? sad[6] + (BI[1][82] - BI[0][64]):sad[6] + (BI[0][64] - BI[1][82]);
        7'd65: sad[6] <= (BI[0][65] < BI[1][83])? sad[6] + (BI[1][83] - BI[0][65]):sad[6] + (BI[0][65] - BI[1][83]);
        7'd66: sad[6] <= (BI[0][66] < BI[1][84])? sad[6] + (BI[1][84] - BI[0][66]):sad[6] + (BI[0][66] - BI[1][84]);
        7'd67: sad[6] <= (BI[0][67] < BI[1][85])? sad[6] + (BI[1][85] - BI[0][67]):sad[6] + (BI[0][67] - BI[1][85]);
        7'd68: sad[6] <= (BI[0][68] < BI[1][86])? sad[6] + (BI[1][86] - BI[0][68]):sad[6] + (BI[0][68] - BI[1][86]);
        7'd69: sad[6] <= (BI[0][69] < BI[1][87])? sad[6] + (BI[1][87] - BI[0][69]):sad[6] + (BI[0][69] - BI[1][87]);
        7'd77: sad[6] <= (BI[0][77] < BI[1][99])? sad[6] + (BI[1][99] - BI[0][77]):sad[6] + (BI[0][77] - BI[1][99]);
        7'd76: sad[6] <= (BI[0][76] < BI[1][98])? sad[6] + (BI[1][98] - BI[0][76]):sad[6] + (BI[0][76] - BI[1][98]);
        7'd75: sad[6] <= (BI[0][75] < BI[1][97])? sad[6] + (BI[1][97] - BI[0][75]):sad[6] + (BI[0][75] - BI[1][97]);
        7'd74: sad[6] <= (BI[0][74] < BI[1][96])? sad[6] + (BI[1][96] - BI[0][74]):sad[6] + (BI[0][74] - BI[1][96]);
        7'd73: sad[6] <= (BI[0][73] < BI[1][95])? sad[6] + (BI[1][95] - BI[0][73]):sad[6] + (BI[0][73] - BI[1][95]);
        7'd72: sad[6] <= (BI[0][72] < BI[1][94])? sad[6] + (BI[1][94] - BI[0][72]):sad[6] + (BI[0][72] - BI[1][94]);
        7'd71: sad[6] <= (BI[0][71] < BI[1][93])? sad[6] + (BI[1][93] - BI[0][71]):sad[6] + (BI[0][71] - BI[1][93]);
        7'd70: sad[6] <= (BI[0][70] < BI[1][92])? sad[6] + (BI[1][92] - BI[0][70]):sad[6] + (BI[0][70] - BI[1][92]);
        default: sad[6] <= sad[6];
    endcase
end
always @(posedge clk) begin
    case (BI_sum_cnt)
        7'd17: sad[7] <= (BI[0][17] < BI[1][19])? sad[7] + (BI[1][19] - BI[0][17]):sad[7] + (BI[0][17] - BI[1][19]);
        7'd16: sad[7] <= (BI[0][16] < BI[1][18])? sad[7] + (BI[1][18] - BI[0][16]):sad[7] + (BI[0][16] - BI[1][18]);
        7'd15: sad[7] <= (BI[0][15] < BI[1][17])? sad[7] + (BI[1][17] - BI[0][15]):sad[7] + (BI[0][15] - BI[1][17]);
        7'd14: sad[7] <= (BI[0][14] < BI[1][16])? sad[7] + (BI[1][16] - BI[0][14]):sad[7] + (BI[0][14] - BI[1][16]);
        7'd13: sad[7] <= (BI[0][13] < BI[1][15])? sad[7] + (BI[1][15] - BI[0][13]):sad[7] + (BI[0][13] - BI[1][15]);
        7'd12: sad[7] <= (BI[0][12] < BI[1][14])? sad[7] + (BI[1][14] - BI[0][12]):sad[7] + (BI[0][12] - BI[1][14]);
        7'd11: sad[7] <= (BI[0][11] < BI[1][13])? sad[7] + (BI[1][13] - BI[0][11]):sad[7] + (BI[0][11] - BI[1][13]);
        7'd10: sad[7] <= (BI[0][10] < BI[1][12])? BI[1][12] - BI[0][10]:BI[0][10] - BI[1][12];
        7'd22: sad[7] <= (BI[0][22] < BI[1][20])? sad[7] + (BI[1][20] - BI[0][22]):sad[7] + (BI[0][22] - BI[1][20]);
        7'd23: sad[7] <= (BI[0][23] < BI[1][21])? sad[7] + (BI[1][21] - BI[0][23]):sad[7] + (BI[0][23] - BI[1][21]);
        7'd24: sad[7] <= (BI[0][24] < BI[1][22])? sad[7] + (BI[1][22] - BI[0][24]):sad[7] + (BI[0][24] - BI[1][22]);
        7'd25: sad[7] <= (BI[0][25] < BI[1][23])? sad[7] + (BI[1][23] - BI[0][25]):sad[7] + (BI[0][25] - BI[1][23]);
        7'd26: sad[7] <= (BI[0][26] < BI[1][24])? sad[7] + (BI[1][24] - BI[0][26]):sad[7] + (BI[0][26] - BI[1][24]);
        7'd27: sad[7] <= (BI[0][27] < BI[1][25])? sad[7] + (BI[1][25] - BI[0][27]):sad[7] + (BI[0][27] - BI[1][25]);
        7'd28: sad[7] <= (BI[0][28] < BI[1][26])? sad[7] + (BI[1][26] - BI[0][28]):sad[7] + (BI[0][28] - BI[1][26]);
        7'd29: sad[7] <= (BI[0][29] < BI[1][27])? sad[7] + (BI[1][27] - BI[0][29]):sad[7] + (BI[0][29] - BI[1][27]);
        7'd37: sad[7] <= (BI[0][37] < BI[1][39])? sad[7] + (BI[1][39] - BI[0][37]):sad[7] + (BI[0][37] - BI[1][39]);
        7'd36: sad[7] <= (BI[0][36] < BI[1][38])? sad[7] + (BI[1][38] - BI[0][36]):sad[7] + (BI[0][36] - BI[1][38]);
        7'd35: sad[7] <= (BI[0][35] < BI[1][37])? sad[7] + (BI[1][37] - BI[0][35]):sad[7] + (BI[0][35] - BI[1][37]);
        7'd34: sad[7] <= (BI[0][34] < BI[1][36])? sad[7] + (BI[1][36] - BI[0][34]):sad[7] + (BI[0][34] - BI[1][36]);
        7'd33: sad[7] <= (BI[0][33] < BI[1][35])? sad[7] + (BI[1][35] - BI[0][33]):sad[7] + (BI[0][33] - BI[1][35]);
        7'd32: sad[7] <= (BI[0][32] < BI[1][34])? sad[7] + (BI[1][34] - BI[0][32]):sad[7] + (BI[0][32] - BI[1][34]);
        7'd31: sad[7] <= (BI[0][31] < BI[1][33])? sad[7] + (BI[1][33] - BI[0][31]):sad[7] + (BI[0][31] - BI[1][33]);
        7'd30: sad[7] <= (BI[0][30] < BI[1][32])? sad[7] + (BI[1][32] - BI[0][30]):sad[7] + (BI[0][30] - BI[1][32]);
        7'd42: sad[7] <= (BI[0][42] < BI[1][40])? sad[7] + (BI[1][40] - BI[0][42]):sad[7] + (BI[0][42] - BI[1][40]);
        7'd43: sad[7] <= (BI[0][43] < BI[1][41])? sad[7] + (BI[1][41] - BI[0][43]):sad[7] + (BI[0][43] - BI[1][41]);
        7'd44: sad[7] <= (BI[0][44] < BI[1][42])? sad[7] + (BI[1][42] - BI[0][44]):sad[7] + (BI[0][44] - BI[1][42]);
        7'd45: sad[7] <= (BI[0][45] < BI[1][43])? sad[7] + (BI[1][43] - BI[0][45]):sad[7] + (BI[0][45] - BI[1][43]);
        7'd46: sad[7] <= (BI[0][46] < BI[1][44])? sad[7] + (BI[1][44] - BI[0][46]):sad[7] + (BI[0][46] - BI[1][44]);
        7'd47: sad[7] <= (BI[0][47] < BI[1][45])? sad[7] + (BI[1][45] - BI[0][47]):sad[7] + (BI[0][47] - BI[1][45]);
        7'd48: sad[7] <= (BI[0][48] < BI[1][46])? sad[7] + (BI[1][46] - BI[0][48]):sad[7] + (BI[0][48] - BI[1][46]);
        7'd49: sad[7] <= (BI[0][49] < BI[1][47])? sad[7] + (BI[1][47] - BI[0][49]):sad[7] + (BI[0][49] - BI[1][47]);
        7'd57: sad[7] <= (BI[0][57] < BI[1][59])? sad[7] + (BI[1][59] - BI[0][57]):sad[7] + (BI[0][57] - BI[1][59]);
        7'd56: sad[7] <= (BI[0][56] < BI[1][58])? sad[7] + (BI[1][58] - BI[0][56]):sad[7] + (BI[0][56] - BI[1][58]);
        7'd55: sad[7] <= (BI[0][55] < BI[1][57])? sad[7] + (BI[1][57] - BI[0][55]):sad[7] + (BI[0][55] - BI[1][57]);
        7'd54: sad[7] <= (BI[0][54] < BI[1][56])? sad[7] + (BI[1][56] - BI[0][54]):sad[7] + (BI[0][54] - BI[1][56]);
        7'd53: sad[7] <= (BI[0][53] < BI[1][55])? sad[7] + (BI[1][55] - BI[0][53]):sad[7] + (BI[0][53] - BI[1][55]);
        7'd52: sad[7] <= (BI[0][52] < BI[1][54])? sad[7] + (BI[1][54] - BI[0][52]):sad[7] + (BI[0][52] - BI[1][54]);
        7'd51: sad[7] <= (BI[0][51] < BI[1][53])? sad[7] + (BI[1][53] - BI[0][51]):sad[7] + (BI[0][51] - BI[1][53]);
        7'd50: sad[7] <= (BI[0][50] < BI[1][52])? sad[7] + (BI[1][52] - BI[0][50]):sad[7] + (BI[0][50] - BI[1][52]);
        7'd62: sad[7] <= (BI[0][62] < BI[1][60])? sad[7] + (BI[1][60] - BI[0][62]):sad[7] + (BI[0][62] - BI[1][60]);
        7'd63: sad[7] <= (BI[0][63] < BI[1][61])? sad[7] + (BI[1][61] - BI[0][63]):sad[7] + (BI[0][63] - BI[1][61]);
        7'd64: sad[7] <= (BI[0][64] < BI[1][62])? sad[7] + (BI[1][62] - BI[0][64]):sad[7] + (BI[0][64] - BI[1][62]);
        7'd65: sad[7] <= (BI[0][65] < BI[1][63])? sad[7] + (BI[1][63] - BI[0][65]):sad[7] + (BI[0][65] - BI[1][63]);
        7'd66: sad[7] <= (BI[0][66] < BI[1][64])? sad[7] + (BI[1][64] - BI[0][66]):sad[7] + (BI[0][66] - BI[1][64]);
        7'd67: sad[7] <= (BI[0][67] < BI[1][65])? sad[7] + (BI[1][65] - BI[0][67]):sad[7] + (BI[0][67] - BI[1][65]);
        7'd68: sad[7] <= (BI[0][68] < BI[1][66])? sad[7] + (BI[1][66] - BI[0][68]):sad[7] + (BI[0][68] - BI[1][66]);
        7'd69: sad[7] <= (BI[0][69] < BI[1][67])? sad[7] + (BI[1][67] - BI[0][69]):sad[7] + (BI[0][69] - BI[1][67]);
        7'd77: sad[7] <= (BI[0][77] < BI[1][79])? sad[7] + (BI[1][79] - BI[0][77]):sad[7] + (BI[0][77] - BI[1][79]);
        7'd76: sad[7] <= (BI[0][76] < BI[1][78])? sad[7] + (BI[1][78] - BI[0][76]):sad[7] + (BI[0][76] - BI[1][78]);
        7'd75: sad[7] <= (BI[0][75] < BI[1][77])? sad[7] + (BI[1][77] - BI[0][75]):sad[7] + (BI[0][75] - BI[1][77]);
        7'd74: sad[7] <= (BI[0][74] < BI[1][76])? sad[7] + (BI[1][76] - BI[0][74]):sad[7] + (BI[0][74] - BI[1][76]);
        7'd73: sad[7] <= (BI[0][73] < BI[1][75])? sad[7] + (BI[1][75] - BI[0][73]):sad[7] + (BI[0][73] - BI[1][75]);
        7'd72: sad[7] <= (BI[0][72] < BI[1][74])? sad[7] + (BI[1][74] - BI[0][72]):sad[7] + (BI[0][72] - BI[1][74]);
        7'd71: sad[7] <= (BI[0][71] < BI[1][73])? sad[7] + (BI[1][73] - BI[0][71]):sad[7] + (BI[0][71] - BI[1][73]);
        7'd70: sad[7] <= (BI[0][70] < BI[1][72])? sad[7] + (BI[1][72] - BI[0][70]):sad[7] + (BI[0][70] - BI[1][72]);
        7'd82: sad[7] <= (BI[0][82] < BI[1][80])? sad[7] + (BI[1][80] - BI[0][82]):sad[7] + (BI[0][82] - BI[1][80]);
        7'd83: sad[7] <= (BI[0][83] < BI[1][81])? sad[7] + (BI[1][81] - BI[0][83]):sad[7] + (BI[0][83] - BI[1][81]);
        7'd84: sad[7] <= (BI[0][84] < BI[1][82])? sad[7] + (BI[1][82] - BI[0][84]):sad[7] + (BI[0][84] - BI[1][82]);
        7'd85: sad[7] <= (BI[0][85] < BI[1][83])? sad[7] + (BI[1][83] - BI[0][85]):sad[7] + (BI[0][85] - BI[1][83]);
        7'd86: sad[7] <= (BI[0][86] < BI[1][84])? sad[7] + (BI[1][84] - BI[0][86]):sad[7] + (BI[0][86] - BI[1][84]);
        7'd87: sad[7] <= (BI[0][87] < BI[1][85])? sad[7] + (BI[1][85] - BI[0][87]):sad[7] + (BI[0][87] - BI[1][85]);
        7'd88: sad[7] <= (BI[0][88] < BI[1][86])? sad[7] + (BI[1][86] - BI[0][88]):sad[7] + (BI[0][88] - BI[1][86]);
        7'd89: sad[7] <= (BI[0][89] < BI[1][87])? sad[7] + (BI[1][87] - BI[0][89]):sad[7] + (BI[0][89] - BI[1][87]);
        default: sad[7] <= sad[7];
    endcase
end
always @(posedge clk) begin
    case (BI_sum_cnt)
        7'd22: sad[8] <= (BI[0][22] < BI[1][0])? BI[1][0] - BI[0][22]:BI[0][22] - BI[1][0];
        7'd23: sad[8] <= (BI[0][23] < BI[1][1])? sad[8] + (BI[1][1] - BI[0][23]):sad[8] + (BI[0][23] - BI[1][1]);
        7'd24: sad[8] <= (BI[0][24] < BI[1][2])? sad[8] + (BI[1][2] - BI[0][24]):sad[8] + (BI[0][24] - BI[1][2]);
        7'd25: sad[8] <= (BI[0][25] < BI[1][3])? sad[8] + (BI[1][3] - BI[0][25]):sad[8] + (BI[0][25] - BI[1][3]);
        7'd26: sad[8] <= (BI[0][26] < BI[1][4])? sad[8] + (BI[1][4] - BI[0][26]):sad[8] + (BI[0][26] - BI[1][4]);
        7'd27: sad[8] <= (BI[0][27] < BI[1][5])? sad[8] + (BI[1][5] - BI[0][27]):sad[8] + (BI[0][27] - BI[1][5]);
        7'd28: sad[8] <= (BI[0][28] < BI[1][6])? sad[8] + (BI[1][6] - BI[0][28]):sad[8] + (BI[0][28] - BI[1][6]);
        7'd29: sad[8] <= (BI[0][29] < BI[1][7])? sad[8] + (BI[1][7] - BI[0][29]):sad[8] + (BI[0][29] - BI[1][7]);
        7'd37: sad[8] <= (BI[0][37] < BI[1][19])? sad[8] + (BI[1][19] - BI[0][37]):sad[8] + (BI[0][37] - BI[1][19]);
        7'd36: sad[8] <= (BI[0][36] < BI[1][18])? sad[8] + (BI[1][18] - BI[0][36]):sad[8] + (BI[0][36] - BI[1][18]);
        7'd35: sad[8] <= (BI[0][35] < BI[1][17])? sad[8] + (BI[1][17] - BI[0][35]):sad[8] + (BI[0][35] - BI[1][17]);
        7'd34: sad[8] <= (BI[0][34] < BI[1][16])? sad[8] + (BI[1][16] - BI[0][34]):sad[8] + (BI[0][34] - BI[1][16]);
        7'd33: sad[8] <= (BI[0][33] < BI[1][15])? sad[8] + (BI[1][15] - BI[0][33]):sad[8] + (BI[0][33] - BI[1][15]);
        7'd32: sad[8] <= (BI[0][32] < BI[1][14])? sad[8] + (BI[1][14] - BI[0][32]):sad[8] + (BI[0][32] - BI[1][14]);
        7'd31: sad[8] <= (BI[0][31] < BI[1][13])? sad[8] + (BI[1][13] - BI[0][31]):sad[8] + (BI[0][31] - BI[1][13]);
        7'd30: sad[8] <= (BI[0][30] < BI[1][12])? sad[8] + (BI[1][12] - BI[0][30]):sad[8] + (BI[0][30] - BI[1][12]);
        7'd42: sad[8] <= (BI[0][42] < BI[1][20])? sad[8] + (BI[1][20] - BI[0][42]):sad[8] + (BI[0][42] - BI[1][20]);
        7'd43: sad[8] <= (BI[0][43] < BI[1][21])? sad[8] + (BI[1][21] - BI[0][43]):sad[8] + (BI[0][43] - BI[1][21]);
        7'd44: sad[8] <= (BI[0][44] < BI[1][22])? sad[8] + (BI[1][22] - BI[0][44]):sad[8] + (BI[0][44] - BI[1][22]);
        7'd45: sad[8] <= (BI[0][45] < BI[1][23])? sad[8] + (BI[1][23] - BI[0][45]):sad[8] + (BI[0][45] - BI[1][23]);
        7'd46: sad[8] <= (BI[0][46] < BI[1][24])? sad[8] + (BI[1][24] - BI[0][46]):sad[8] + (BI[0][46] - BI[1][24]);
        7'd47: sad[8] <= (BI[0][47] < BI[1][25])? sad[8] + (BI[1][25] - BI[0][47]):sad[8] + (BI[0][47] - BI[1][25]);
        7'd48: sad[8] <= (BI[0][48] < BI[1][26])? sad[8] + (BI[1][26] - BI[0][48]):sad[8] + (BI[0][48] - BI[1][26]);
        7'd49: sad[8] <= (BI[0][49] < BI[1][27])? sad[8] + (BI[1][27] - BI[0][49]):sad[8] + (BI[0][49] - BI[1][27]);
        7'd57: sad[8] <= (BI[0][57] < BI[1][39])? sad[8] + (BI[1][39] - BI[0][57]):sad[8] + (BI[0][57] - BI[1][39]);
        7'd56: sad[8] <= (BI[0][56] < BI[1][38])? sad[8] + (BI[1][38] - BI[0][56]):sad[8] + (BI[0][56] - BI[1][38]);
        7'd55: sad[8] <= (BI[0][55] < BI[1][37])? sad[8] + (BI[1][37] - BI[0][55]):sad[8] + (BI[0][55] - BI[1][37]);
        7'd54: sad[8] <= (BI[0][54] < BI[1][36])? sad[8] + (BI[1][36] - BI[0][54]):sad[8] + (BI[0][54] - BI[1][36]);
        7'd53: sad[8] <= (BI[0][53] < BI[1][35])? sad[8] + (BI[1][35] - BI[0][53]):sad[8] + (BI[0][53] - BI[1][35]);
        7'd52: sad[8] <= (BI[0][52] < BI[1][34])? sad[8] + (BI[1][34] - BI[0][52]):sad[8] + (BI[0][52] - BI[1][34]);
        7'd51: sad[8] <= (BI[0][51] < BI[1][33])? sad[8] + (BI[1][33] - BI[0][51]):sad[8] + (BI[0][51] - BI[1][33]);
        7'd50: sad[8] <= (BI[0][50] < BI[1][32])? sad[8] + (BI[1][32] - BI[0][50]):sad[8] + (BI[0][50] - BI[1][32]);
        7'd62: sad[8] <= (BI[0][62] < BI[1][40])? sad[8] + (BI[1][40] - BI[0][62]):sad[8] + (BI[0][62] - BI[1][40]);
        7'd63: sad[8] <= (BI[0][63] < BI[1][41])? sad[8] + (BI[1][41] - BI[0][63]):sad[8] + (BI[0][63] - BI[1][41]);
        7'd64: sad[8] <= (BI[0][64] < BI[1][42])? sad[8] + (BI[1][42] - BI[0][64]):sad[8] + (BI[0][64] - BI[1][42]);
        7'd65: sad[8] <= (BI[0][65] < BI[1][43])? sad[8] + (BI[1][43] - BI[0][65]):sad[8] + (BI[0][65] - BI[1][43]);
        7'd66: sad[8] <= (BI[0][66] < BI[1][44])? sad[8] + (BI[1][44] - BI[0][66]):sad[8] + (BI[0][66] - BI[1][44]);
        7'd67: sad[8] <= (BI[0][67] < BI[1][45])? sad[8] + (BI[1][45] - BI[0][67]):sad[8] + (BI[0][67] - BI[1][45]);
        7'd68: sad[8] <= (BI[0][68] < BI[1][46])? sad[8] + (BI[1][46] - BI[0][68]):sad[8] + (BI[0][68] - BI[1][46]);
        7'd69: sad[8] <= (BI[0][69] < BI[1][47])? sad[8] + (BI[1][47] - BI[0][69]):sad[8] + (BI[0][69] - BI[1][47]);
        7'd77: sad[8] <= (BI[0][77] < BI[1][59])? sad[8] + (BI[1][59] - BI[0][77]):sad[8] + (BI[0][77] - BI[1][59]);
        7'd76: sad[8] <= (BI[0][76] < BI[1][58])? sad[8] + (BI[1][58] - BI[0][76]):sad[8] + (BI[0][76] - BI[1][58]);
        7'd75: sad[8] <= (BI[0][75] < BI[1][57])? sad[8] + (BI[1][57] - BI[0][75]):sad[8] + (BI[0][75] - BI[1][57]);
        7'd74: sad[8] <= (BI[0][74] < BI[1][56])? sad[8] + (BI[1][56] - BI[0][74]):sad[8] + (BI[0][74] - BI[1][56]);
        7'd73: sad[8] <= (BI[0][73] < BI[1][55])? sad[8] + (BI[1][55] - BI[0][73]):sad[8] + (BI[0][73] - BI[1][55]);
        7'd72: sad[8] <= (BI[0][72] < BI[1][54])? sad[8] + (BI[1][54] - BI[0][72]):sad[8] + (BI[0][72] - BI[1][54]);
        7'd71: sad[8] <= (BI[0][71] < BI[1][53])? sad[8] + (BI[1][53] - BI[0][71]):sad[8] + (BI[0][71] - BI[1][53]);
        7'd70: sad[8] <= (BI[0][70] < BI[1][52])? sad[8] + (BI[1][52] - BI[0][70]):sad[8] + (BI[0][70] - BI[1][52]);
        7'd82: sad[8] <= (BI[0][82] < BI[1][60])? sad[8] + (BI[1][60] - BI[0][82]):sad[8] + (BI[0][82] - BI[1][60]);
        7'd83: sad[8] <= (BI[0][83] < BI[1][61])? sad[8] + (BI[1][61] - BI[0][83]):sad[8] + (BI[0][83] - BI[1][61]);
        7'd84: sad[8] <= (BI[0][84] < BI[1][62])? sad[8] + (BI[1][62] - BI[0][84]):sad[8] + (BI[0][84] - BI[1][62]);
        7'd85: sad[8] <= (BI[0][85] < BI[1][63])? sad[8] + (BI[1][63] - BI[0][85]):sad[8] + (BI[0][85] - BI[1][63]);
        7'd86: sad[8] <= (BI[0][86] < BI[1][64])? sad[8] + (BI[1][64] - BI[0][86]):sad[8] + (BI[0][86] - BI[1][64]);
        7'd87: sad[8] <= (BI[0][87] < BI[1][65])? sad[8] + (BI[1][65] - BI[0][87]):sad[8] + (BI[0][87] - BI[1][65]);
        7'd88: sad[8] <= (BI[0][88] < BI[1][66])? sad[8] + (BI[1][66] - BI[0][88]):sad[8] + (BI[0][88] - BI[1][66]);
        7'd89: sad[8] <= (BI[0][89] < BI[1][67])? sad[8] + (BI[1][67] - BI[0][89]):sad[8] + (BI[0][89] - BI[1][67]);
        7'd97: sad[8] <= (BI[0][97] < BI[1][79])? sad[8] + (BI[1][79] - BI[0][97]):sad[8] + (BI[0][97] - BI[1][79]);
        7'd96: sad[8] <= (BI[0][96] < BI[1][78])? sad[8] + (BI[1][78] - BI[0][96]):sad[8] + (BI[0][96] - BI[1][78]);
        7'd95: sad[8] <= (BI[0][95] < BI[1][77])? sad[8] + (BI[1][77] - BI[0][95]):sad[8] + (BI[0][95] - BI[1][77]);
        7'd94: sad[8] <= (BI[0][94] < BI[1][76])? sad[8] + (BI[1][76] - BI[0][94]):sad[8] + (BI[0][94] - BI[1][76]);
        7'd93: sad[8] <= (BI[0][93] < BI[1][75])? sad[8] + (BI[1][75] - BI[0][93]):sad[8] + (BI[0][93] - BI[1][75]);
        7'd92: sad[8] <= (BI[0][92] < BI[1][74])? sad[8] + (BI[1][74] - BI[0][92]):sad[8] + (BI[0][92] - BI[1][74]);
        7'd91: sad[8] <= (BI[0][91] < BI[1][73])? sad[8] + (BI[1][73] - BI[0][91]):sad[8] + (BI[0][91] - BI[1][73]);
        7'd90: sad[8] <= (BI[0][90] < BI[1][72])? sad[8] + (BI[1][72] - BI[0][90]):sad[8] + (BI[0][90] - BI[1][72]);
        default: sad[8] <= sad[8];
    endcase
end
image_0 img0(.A0(A[0][0]),        .A1(A[0][1]),           .A2(A[0][2]),           .A3(A[0][3]),
             .A4(A[0][4]),         .A5(A[0][5]),           .A6(A[0][6]),           .A7(A[0][7]),
             .A8(A[0][8]),         .A9(A[0][9]),           .A10(A[0][10]),         .A11(A[0][11]),
             .A12(A[0][12]),       .A13(A[0][13]),
             .DO0(Dout[0][0]),     .DO1(Dout[0][1]),       .DO2(Dout[0][2]),       .DO3(Dout[0][3]),
             .DO4(Dout[0][4]),     .DO5(Dout[0][5]),       .DO6(Dout[0][6]),       .DO7(Dout[0][7]),
             .DI0(Din[0]),         .DI1(Din[1]),           .DI2(Din[2]),           .DI3(Din[3]),
             .DI4(Din[4]),         .DI5(Din[5]),           .DI6(Din[6]),           .DI7(Din[7]),
             .CK(clk),             .WEB(WEB[0]),           .OE(1'b1),              .CS(1'b1));
image_1 img1(.A0(A[1][0]),        .A1(A[1][1]),           .A2(A[1][2]),           .A3(A[1][3]),
             .A4(A[1][4]),         .A5(A[1][5]),           .A6(A[1][6]),           .A7(A[1][7]),
             .A8(A[1][8]),         .A9(A[1][9]),           .A10(A[1][10]),         .A11(A[1][11]),
             .A12(A[1][12]),       .A13(A[1][13]),
             .DO0(Dout[1][0]),     .DO1(Dout[1][1]),       .DO2(Dout[1][2]),       .DO3(Dout[1][3]),
             .DO4(Dout[1][4]),     .DO5(Dout[1][5]),       .DO6(Dout[1][6]),       .DO7(Dout[1][7]),
             .DI0(Din[0]),         .DI1(Din[1]),           .DI2(Din[2]),           .DI3(Din[3]),
             .DI4(Din[4]),         .DI5(Din[5]),           .DI6(Din[6]),           .DI7(Din[7]),
             .CK(clk),             .WEB(WEB[1]),           .OE(1'b1),              .CS(1'b1));
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
