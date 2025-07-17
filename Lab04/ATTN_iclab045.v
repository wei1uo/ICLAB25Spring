//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   ICLAB 2023 Fall
//   Lab04 Exercise		: Two Head Attention
//   Author     		: Yu-Chi Lin (a6121461214.st12@nycu.edu.tw)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : ATTN.v
//   Module Name : ATTN
//   Release version : V1.0 (Release Date: 2025-3)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################


module ATTN(
    //Input Port
    clk,
    rst_n,

    in_valid,
    in_str,
    q_weight,
    k_weight,
    v_weight,
    out_weight,

    //Output Port
    out_valid,
    out
    );

//---------------------------------------------------------------------
//   PARAMETER
//---------------------------------------------------------------------

// IEEE floating point parameter
parameter inst_sig_width = 23;
parameter inst_exp_width = 8;
parameter inst_ieee_compliance = 0;
parameter inst_arch_type = 0;
parameter inst_arch = 1;
parameter inst_faithful_round = 0;
parameter r2_rep = 32'b0011_1111_0011_0101_0000_0100_1111_0011;

input rst_n, clk, in_valid;
input [inst_sig_width+inst_exp_width:0] in_str, q_weight, k_weight, v_weight, out_weight;

output out_valid;
output [inst_sig_width+inst_exp_width:0] out;

//---------------------------------------------------------------------
//   Reg & Wires
//---------------------------------------------------------------------

reg[31:0] m_a[1:20], m_b[1:20], m_z[1:20], m_reg[1:20];
reg[31:0] add_a[1:20], add_b[1:20], add_z[1:20];
reg[31:0] exp_a[1:5], exp_z[1:5];
reg[31:0] div_a[0:4], div_b[0:4], div_z[0:4];
reg[31:0] sum_a[1:2], sum_b[1:2], sum_c[1:2], sum_z[1:2];

reg[5:0] counter;
genvar i, j;

reg[31:0] in_w[0:4][0:3];
reg[31:0] k_w[0:3][0:3], q_w[0:3][0:3], v_w[0:3][0:3], out_w[0:3][0:3];
reg[31:0] k[0:4][0:3], q[0:4][0:3], v[0:4][0:3];
reg[31:0] score[1:2][0:4][0:4];
reg[31:0] sum3[1:2][0:4];
reg[31:0] headout[0:4][0:3];
reg[31:0] head_part[0:1][0:1];
reg[31:0] final_res;

//---------------------------------------------------------------------
// IPs
//---------------------------------------------------------------------

generate
    for(i = 1; i < 21; i = i + 1)begin:ip_mac
        DW_fp_mult #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
        MUL(.a(m_a[i]), .b(m_b[i]), .rnd(3'b0), .z(m_z[i]), .status());
        DW_fp_add #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
        ADD(.a(add_a[i]), .b(add_b[i]), .rnd(3'b0), .z(add_z[i]), .status());
    end
endgenerate
generate
    for(i = 1; i < 6; i = i + 1)begin:ip_exp
        DW_fp_exp #(inst_sig_width,inst_exp_width,inst_ieee_compliance, inst_arch)
        EXP(.a(exp_a[i]), .z(exp_z[i]));
    end
endgenerate
generate
    for(i = 0; i < 5; i = i + 1)begin:ip_div
        DW_fp_div #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_faithful_round)
        DIV( .a(div_a[i]), .b(div_b[i]), .rnd(3'b0), .z(div_z[i]), .status());
    end
endgenerate
DW_fp_sum3 #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch_type)
SUM1(.a(sum_a[1]),.b(sum_b[1]),.c(sum_c[1]),.rnd(3'b0),.z(sum_z[1]),.status());
DW_fp_sum3 #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch_type)
SUM2(.a(sum_a[2]),.b(sum_b[2]),.c(sum_c[2]),.rnd(3'b0),.z(sum_z[2]),.status());
        
//---------------------------------------------------------------------
// Design
//---------------------------------------------------------------------

assign out = (counter > 6'd33)? final_res:32'b0;
assign out_valid = (counter > 6'd33);

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        counter <= 6'b0;
    else if(counter == 6'd53)
        counter <= 6'b0;
    else if(!counter && in_valid)
        counter <= 6'd1;
    else if(counter)
        counter <= counter + 1'b1;
    else 
        counter <= counter;
end
generate
    for(i = 1; i < 21; i = i + 1)begin:reg_inst
        always @(posedge clk) begin
            m_reg[i] <= m_z[i];
        end
    end
endgenerate
always @(posedge clk) begin
    final_res <= add_z[2];
end
always @(posedge clk) begin
    head_part[0][0] <= add_z[1];
end
always @(posedge clk) begin
    head_part[0][1] <= m_reg[15];
end
always @(posedge clk) begin
    head_part[1][0] <= add_z[19];
end
always @(posedge clk) begin
    head_part[1][1] <= m_reg[20];
end
generate
    for(j = 0; j < 5; j = j + 1)begin
        for(i = 0; i < 4; i = i + 2)begin
            always @(posedge clk) begin
                if((j << 1) + (i >> 1) + 30 == counter)begin
                    headout[j][i] <= add_z[3];
                    headout[j][i+1] <= add_z[20]; 
                end
            end
        end
    end
endgenerate
//---------------------------------------------------------------------
// WEIGHT IN_KQV_OUT HEADOUT
//---------------------------------------------------------------------

generate
    for(j = 0; j < 5; j = j + 1)begin
        for(i = 0; i < 4; i = i + 1)begin
            always @(posedge clk) begin
                in_w[j][i] <= (counter == ((j << 2) + i))? in_str:in_w[j][i];
            end
        end
    end
endgenerate
generate
    for(j = 0; j < 4; j = j + 1)begin
        for(i = 0; i < 4; i = i + 1)begin
            always @(posedge clk) begin
                k_w[j][i] <= (counter == ((j << 2) + i))? k_weight:k_w[j][i];
            end
        end
    end
endgenerate
generate
    for(j = 0; j < 4; j = j + 1)begin
        for(i = 0; i < 4; i = i + 1)begin
            always @(posedge clk) begin
                q_w[j][i] <= (counter == ((j << 2) + i))? q_weight:q_w[j][i];
            end
        end
    end
endgenerate
generate
    for(j = 0; j < 4; j = j + 1)begin
        for(i = 0; i < 4; i = i + 1)begin
            always @(posedge clk) begin
                v_w[j][i] <= (counter == ((j << 2) + i))? v_weight:v_w[j][i];
            end
        end
    end
endgenerate
generate
    for(j = 0; j < 4; j = j + 1)begin
        for(i = 0; i < 4; i = i + 1)begin
            always @(posedge clk) begin
                out_w[j][i] <= (counter == ((j << 2) + i))? out_weight:out_w[j][i];
            end
        end
    end
endgenerate

//---------------------------------------------------------------------
// KQV
//---------------------------------------------------------------------

// === K === /
always @(posedge clk) begin // row 0
    case (counter)
        6'd1: k[0][0] <= m_z[1];
        6'd3: k[0][0] <= add_z[1];
        6'd4: k[0][0] <= add_z[1];
        6'd5: k[0][0] <= add_z[1];
        6'd6: k[0][0] <= m_z[1];
        default: k[0][0] <= k[0][0];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd5: k[0][1] <= m_z[2];
        6'd7: k[0][1] <= add_z[2];
        6'd8: k[0][1] <= add_z[2];
        6'd9: k[0][1] <= add_z[2];
        6'd10: k[0][1] <= m_z[2];
        default: k[0][1] <= k[0][1];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd9: k[0][2] <= m_z[1];
        6'd11: k[0][2] <= add_z[1];
        6'd12: k[0][2] <= add_z[1];
        6'd13: k[0][2] <= add_z[1];
        6'd14: k[0][2] <= m_z[15];
        default: k[0][2] <= k[0][2];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd13: k[0][3] <= m_z[1];
        6'd15: k[0][3] <= add_z[1];
        6'd16: k[0][3] <= add_z[1];
        6'd17: k[0][3] <= add_z[1];
        6'd18: k[0][3] <= m_z[5];
        default: k[0][3] <= k[0][3];
    endcase
end
always @(posedge clk) begin // row 1
    case (counter)
        6'd5: k[1][0] <= m_z[4];
        6'd7: k[1][0] <= add_z[4];
        6'd8: k[1][0] <= add_z[4];
        6'd9: k[1][0] <= add_z[4];
        6'd10: k[1][0] <= m_z[4];
        default: k[1][0] <= k[1][0];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd5: k[1][1] <= m_z[3];
        6'd7: k[1][1] <= add_z[3];
        6'd8: k[1][1] <= add_z[3];
        6'd9: k[1][1] <= add_z[3];
        6'd10: k[1][1] <= m_z[3];
        default: k[1][1] <= k[1][1];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd9: k[1][2] <= m_z[5];
        6'd11: k[1][2] <= add_z[5];
        6'd12: k[1][2] <= add_z[5];
        6'd13: k[1][2] <= add_z[5];
        6'd14: k[1][2] <= m_z[16];
        default: k[1][2] <= k[1][2];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd13: k[1][3] <= m_z[2];
        6'd15: k[1][3] <= add_z[2];
        6'd16: k[1][3] <= add_z[2];
        6'd17: k[1][3] <= add_z[2];
        6'd18: k[1][3] <= m_z[6];
        default: k[1][3] <= k[1][3];
    endcase
end
always @(posedge clk) begin // row 2
    case (counter)
        6'd9: k[2][0] <= m_z[8];
        6'd11: k[2][0] <= add_z[8];
        6'd12: k[2][0] <= add_z[8];
        6'd13: k[2][0] <= add_z[8];
        6'd14: k[2][0] <= m_z[19];
        default: k[2][0] <= k[2][0];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd9: k[2][1] <= m_z[7];
        6'd11: k[2][1] <= add_z[7];
        6'd12: k[2][1] <= add_z[7];
        6'd13: k[2][1] <= add_z[7];
        6'd14: k[2][1] <= m_z[18];
        default: k[2][1] <= k[2][1];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd9: k[2][2] <= m_z[6];
        6'd11: k[2][2] <= add_z[6];
        6'd12: k[2][2] <= add_z[6];
        6'd13: k[2][2] <= add_z[6];
        6'd14: k[2][2] <= m_z[17];
        default: k[2][2] <= k[2][2];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd13: k[2][3] <= m_z[3];
        6'd15: k[2][3] <= add_z[3];
        6'd16: k[2][3] <= add_z[3];
        6'd17: k[2][3] <= add_z[3];
        6'd18: k[2][3] <= m_z[7];
        default: k[2][3] <= k[2][3];
    endcase
end
always @(posedge clk) begin // row 3
    case (counter)
        6'd13: k[3][0] <= m_z[7];
        6'd15: k[3][0] <= add_z[7];
        6'd16: k[3][0] <= add_z[7];
        6'd17: k[3][0] <= add_z[7];
        6'd18: k[3][0] <= m_z[15];
        default: k[3][0] <= k[3][0];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd13: k[3][1] <= m_z[6];
        6'd15: k[3][1] <= add_z[6];
        6'd16: k[3][1] <= add_z[6];
        6'd17: k[3][1] <= add_z[6];
        6'd18: k[3][1] <= m_z[14];
        default: k[3][1] <= k[3][1];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd13: k[3][2] <= m_z[5];
        6'd15: k[3][2] <= add_z[5];
        6'd16: k[3][2] <= add_z[5];
        6'd17: k[3][2] <= add_z[5];
        6'd18: k[3][2] <= m_z[13];
        default: k[3][2] <= k[3][2];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd13: k[3][3] <= m_z[4];
        6'd15: k[3][3] <= add_z[4];
        6'd16: k[3][3] <= add_z[4];
        6'd17: k[3][3] <= add_z[4];
        6'd18: k[3][3] <= m_z[12];
        default: k[3][3] <= k[3][3];
    endcase
end
always @(posedge clk) begin // row 4
    case (counter)
        6'd17: k[4][0] <= m_z[1];
        6'd19: k[4][0] <= add_z[1];
        6'd20: k[4][0] <= add_z[1];
        6'd21: k[4][0] <= add_z[1];
        6'd22: k[4][0] <= m_z[1];
        default: k[4][0] <= k[4][0];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd17: k[4][1] <= m_z[2];
        6'd19: k[4][1] <= add_z[2];
        6'd20: k[4][1] <= add_z[2];
        6'd21: k[4][1] <= add_z[2];
        6'd22: k[4][1] <= m_z[2];
        default: k[4][1] <= k[4][1];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd17: k[4][2] <= m_z[3];
        6'd19: k[4][2] <= add_z[3];
        6'd20: k[4][2] <= add_z[3];
        6'd21: k[4][2] <= add_z[3];
        6'd22: k[4][2] <= m_z[3];
        default: k[4][2] <= k[4][2];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd17: k[4][3] <= m_z[4];
        6'd19: k[4][3] <= add_z[4];
        6'd20: k[4][3] <= add_z[4];
        6'd21: k[4][3] <= add_z[4];
        6'd22: k[4][3] <= m_z[4];
        default: k[4][3] <= k[4][3];
    endcase
end
// === Q === /
always @(posedge clk) begin
    case (counter)
        6'd1: q[0][0] <= m_z[8];
        6'd3: q[0][0] <= add_z[8];
        6'd4: q[0][0] <= add_z[8];
        6'd5: q[0][0] <= add_z[8];
        default: q[0][0] <= q[0][0];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd5: q[0][1] <= m_z[8];
        6'd7: q[0][1] <= add_z[8];
        6'd8: q[0][1] <= add_z[8];
        6'd9: q[0][1] <= add_z[8];
        default: q[0][1] <= q[0][1];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd9: q[0][2] <= m_z[11];
        6'd11: q[0][2] <= add_z[11];
        6'd12: q[0][2] <= add_z[11];
        6'd13: q[0][2] <= add_z[11];
        default: q[0][2] <= q[0][2];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd13: q[0][3] <= m_z[11];
        6'd15: q[0][3] <= add_z[11];
        6'd16: q[0][3] <= add_z[11];
        6'd17: q[0][3] <= add_z[11];
        default: q[0][3] <= q[0][3];
    endcase
end
always @(posedge clk) begin // row 1
    case (counter)
        6'd5: q[1][0] <= m_z[10];
        6'd7: q[1][0] <= add_z[10];
        6'd8: q[1][0] <= add_z[10];
        6'd9: q[1][0] <= add_z[10];
        default: q[1][0] <= q[1][0];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd5: q[1][1] <= m_z[9];
        6'd7: q[1][1] <= add_z[9];
        6'd8: q[1][1] <= add_z[9];
        6'd9: q[1][1] <= add_z[9];
        default: q[1][1] <= q[1][1];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd9: q[1][2] <= m_z[12];
        6'd11: q[1][2] <= add_z[12];
        6'd12: q[1][2] <= add_z[12];
        6'd13: q[1][2] <= add_z[12];
        default: q[1][2] <= q[1][2];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd13: q[1][3] <= m_z[12];
        6'd15: q[1][3] <= add_z[12];
        6'd16: q[1][3] <= add_z[12];
        6'd17: q[1][3] <= add_z[12];
        default: q[1][3] <= q[1][3];
    endcase
end
always @(posedge clk) begin // row 2
    case (counter)
        6'd9: q[2][0] <= m_z[10];
        6'd11: q[2][0] <= add_z[10];
        6'd12: q[2][0] <= add_z[10];
        6'd13: q[2][0] <= add_z[10];
        default: q[2][0] <= q[2][0];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd9: q[2][1] <= m_z[9];
        6'd11: q[2][1] <= add_z[9];
        6'd12: q[2][1] <= add_z[9];
        6'd13: q[2][1] <= add_z[9];
        default: q[2][1] <= q[2][1];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd9: q[2][2] <= m_z[13];
        6'd11: q[2][2] <= add_z[13];
        6'd12: q[2][2] <= add_z[13];
        6'd13: q[2][2] <= add_z[13];
        default: q[2][2] <= q[2][2];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd13: q[2][3] <= m_z[13];
        6'd15: q[2][3] <= add_z[13];
        6'd16: q[2][3] <= add_z[13];
        6'd17: q[2][3] <= add_z[13];
        default: q[2][3] <= q[2][3];
    endcase
end
always @(posedge clk) begin // row 3
    case (counter)
        6'd13: q[3][0] <= m_z[10];
        6'd15: q[3][0] <= add_z[10];
        6'd16: q[3][0] <= add_z[10];
        6'd17: q[3][0] <= add_z[10];
        default: q[3][0] <= q[3][0];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd13: q[3][1] <= m_z[9];
        6'd15: q[3][1] <= add_z[9];
        6'd16: q[3][1] <= add_z[9];
        6'd17: q[3][1] <= add_z[9];
        default: q[3][1] <= q[3][1];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd13: q[3][2] <= m_z[8];
        6'd15: q[3][2] <= add_z[8];
        6'd16: q[3][2] <= add_z[8];
        6'd17: q[3][2] <= add_z[8];
        default: q[3][2] <= q[3][2];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd13: q[3][3] <= m_z[14];
        6'd15: q[3][3] <= add_z[14];
        6'd16: q[3][3] <= add_z[14];
        6'd17: q[3][3] <= add_z[14];
        default: q[3][3] <= q[3][3];
    endcase
end
always @(posedge clk) begin // row 4
    case (counter)
        6'd17: q[4][0] <= m_z[10];
        6'd19: q[4][0] <= add_z[10];
        6'd20: q[4][0] <= add_z[10];
        6'd21: q[4][0] <= add_z[10];
        default: q[4][0] <= q[4][0];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd17: q[4][1] <= m_z[9];
        6'd19: q[4][1] <= add_z[9];
        6'd20: q[4][1] <= add_z[9];
        6'd21: q[4][1] <= add_z[9];
        default: q[4][1] <= q[4][1];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd17: q[4][2] <= m_z[8];
        6'd19: q[4][2] <= add_z[8];
        6'd20: q[4][2] <= add_z[8];
        6'd21: q[4][2] <= add_z[8];
        default: q[4][2] <= q[4][2];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd17: q[4][3] <= m_z[11];
        6'd19: q[4][3] <= add_z[11];
        6'd20: q[4][3] <= add_z[11];
        6'd21: q[4][3] <= add_z[11];
        default: q[4][3] <= q[4][3];
    endcase
end
// === V === /
always @(posedge clk) begin
    case (counter)
        6'd1: v[0][0] <= m_z[15];
        6'd3: v[0][0] <= add_z[15];
        6'd4: v[0][0] <= add_z[15];
        6'd5: v[0][0] <= add_z[15];
        default: v[0][0] <= v[0][0];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd5: v[0][1] <= m_z[15];
        6'd7: v[0][1] <= add_z[15];
        6'd8: v[0][1] <= add_z[15];
        6'd9: v[0][1] <= add_z[15];
        default: v[0][1] <= v[0][1];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd9: v[0][2] <= m_z[15];
        6'd11: v[0][2] <= add_z[15];
        6'd12: v[0][2] <= add_z[15];
        6'd13: v[0][2] <= add_z[15];
        default: v[0][2] <= v[0][2];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd18: v[0][3] <= add_z[5];
        6'd22: v[0][3] <= add_z[14];
        6'd23: v[0][3] <= add_z[17];
        default: v[0][3] <= v[0][3];
    endcase
end
always @(posedge clk) begin // row 1
    case (counter)
        6'd5: v[1][0] <= m_z[17];
        6'd7: v[1][0] <= add_z[17];
        6'd8: v[1][0] <= add_z[17];
        6'd9: v[1][0] <= add_z[17];
        default: v[1][0] <= v[1][0];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd5: v[1][1] <= m_z[16];
        6'd7: v[1][1] <= add_z[16];
        6'd8: v[1][1] <= add_z[16];
        6'd9: v[1][1] <= add_z[16];
        default: v[1][1] <= v[1][1];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd9: v[1][2] <= m_z[16];
        6'd11: v[1][2] <= add_z[16];
        6'd12: v[1][2] <= add_z[16];
        6'd13: v[1][2] <= add_z[16];
        default: v[1][2] <= v[1][2];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd18: v[1][3] <= add_z[13];
        6'd22: v[1][3] <= add_z[15];
        6'd23: v[1][3] <= add_z[14];
        default: v[1][3] <= v[1][3];
    endcase
end
always @(posedge clk) begin // row 2
    case (counter)
        6'd9: v[2][0] <= m_z[17];
        6'd11: v[2][0] <= add_z[17];
        6'd13: v[2][0] <= add_z[17];
        6'd14: v[2][0] <= add_z[17];
        default: v[2][0] <= v[2][0];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd9: v[2][1] <= m_z[14];
        6'd11: v[2][1] <= add_z[14];
        6'd13: v[2][1] <= add_z[14];
        6'd14: v[2][1] <= add_z[15];
        default: v[2][1] <= v[2][1];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd9: v[2][2] <= m_z[18];
        6'd11: v[2][2] <= add_z[18];
        6'd13: v[2][2] <= add_z[18];
        6'd14: v[2][2] <= add_z[18];
        default: v[2][2] <= v[2][2];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd17: v[2][3] <= add_z[15];
        6'd18: v[2][3] <= add_z[17];
        6'd22: v[2][3] <= add_z[17];
        default: v[2][3] <= v[2][3];
    endcase
end
always @(posedge clk) begin // row 3
    case (counter)
        6'd13: v[3][0] <= m_z[16];
        6'd18: v[3][0] <= add_z[16];
        6'd19: v[3][0] <= add_z[16];
        6'd22: v[3][0] <= add_z[16];
        default: v[3][0] <= v[3][0];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd13: v[3][1] <= m_z[19];
        6'd18: v[3][1] <= add_z[19];
        6'd19: v[3][1] <= add_z[19];
        6'd22: v[3][1] <= add_z[19];
        default: v[3][1] <= v[3][1];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd13: v[3][2] <= m_z[20];
        6'd18: v[3][2] <= add_z[20];
        6'd19: v[3][2] <= add_z[20];
        6'd22: v[3][2] <= add_z[20];
        default: v[3][2] <= v[3][2];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd14: v[3][3] <= m_z[20];
        6'd18: v[3][3] <= add_z[15];
        6'd22: v[3][3] <= add_z[13];
        6'd23: v[3][3] <= add_z[13];
        default: v[3][3] <= v[3][3];
    endcase
end
always @(posedge clk) begin // row 4
    case (counter)
        6'd17: v[4][0] <= m_z[18];
        6'd22: v[4][0] <= add_z[18];
        6'd23: v[4][0] <= add_z[18];
        6'd25: v[4][0] <= add_z[18];
        default: v[4][0] <= v[4][0];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd17: v[4][1] <= m_z[7];
        6'd23: v[4][1] <= add_z[15];
        6'd25: v[4][1] <= add_z[15];
        6'd26: v[4][1] <= add_z[15];
        default: v[4][1] <= v[4][1];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd17: v[4][2] <= m_z[12];
        6'd23: v[4][2] <= add_z[16];
        6'd25: v[4][2] <= add_z[16];
        6'd26: v[4][2] <= add_z[16];
        default: v[4][2] <= v[4][2];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd19: v[4][3] <= add_z[17];
        6'd25: v[4][3] <= add_z[17];
        6'd26: v[4][3] <= add_z[17];
        default: v[4][3] <= v[4][3];
    endcase
end
//---------------------------------------------------------------------
// SCORE
//---------------------------------------------------------------------
always @(posedge clk) begin
    case (counter)
        6'd12: score[1][0][0] <= add_z[3];
        6'd13: score[1][0][0] <= exp_z[1];
        6'd27: score[1][0][0] <= div_z[0];
        default: score[1][0][0] <= score[1][0][0];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd12: score[1][0][1] <= add_z[14];
        6'd13: score[1][0][1] <= exp_z[2];
        6'd27: score[1][0][1] <= div_z[1];
        default: score[1][0][1] <= score[1][0][1];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd16: score[1][0][2] <= add_z[16];
        6'd17: score[1][0][2] <= exp_z[1];
        6'd27: score[1][0][2] <= div_z[2];
        default: score[1][0][2] <= score[1][0][2];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd23: score[1][0][3] <= add_z[6];
        6'd24: score[1][0][3] <= exp_z[1];
        6'd27: score[1][0][3] <= div_z[3];
        default: score[1][0][3] <= score[1][0][3];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd24: score[1][0][4] <= add_z[2];
        6'd25: score[1][0][4] <= exp_z[1];
        6'd27: score[1][0][4] <= div_z[4];
        default: score[1][0][4] <= score[1][0][4];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd12: score[1][1][0] <= add_z[18];
        6'd13: score[1][1][0] <= exp_z[3];
        6'd29: score[1][1][0] <= div_z[0];
        default: score[1][1][0] <= score[1][1][0];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd12: score[1][1][1] <= add_z[20];
        6'd13: score[1][1][1] <= exp_z[4];
        6'd29: score[1][1][1] <= div_z[1];
        default: score[1][1][1] <= score[1][1][1];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd16: score[1][1][2] <= add_z[18];
        6'd17: score[1][1][2] <= exp_z[2];
        6'd29: score[1][1][2] <= div_z[2];
        default: score[1][1][2] <= score[1][1][2];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd23: score[1][1][3] <= add_z[8];
        6'd24: score[1][1][3] <= exp_z[2];
        6'd29: score[1][1][3] <= div_z[3];
        default: score[1][1][3] <= score[1][1][3];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd24: score[1][1][4] <= add_z[4];
        6'd25: score[1][1][4] <= exp_z[2];
        6'd29: score[1][1][4] <= div_z[4];
        default: score[1][1][4] <= score[1][1][4];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd17: score[1][2][0] <= add_z[18];
        6'd18: score[1][2][0] <= exp_z[1];
        6'd31: score[1][2][0] <= div_z[0];
        default: score[1][2][0] <= score[1][2][0];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd17: score[1][2][1] <= add_z[20];
        6'd18: score[1][2][1] <= exp_z[2];
        6'd31: score[1][2][1] <= div_z[1];
        default: score[1][2][1] <= score[1][2][1];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd16: score[1][2][2] <= add_z[20];
        6'd17: score[1][2][2] <= exp_z[3];
        6'd31: score[1][2][2] <= div_z[2];
        default: score[1][2][2] <= score[1][2][2];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd23: score[1][2][3] <= add_z[10];
        6'd24: score[1][2][3] <= exp_z[3];
        6'd31: score[1][2][3] <= div_z[3];
        default: score[1][2][3] <= score[1][2][3];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd24: score[1][2][4] <= add_z[6];
        6'd25: score[1][2][4] <= exp_z[3];
        6'd31: score[1][2][4] <= div_z[4];
        default: score[1][2][4] <= score[1][2][4];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd20: score[1][3][0] <= add_z[6];
        6'd21: score[1][3][0] <= exp_z[1];
        6'd33: score[1][3][0] <= div_z[0];
        default: score[1][3][0] <= score[1][3][0];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd20: score[1][3][1] <= add_z[12];
        6'd21: score[1][3][1] <= exp_z[2];
        6'd33: score[1][3][1] <= div_z[1];
        default: score[1][3][1] <= score[1][3][1];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd20: score[1][3][2] <= add_z[14];
        6'd21: score[1][3][2] <= exp_z[3];
        6'd33: score[1][3][2] <= div_z[2];
        default: score[1][3][2] <= score[1][3][2];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd23: score[1][3][3] <= add_z[12];
        6'd24: score[1][3][3] <= exp_z[4];
        6'd33: score[1][3][3] <= div_z[3];
        default: score[1][3][3] <= score[1][3][3];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd24: score[1][3][4] <= add_z[8];
        6'd25: score[1][3][4] <= exp_z[4];
        6'd33: score[1][3][4] <= div_z[4];
        default: score[1][3][4] <= score[1][3][4];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd25: score[1][4][0] <= add_z[2];
        6'd26: score[1][4][0] <= exp_z[1];
        6'd35: score[1][4][0] <= div_z[0];
        default: score[1][4][0] <= score[1][4][0];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd25: score[1][4][1] <= add_z[4];
        6'd26: score[1][4][1] <= exp_z[2];
        6'd35: score[1][4][1] <= div_z[1];
        default: score[1][4][1] <= score[1][4][1];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd25: score[1][4][2] <= add_z[6];
        6'd26: score[1][4][2] <= exp_z[3];
        6'd35: score[1][4][2] <= div_z[2];
        default: score[1][4][2] <= score[1][4][2];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd25: score[1][4][3] <= add_z[8];
        6'd26: score[1][4][3] <= exp_z[4];
        6'd35: score[1][4][3] <= div_z[3];
        default: score[1][4][3] <= score[1][4][3];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd24: score[1][4][4] <= add_z[10];
        6'd25: score[1][4][4] <= exp_z[5];
        6'd35: score[1][4][4] <= div_z[4];
        default: score[1][4][4] <= score[1][4][4];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd20: score[2][0][0] <= add_z[16];
        6'd21: score[2][0][0] <= exp_z[4];
        6'd28: score[2][0][0] <= div_z[0];
        default: score[2][0][0] <= score[2][0][0];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd20: score[2][0][1] <= add_z[18];
        6'd21: score[2][0][1] <= exp_z[5];
        6'd28: score[2][0][1] <= div_z[1];
        default: score[2][0][1] <= score[2][0][1];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd20: score[2][0][2] <= add_z[20];
        6'd22: score[2][0][2] <= exp_z[1];
        6'd28: score[2][0][2] <= div_z[2];
        default: score[2][0][2] <= score[2][0][2];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd22: score[2][0][3] <= add_z[8];
        6'd24: score[2][0][3] <= exp_z[5];
        6'd28: score[2][0][3] <= div_z[3];
        default: score[2][0][3] <= score[2][0][3];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd24: score[2][0][4] <= add_z[12];
        6'd26: score[2][0][4] <= exp_z[5];
        6'd28: score[2][0][4] <= div_z[4];
        default: score[2][0][4] <= score[2][0][4];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd21: score[2][1][0] <= add_z[6];
        6'd22: score[2][1][0] <= exp_z[4];
        6'd30: score[2][1][0] <= div_z[0];
        default: score[2][1][0] <= score[2][1][0];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd21: score[2][1][1] <= add_z[12];
        6'd22: score[2][1][1] <= exp_z[5];
        6'd30: score[2][1][1] <= div_z[1];
        default: score[2][1][1] <= score[2][1][1];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd21: score[2][1][2] <= add_z[14];
        6'd22: score[2][1][2] <= exp_z[2];
        6'd30: score[2][1][2] <= div_z[2];
        default: score[2][1][2] <= score[2][1][2];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd22: score[2][1][3] <= add_z[10];
        6'd27: score[2][1][3] <= exp_z[4];
        6'd30: score[2][1][3] <= div_z[3];
        default: score[2][1][3] <= score[2][1][3];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd24: score[2][1][4] <= add_z[14];
        6'd27: score[2][1][4] <= exp_z[5];
        6'd30: score[2][1][4] <= div_z[4];
        default: score[2][1][4] <= score[2][1][4];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd21: score[2][2][0] <= add_z[16];
        6'd22: score[2][2][0] <= exp_z[3];
        6'd32: score[2][2][0] <= div_z[0];
        default: score[2][2][0] <= score[2][2][0];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd21: score[2][2][1] <= add_z[18];
        6'd23: score[2][2][1] <= exp_z[3];
        6'd32: score[2][2][1] <= div_z[1];
        default: score[2][2][1] <= score[2][2][1];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd21: score[2][2][2] <= add_z[20];
        6'd23: score[2][2][2] <= exp_z[1];
        6'd32: score[2][2][2] <= div_z[2];
        default: score[2][2][2] <= score[2][2][2];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd22: score[2][2][3] <= add_z[12];
        6'd27: score[2][2][3] <= exp_z[1];
        6'd32: score[2][2][3] <= div_z[3];
        default: score[2][2][3] <= score[2][2][3];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd24: score[2][2][4] <= add_z[16];
        6'd27: score[2][2][4] <= exp_z[3];
        6'd32: score[2][2][4] <= div_z[4];
        default: score[2][2][4] <= score[2][2][4];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd22: score[2][3][0] <= add_z[2];
        6'd23: score[2][3][0] <= exp_z[4];
        6'd34: score[2][3][0] <= div_z[0];
        default: score[2][3][0] <= score[2][3][0];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd22: score[2][3][1] <= add_z[4];
        6'd23: score[2][3][1] <= exp_z[5];
        6'd34: score[2][3][1] <= div_z[1];
        default: score[2][3][1] <= score[2][3][1];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd22: score[2][3][2] <= add_z[6];
        6'd23: score[2][3][2] <= exp_z[2];
        6'd34: score[2][3][2] <= div_z[2];
        default: score[2][3][2] <= score[2][3][2];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd23: score[2][3][3] <= add_z[20];
        6'd27: score[2][3][3] <= exp_z[2];
        6'd34: score[2][3][3] <= div_z[3];
        default: score[2][3][3] <= score[2][3][3];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd24: score[2][3][4] <= add_z[18];
        6'd28: score[2][3][4] <= exp_z[3];
        6'd34: score[2][3][4] <= div_z[4];
        default: score[2][3][4] <= score[2][3][4];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd25: score[2][4][0] <= add_z[10];
        6'd28: score[2][4][0] <= exp_z[4];
        6'd36: score[2][4][0] <= div_z[0];
        default: score[2][4][0] <= score[2][4][0];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd25: score[2][4][1] <= add_z[12];
        6'd28: score[2][4][1] <= exp_z[5];
        6'd36: score[2][4][1] <= div_z[1];
        default: score[2][4][1] <= score[2][4][1];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd25: score[2][4][2] <= add_z[14];
        6'd28: score[2][4][2] <= exp_z[1];
        6'd36: score[2][4][2] <= div_z[2];
        default: score[2][4][2] <= score[2][4][2];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd25: score[2][4][3] <= add_z[20];
        6'd28: score[2][4][3] <= exp_z[2];
        6'd36: score[2][4][3] <= div_z[3];
        default: score[2][4][3] <= score[2][4][3];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd24: score[2][4][4] <= add_z[20];
        6'd29: score[2][4][4] <= exp_z[5];
        6'd36: score[2][4][4] <= div_z[4];
        default: score[2][4][4] <= score[2][4][4];
    endcase
end
//---------------------------------------------------------------------
// SUM3
//---------------------------------------------------------------------
always @(posedge clk) begin
    case (counter)
        6'd18: sum3[1][0] <= sum_z[1];
        6'd26: sum3[1][0] <= sum_z[1];
        default: sum3[1][0] <= sum3[1][0];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd18: sum3[1][1] <= sum_z[2];
        6'd26: sum3[1][1] <= sum_z[2];
        default: sum3[1][1] <= sum3[1][1];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd19: sum3[1][2] <= sum_z[1];
        6'd27: sum3[1][2] <= sum_z[1];
        default: sum3[1][2] <= sum3[1][2];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd22: sum3[1][3] <= sum_z[1];
        6'd29: sum3[1][3] <= sum_z[1];
        default: sum3[1][3] <= sum3[1][3];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd30: sum3[1][4] <= sum_z[1];
        6'd31: sum3[1][4] <= sum_z[1];
        default: sum3[1][4] <= sum3[1][4];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd23: sum3[2][0] <= sum_z[1];
        6'd27: sum3[2][0] <= sum_z[2];
        default: sum3[2][0] <= sum3[2][0];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd23: sum3[2][1] <= sum_z[2];
        6'd28: sum3[2][1] <= sum_z[1];
        default: sum3[2][1] <= sum3[2][1];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd24: sum3[2][2] <= sum_z[1];
        6'd28: sum3[2][2] <= sum_z[2];
        default: sum3[2][2] <= sum3[2][2];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd24: sum3[2][3] <= sum_z[2];
        6'd29: sum3[2][3] <= sum_z[2];
        default: sum3[2][3] <= sum3[2][3];
    endcase
end
always @(posedge clk) begin
    case (counter)
        6'd30: sum3[2][4] <= sum_z[2];
        6'd31: sum3[2][4] <= sum_z[2];
        default: sum3[2][4] <= sum3[2][4];
    endcase
end
//---------------------------------------------------------------------
// FP_MULT
//---------------------------------------------------------------------
always @(*) begin // m1_a
    case (counter)
        6'd1: m_a[1] = in_w[0][0];
        6'd2: m_a[1] = in_w[0][1];
        6'd3: m_a[1] = in_w[0][2];
        6'd4: m_a[1] = in_w[0][3];
        6'd6: m_a[1] = k[0][0];
        6'd9: m_a[1] = in_w[0][0];
        6'd10: m_a[1] = in_w[0][1];
        6'd11: m_a[1] = in_w[0][2];
        6'd12: m_a[1] = in_w[0][3];
        6'd13: m_a[1] = in_w[0][0];
        6'd14: m_a[1] = in_w[0][1];
        6'd15: m_a[1] = in_w[0][2];
        6'd16: m_a[1] = in_w[0][3];
        6'd17: m_a[1] = in_w[4][0];
        6'd18: m_a[1] = in_w[4][1];
        6'd19: m_a[1] = in_w[4][2];
        6'd20: m_a[1] = in_w[4][3];
        6'd22: m_a[1] = k[4][0];

        6'd23: m_a[1] = k[4][0];
        6'd24: m_a[1] = k[0][0];
        6'd21: m_a[1] = k[0][2];
        default: m_a[1] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        6'd1: m_b[1] = k_w[0][0];
        6'd2: m_b[1] = k_w[0][1];
        6'd3: m_b[1] = k_w[0][2];
        6'd4: m_b[1] = k_w[0][3];
        6'd6: m_b[1] = r2_rep;
        6'd9: m_b[1] = k_w[2][0];
        6'd10: m_b[1] = k_w[2][1];
        6'd11: m_b[1] = k_w[2][2];
        6'd12: m_b[1] = k_w[2][3];
        6'd13: m_b[1] = k_w[3][0];
        6'd14: m_b[1] = k_w[3][1];
        6'd15: m_b[1] = k_w[3][2];
        6'd16: m_b[1] = k_w[3][3];
        6'd17: m_b[1] = k_w[0][0];
        6'd18: m_b[1] = k_w[0][1];
        6'd19: m_b[1] = k_w[0][2];
        6'd20: m_b[1] = k_w[0][3];
        6'd22: m_b[1] = r2_rep;

        6'd23: m_b[1] = q[0][0];
        6'd24: m_b[1] = q[4][0];
        6'd21: m_b[1] = q[3][2];
        default: m_b[1] = 32'b0;
    endcase
end
always @(*) begin  // m2_a
    case (counter)
        6'd5: m_a[2] = in_w[0][0];
        6'd6: m_a[2] = in_w[0][1];
        6'd7: m_a[2] = in_w[0][2];
        6'd8: m_a[2] = in_w[0][3];
        6'd10: m_a[2] = k[0][1];
        6'd13: m_a[2] = in_w[1][0];
        6'd14: m_a[2] = in_w[1][1];
        6'd15: m_a[2] = in_w[1][2];
        6'd16: m_a[2] = in_w[1][3];
        6'd17: m_a[2] = in_w[4][0];
        6'd18: m_a[2] = in_w[4][1];
        6'd19: m_a[2] = in_w[4][2];
        6'd20: m_a[2] = in_w[4][3];
        6'd22: m_a[2] = k[4][1];

        6'd11: m_a[2] = k[0][0];
        6'd23: m_a[2] = k[4][1];
        6'd24: m_a[2] = k[0][1];
        6'd21: m_a[2] = k[0][3];
        default: m_a[2] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        6'd5: m_b[2] = k_w[1][0];
        6'd6: m_b[2] = k_w[1][1];
        6'd7: m_b[2] = k_w[1][2];
        6'd8: m_b[2] = k_w[1][3];
        6'd10: m_b[2] = r2_rep;
        6'd13: m_b[2] = k_w[3][0];
        6'd14: m_b[2] = k_w[3][1];
        6'd15: m_b[2] = k_w[3][2];
        6'd16: m_b[2] = k_w[3][3];
        6'd17: m_b[2] = k_w[1][0];
        6'd18: m_b[2] = k_w[1][1];
        6'd19: m_b[2] = k_w[1][2];
        6'd20: m_b[2] = k_w[1][3];
        6'd22: m_b[2] = r2_rep;

        6'd11: m_b[2] = q[0][0];
        6'd23: m_b[2] = q[0][1];
        6'd24: m_b[2] = q[4][1];
        6'd21: m_b[2] = q[3][3];
        default: m_b[2] = 32'b0;
    endcase
end
always @(*) begin  // m3_a
    case (counter)
        6'd5: m_a[3] = in_w[1][0];
        6'd6: m_a[3] = in_w[1][1];
        6'd7: m_a[3] = in_w[1][2];
        6'd8: m_a[3] = in_w[1][3];
        6'd10: m_a[3] = k[1][1];
        6'd13: m_a[3] = in_w[2][0];
        6'd14: m_a[3] = in_w[2][1];
        6'd15: m_a[3] = in_w[2][2];
        6'd16: m_a[3] = in_w[2][3];
        6'd17: m_a[3] = in_w[4][0];
        6'd18: m_a[3] = in_w[4][1];
        6'd19: m_a[3] = in_w[4][2];
        6'd20: m_a[3] = in_w[4][3];
        6'd22: m_a[3] = k[4][2];

        6'd11: m_a[3] = k[0][1];
        6'd23: m_a[3] = k[4][0];
        6'd24: m_a[3] = k[1][0];

        6'd21: m_a[3] = k[1][2];
        default: m_a[3] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        6'd5: m_b[3] = k_w[1][0];
        6'd6: m_b[3] = k_w[1][1];
        6'd7: m_b[3] = k_w[1][2];
        6'd8: m_b[3] = k_w[1][3];
        6'd10: m_b[3] = r2_rep;
        6'd13: m_b[3] = k_w[3][0];
        6'd14: m_b[3] = k_w[3][1];
        6'd15: m_b[3] = k_w[3][2];
        6'd16: m_b[3] = k_w[3][3];
        6'd17: m_b[3] = k_w[2][0];
        6'd18: m_b[3] = k_w[2][1];
        6'd19: m_b[3] = k_w[2][2];
        6'd20: m_b[3] = k_w[2][3];
        6'd22: m_b[3] = r2_rep;

        6'd11: m_b[3] = q[0][1];
        6'd23: m_b[3] = q[1][0];
        6'd24: m_b[3] = q[4][0];
        6'd21: m_b[3] = q[3][2];
        default: m_b[3] = 32'b0;
    endcase
end
always @(*) begin  // m4_a
    case (counter)
        6'd5: m_a[4] = in_w[1][0];
        6'd6: m_a[4] = in_w[1][1];
        6'd7: m_a[4] = in_w[1][2];
        6'd8: m_a[4] = in_w[1][3];
        6'd10: m_a[4] = k[1][0];
        6'd13: m_a[4] = in_w[3][0];
        6'd14: m_a[4] = in_w[3][1];
        6'd15: m_a[4] = in_w[3][2];
        6'd16: m_a[4] = in_w[3][3];
        6'd17: m_a[4] = in_w[4][0];
        6'd18: m_a[4] = in_w[4][1];
        6'd19: m_a[4] = in_w[4][2];
        6'd20: m_a[4] = in_w[4][3];
        6'd22: m_a[4] = k[4][3];

        6'd11: m_a[4] = k[1][0];
        6'd23: m_a[4] = k[4][1];
        6'd24: m_a[4] = k[1][1];
        6'd21: m_a[4] = k[1][3];

        6'd32: m_a[4] = headout[0][0];
        6'd33: m_a[4] = headout[0][0];
        6'd34: m_a[4] = headout[0][0];
        6'd35: m_a[4] = headout[0][0];
        6'd36: m_a[4] = headout[1][0];
        6'd37: m_a[4] = headout[1][0];
        6'd38: m_a[4] = headout[1][0];
        6'd39: m_a[4] = headout[1][0];
        6'd40: m_a[4] = headout[2][0];
        6'd41: m_a[4] = headout[2][0];
        6'd42: m_a[4] = headout[2][0];
        6'd43: m_a[4] = headout[2][0];
        6'd44: m_a[4] = headout[3][0];
        6'd45: m_a[4] = headout[3][0];
        6'd46: m_a[4] = headout[3][0];
        6'd47: m_a[4] = headout[3][0];
        6'd48: m_a[4] = headout[4][0];
        6'd49: m_a[4] = headout[4][0];
        6'd50: m_a[4] = headout[4][0];
        6'd51: m_a[4] = headout[4][0];
        default: m_a[4] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        6'd5: m_b[4] = k_w[0][0];
        6'd6: m_b[4] = k_w[0][1];
        6'd7: m_b[4] = k_w[0][2];
        6'd8: m_b[4] = k_w[0][3];
        6'd10: m_b[4] = r2_rep;
        6'd13: m_b[4] = k_w[3][0];
        6'd14: m_b[4] = k_w[3][1];
        6'd15: m_b[4] = k_w[3][2];
        6'd16: m_b[4] = k_w[3][3];
        6'd17: m_b[4] = k_w[3][0];
        6'd18: m_b[4] = k_w[3][1];
        6'd19: m_b[4] = k_w[3][2];
        6'd20: m_b[4] = k_w[3][3];
        6'd22: m_b[4] = r2_rep;

        6'd11: m_b[4] = q[0][0];
        6'd23: m_b[4] = q[1][1];
        6'd24: m_b[4] = q[4][1];
        6'd21: m_b[4] = q[3][3];

        6'd32: m_b[4] = out_w[0][0];
        6'd33: m_b[4] = out_w[1][0];
        6'd34: m_b[4] = out_w[2][0];
        6'd35: m_b[4] = out_w[3][0];
        6'd36: m_b[4] = out_w[0][0];
        6'd37: m_b[4] = out_w[1][0];
        6'd38: m_b[4] = out_w[2][0];
        6'd39: m_b[4] = out_w[3][0];
        6'd40: m_b[4] = out_w[0][0];
        6'd41: m_b[4] = out_w[1][0];
        6'd42: m_b[4] = out_w[2][0];
        6'd43: m_b[4] = out_w[3][0];
        6'd44: m_b[4] = out_w[0][0];
        6'd45: m_b[4] = out_w[1][0];
        6'd46: m_b[4] = out_w[2][0];
        6'd47: m_b[4] = out_w[3][0];
        6'd48: m_b[4] = out_w[0][0];
        6'd49: m_b[4] = out_w[1][0];
        6'd50: m_b[4] = out_w[2][0];
        6'd51: m_b[4] = out_w[3][0];
        default: m_b[4] = 32'b0;
    endcase
end
always @(*) begin  // m5_a
    case (counter)
        6'd9: m_a[5] = in_w[1][0];
        6'd10: m_a[5] = in_w[1][1];
        6'd11: m_a[5] = in_w[1][2];
        6'd12: m_a[5] = in_w[1][3];
        6'd13: m_a[5] = in_w[3][0];
        6'd14: m_a[5] = in_w[3][1];
        6'd15: m_a[5] = in_w[3][2];
        6'd16: m_a[5] = in_w[3][3];
        6'd18: m_a[5] = k[0][3];

        6'd17: m_a[5] = in_w[0][0];

        6'd19: m_a[5] = k[0][0];
        6'd22: m_a[5] = k[3][0];
        6'd23: m_a[5] = k[4][0];
        6'd24: m_a[5] = k[2][0];
        6'd20: m_a[5] = k[0][2];
        6'd21: m_a[5] = k[2][2];

        6'd32: m_a[5] = headout[0][1];
        6'd33: m_a[5] = headout[0][1];
        6'd34: m_a[5] = headout[0][1];
        6'd35: m_a[5] = headout[0][1];
        6'd36: m_a[5] = headout[1][1];
        6'd37: m_a[5] = headout[1][1];
        6'd38: m_a[5] = headout[1][1];
        6'd39: m_a[5] = headout[1][1];
        6'd40: m_a[5] = headout[2][1];
        6'd41: m_a[5] = headout[2][1];
        6'd42: m_a[5] = headout[2][1];
        6'd43: m_a[5] = headout[2][1];
        6'd44: m_a[5] = headout[3][1];
        6'd45: m_a[5] = headout[3][1];
        6'd46: m_a[5] = headout[3][1];
        6'd47: m_a[5] = headout[3][1];
        6'd48: m_a[5] = headout[4][1];
        6'd49: m_a[5] = headout[4][1];
        6'd50: m_a[5] = headout[4][1];
        6'd51: m_a[5] = headout[4][1];
        default: m_a[5] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        6'd9: m_b[5] = k_w[2][0];
        6'd10: m_b[5] = k_w[2][1];
        6'd11: m_b[5] = k_w[2][2];
        6'd12: m_b[5] = k_w[2][3];
        6'd13: m_b[5] = k_w[2][0];
        6'd14: m_b[5] = k_w[2][1];
        6'd15: m_b[5] = k_w[2][2];
        6'd16: m_b[5] = k_w[2][3];
        6'd18: m_b[5] = r2_rep;

        6'd17: m_b[5] = v_w[3][0];

        6'd19: m_b[5] = q[3][0];
        6'd22: m_b[5] = q[0][0];
        6'd23: m_b[5] = q[2][0];
        6'd24: m_b[5] = q[4][0];
        6'd20: m_b[5] = q[1][2];
        6'd21: m_b[5] = q[3][2];

        6'd32: m_b[5] = out_w[0][1];
        6'd33: m_b[5] = out_w[1][1];
        6'd34: m_b[5] = out_w[2][1];
        6'd35: m_b[5] = out_w[3][1];
        6'd36: m_b[5] = out_w[0][1];
        6'd37: m_b[5] = out_w[1][1];
        6'd38: m_b[5] = out_w[2][1];
        6'd39: m_b[5] = out_w[3][1];
        6'd40: m_b[5] = out_w[0][1];
        6'd41: m_b[5] = out_w[1][1];
        6'd42: m_b[5] = out_w[2][1];
        6'd43: m_b[5] = out_w[3][1];
        6'd44: m_b[5] = out_w[0][1];
        6'd45: m_b[5] = out_w[1][1];
        6'd46: m_b[5] = out_w[2][1];
        6'd47: m_b[5] = out_w[3][1];
        6'd48: m_b[5] = out_w[0][1];
        6'd49: m_b[5] = out_w[1][1];
        6'd50: m_b[5] = out_w[2][1];
        6'd51: m_b[5] = out_w[3][1];
        default: m_b[5] = 32'b0;
    endcase
end
always @(*) begin  // m6_a
    case (counter)
        6'd9: m_a[6] = in_w[2][0];
        6'd10: m_a[6] = in_w[2][1];
        6'd11: m_a[6] = in_w[2][2];
        6'd12: m_a[6] = in_w[2][3];
        6'd13: m_a[6] = in_w[3][0];
        6'd14: m_a[6] = in_w[3][1];
        6'd15: m_a[6] = in_w[3][2];
        6'd16: m_a[6] = in_w[3][3];
        6'd18: m_a[6] = k[1][3];

        6'd17: m_a[6] = in_w[0][1];

        6'd19: m_a[6] = k[0][1];
        6'd22: m_a[6] = k[3][1];
        6'd23: m_a[6] = k[4][1];
        6'd24: m_a[6] = k[2][1];
        6'd20: m_a[6] = k[0][3];
        6'd21: m_a[6] = k[2][3];

        6'd32: m_a[6] = headout[0][2];
        6'd33: m_a[6] = headout[0][2];
        6'd34: m_a[6] = headout[0][2];
        6'd35: m_a[6] = headout[0][2];
        6'd36: m_a[6] = headout[1][2];
        6'd37: m_a[6] = headout[1][2];
        6'd38: m_a[6] = headout[1][2];
        6'd39: m_a[6] = headout[1][2];
        6'd40: m_a[6] = headout[2][2];
        6'd41: m_a[6] = headout[2][2];
        6'd42: m_a[6] = headout[2][2];
        6'd43: m_a[6] = headout[2][2];
        6'd44: m_a[6] = headout[3][2];
        6'd45: m_a[6] = headout[3][2];
        6'd46: m_a[6] = headout[3][2];
        6'd47: m_a[6] = headout[3][2];
        6'd48: m_a[6] = headout[4][2];
        6'd49: m_a[6] = headout[4][2];
        6'd50: m_a[6] = headout[4][2];
        6'd51: m_a[6] = headout[4][2];
        default: m_a[6] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        6'd9: m_b[6] = k_w[2][0];
        6'd10: m_b[6] = k_w[2][1];
        6'd11: m_b[6] = k_w[2][2];
        6'd12: m_b[6] = k_w[2][3];
        6'd13: m_b[6] = k_w[1][0];
        6'd14: m_b[6] = k_w[1][1];
        6'd15: m_b[6] = k_w[1][2];
        6'd16: m_b[6] = k_w[1][3];
        6'd18: m_b[6] = r2_rep;

        6'd17: m_b[6] = v_w[3][1];

        6'd19: m_b[6] = q[3][1];
        6'd22: m_b[6] = q[0][1];
        6'd23: m_b[6] = q[2][1];
        6'd24: m_b[6] = q[4][1];
        6'd20: m_b[6] = q[1][3];
        6'd21: m_b[6] = q[3][3];

        6'd32: m_b[6] = out_w[0][2];
        6'd33: m_b[6] = out_w[1][2];
        6'd34: m_b[6] = out_w[2][2];
        6'd35: m_b[6] = out_w[3][2];
        6'd36: m_b[6] = out_w[0][2];
        6'd37: m_b[6] = out_w[1][2];
        6'd38: m_b[6] = out_w[2][2];
        6'd39: m_b[6] = out_w[3][2];
        6'd40: m_b[6] = out_w[0][2];
        6'd41: m_b[6] = out_w[1][2];
        6'd42: m_b[6] = out_w[2][2];
        6'd43: m_b[6] = out_w[3][2];
        6'd44: m_b[6] = out_w[0][2];
        6'd45: m_b[6] = out_w[1][2];
        6'd46: m_b[6] = out_w[2][2];
        6'd47: m_b[6] = out_w[3][2];
        6'd48: m_b[6] = out_w[0][2];
        6'd49: m_b[6] = out_w[1][2];
        6'd50: m_b[6] = out_w[2][2];
        6'd51: m_b[6] = out_w[3][2];
        default: m_b[6] = 32'b0;
    endcase
end
always @(*) begin  // m7_a
    case (counter)
        6'd9: m_a[7] = in_w[2][0];
        6'd10: m_a[7] = in_w[2][1];
        6'd11: m_a[7] = in_w[2][2];
        6'd12: m_a[7] = in_w[2][3];
        6'd13: m_a[7] = in_w[3][0];
        6'd14: m_a[7] = in_w[3][1];
        6'd15: m_a[7] = in_w[3][2];
        6'd16: m_a[7] = in_w[3][3];
        6'd18: m_a[7] = k[2][3];

        6'd17: m_a[7] = in_w[4][0];

        6'd19: m_a[7] = k[1][0];
        6'd22: m_a[7] = k[3][0];
        6'd23: m_a[7] = k[4][0];
        6'd24: m_a[7] = k[3][0];
        6'd20: m_a[7] = k[1][2];
        6'd21: m_a[7] = k[3][2];

        6'd32: m_a[7] = headout[0][3];
        6'd33: m_a[7] = headout[0][3];
        6'd34: m_a[7] = headout[0][3];
        6'd35: m_a[7] = headout[0][3];
        6'd36: m_a[7] = headout[1][3];
        6'd37: m_a[7] = headout[1][3];
        6'd38: m_a[7] = headout[1][3];
        6'd39: m_a[7] = headout[1][3];
        6'd40: m_a[7] = headout[2][3];
        6'd41: m_a[7] = headout[2][3];
        6'd42: m_a[7] = headout[2][3];
        6'd43: m_a[7] = headout[2][3];
        6'd44: m_a[7] = headout[3][3];
        6'd45: m_a[7] = headout[3][3];
        6'd46: m_a[7] = headout[3][3];
        6'd47: m_a[7] = headout[3][3];
        6'd48: m_a[7] = headout[4][3];
        6'd49: m_a[7] = headout[4][3];
        6'd50: m_a[7] = headout[4][3];
        6'd51: m_a[7] = headout[4][3];
        default: m_a[7] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        6'd9: m_b[7] = k_w[1][0];
        6'd10: m_b[7] = k_w[1][1];
        6'd11: m_b[7] = k_w[1][2];
        6'd12: m_b[7] = k_w[1][3];
        6'd13: m_b[7] = k_w[0][0];
        6'd14: m_b[7] = k_w[0][1];
        6'd15: m_b[7] = k_w[0][2];
        6'd16: m_b[7] = k_w[0][3];
        6'd18: m_b[7] = r2_rep;

        6'd17: m_b[7] = v_w[1][0];

        6'd19: m_b[7] = q[3][0];
        6'd22: m_b[7] = q[1][0];
        6'd23: m_b[7] = q[3][0];
        6'd24: m_b[7] = q[4][0];
        6'd20: m_b[7] = q[1][2];
        6'd21: m_b[7] = q[0][2];

        6'd32: m_b[7] = out_w[0][3];
        6'd33: m_b[7] = out_w[1][3];
        6'd34: m_b[7] = out_w[2][3];
        6'd35: m_b[7] = out_w[3][3];
        6'd36: m_b[7] = out_w[0][3];
        6'd37: m_b[7] = out_w[1][3];
        6'd38: m_b[7] = out_w[2][3];
        6'd39: m_b[7] = out_w[3][3];
        6'd40: m_b[7] = out_w[0][3];
        6'd41: m_b[7] = out_w[1][3];
        6'd42: m_b[7] = out_w[2][3];
        6'd43: m_b[7] = out_w[3][3];
        6'd44: m_b[7] = out_w[0][3];
        6'd45: m_b[7] = out_w[1][3];
        6'd46: m_b[7] = out_w[2][3];
        6'd47: m_b[7] = out_w[3][3];
        6'd48: m_b[7] = out_w[0][3];
        6'd49: m_b[7] = out_w[1][3];
        6'd50: m_b[7] = out_w[2][3];
        6'd51: m_b[7] = out_w[3][3];
        default: m_b[7] = 32'b0;
    endcase
end
always @(*) begin  // m8_a
    case (counter)
        6'd9: m_a[8] = in_w[2][0];
        6'd10: m_a[8] = in_w[2][1];
        6'd11: m_a[8] = in_w[2][2];
        6'd12: m_a[8] = in_w[2][3];

        6'd1: m_a[8] = in_w[0][0];
        6'd2: m_a[8] = in_w[0][1];
        6'd3: m_a[8] = in_w[0][2];
        6'd4: m_a[8] = in_w[0][3];
        6'd5: m_a[8] = in_w[0][0];
        6'd6: m_a[8] = in_w[0][1];
        6'd7: m_a[8] = in_w[0][2];
        6'd8: m_a[8] = in_w[0][3];
        6'd13: m_a[8] = in_w[3][0];
        6'd14: m_a[8] = in_w[3][1];
        6'd15: m_a[8] = in_w[3][2];
        6'd16: m_a[8] = in_w[3][3];
        6'd17: m_a[8] = in_w[4][0];
        6'd18: m_a[8] = in_w[4][1];
        6'd19: m_a[8] = in_w[4][2];
        6'd20: m_a[8] = in_w[4][3];

        6'd22: m_a[8] = k[3][1];
        6'd23: m_a[8] = k[4][1];
        6'd24: m_a[8] = k[3][1];
        6'd21: m_a[8] = k[3][3];
        default: m_a[8] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        6'd9: m_b[8] = k_w[0][0];
        6'd10: m_b[8] = k_w[0][1];
        6'd11: m_b[8] = k_w[0][2];
        6'd12: m_b[8] = k_w[0][3];

        6'd1: m_b[8] = q_w[0][0];
        6'd2: m_b[8] = q_w[0][1];
        6'd3: m_b[8] = q_w[0][2];
        6'd4: m_b[8] = q_w[0][3];
        6'd5: m_b[8] = q_w[1][0];
        6'd6: m_b[8] = q_w[1][1];
        6'd7: m_b[8] = q_w[1][2];
        6'd8: m_b[8] = q_w[1][3];
        6'd13: m_b[8] = q_w[2][0];
        6'd14: m_b[8] = q_w[2][1];
        6'd15: m_b[8] = q_w[2][2];
        6'd16: m_b[8] = q_w[2][3];
        6'd17: m_b[8] = q_w[2][0];
        6'd18: m_b[8] = q_w[2][1];
        6'd19: m_b[8] = q_w[2][2];
        6'd20: m_b[8] = q_w[2][3];

        6'd22: m_b[8] = q[1][1];
        6'd23: m_b[8] = q[3][1];
        6'd24: m_b[8] = q[4][1];
        6'd21: m_b[8] = q[0][3];
        default: m_b[8] = 32'b0;
    endcase
end
always @(*) begin  // m9_a
    case (counter)
        6'd5: m_a[9] = in_w[1][0];
        6'd6: m_a[9] = in_w[1][1];
        6'd7: m_a[9] = in_w[1][2];
        6'd8: m_a[9] = in_w[1][3];
        6'd9: m_a[9] = in_w[2][0];
        6'd10: m_a[9] = in_w[2][1];
        6'd11: m_a[9] = in_w[2][2];
        6'd12: m_a[9] = in_w[2][3];
        6'd13: m_a[9] = in_w[3][0];
        6'd14: m_a[9] = in_w[3][1];
        6'd15: m_a[9] = in_w[3][2];
        6'd16: m_a[9] = in_w[3][3];
        6'd17: m_a[9] = in_w[4][0];
        6'd18: m_a[9] = in_w[4][1];
        6'd19: m_a[9] = in_w[4][2];
        6'd20: m_a[9] = in_w[4][3];

        6'd22: m_a[9] = k[3][0];
        6'd23: m_a[9] = k[4][0];

        6'd21: m_a[9] = k[3][2];
        6'd24: m_a[9] = k[0][2];
        default: m_a[9] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        6'd5: m_b[9] = q_w[1][0];
        6'd6: m_b[9] = q_w[1][1];
        6'd7: m_b[9] = q_w[1][2];
        6'd8: m_b[9] = q_w[1][3];
        6'd9: m_b[9] = q_w[1][0];
        6'd10: m_b[9] = q_w[1][1];
        6'd11: m_b[9] = q_w[1][2];
        6'd12: m_b[9] = q_w[1][3];
        6'd13: m_b[9] = q_w[1][0];
        6'd14: m_b[9] = q_w[1][1];
        6'd15: m_b[9] = q_w[1][2];
        6'd16: m_b[9] = q_w[1][3];
        6'd17: m_b[9] = q_w[1][0];
        6'd18: m_b[9] = q_w[1][1];
        6'd19: m_b[9] = q_w[1][2];
        6'd20: m_b[9] = q_w[1][3];

        6'd22: m_b[9] = q[2][0];
        6'd23: m_b[9] = q[4][0];
        6'd21: m_b[9] = q[1][2];
        6'd24: m_b[9] = q[4][2];
        default: m_b[9] = 32'b0;
    endcase
end
always @(*) begin  // m10_a
    case (counter)
        6'd5: m_a[10] = in_w[1][0];
        6'd6: m_a[10] = in_w[1][1];
        6'd7: m_a[10] = in_w[1][2];
        6'd8: m_a[10] = in_w[1][3];
        6'd9: m_a[10] = in_w[2][0];
        6'd10: m_a[10] = in_w[2][1];
        6'd11: m_a[10] = in_w[2][2];
        6'd12: m_a[10] = in_w[2][3];
        6'd13: m_a[10] = in_w[3][0];
        6'd14: m_a[10] = in_w[3][1];
        6'd15: m_a[10] = in_w[3][2];
        6'd16: m_a[10] = in_w[3][3];
        6'd17: m_a[10] = in_w[4][0];
        6'd18: m_a[10] = in_w[4][1];
        6'd19: m_a[10] = in_w[4][2];
        6'd20: m_a[10] = in_w[4][3];

        6'd22: m_a[10] = k[3][1];
        6'd23: m_a[10] = k[4][1];
        6'd21: m_a[10] = k[3][3];
        6'd24: m_a[10] = k[0][3];
        default: m_a[10] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        6'd5: m_b[10] = q_w[0][0];
        6'd6: m_b[10] = q_w[0][1];
        6'd7: m_b[10] = q_w[0][2];
        6'd8: m_b[10] = q_w[0][3];
        6'd9: m_b[10] = q_w[0][0];
        6'd10: m_b[10] = q_w[0][1];
        6'd11: m_b[10] = q_w[0][2];
        6'd12: m_b[10] = q_w[0][3];
        6'd13: m_b[10] = q_w[0][0];
        6'd14: m_b[10] = q_w[0][1];
        6'd15: m_b[10] = q_w[0][2];
        6'd16: m_b[10] = q_w[0][3];
        6'd17: m_b[10] = q_w[0][0];
        6'd18: m_b[10] = q_w[0][1];
        6'd19: m_b[10] = q_w[0][2];
        6'd20: m_b[10] = q_w[0][3];

        6'd22: m_b[10] = q[2][1];
        6'd23: m_b[10] = q[4][1];
        6'd21: m_b[10] = q[1][3];
        6'd24: m_b[10] = q[4][3];
        default: m_b[10] = 32'b0;
    endcase
end
always @(*) begin  // m11_a
    case (counter)
        6'd9: m_a[11] = in_w[0][0];
        6'd10: m_a[11] = in_w[0][1];
        6'd11: m_a[11] = in_w[0][2];
        6'd12: m_a[11] = in_w[0][3];
        6'd13: m_a[11] = in_w[0][0];
        6'd14: m_a[11] = in_w[0][1];
        6'd15: m_a[11] = in_w[0][2];
        6'd16: m_a[11] = in_w[0][3];
        6'd17: m_a[11] = in_w[4][0];
        6'd18: m_a[11] = in_w[4][1];
        6'd19: m_a[11] = in_w[4][2];
        6'd20: m_a[11] = in_w[4][3];

        6'd22: m_a[11] = k[3][0];
        6'd21: m_a[11] = k[3][2];
        6'd23: m_a[11] = k[4][2];
        6'd24: m_a[11] = k[1][2];

        6'd28: m_a[11] = score[1][0][0];
        6'd29: m_a[11] = score[2][0][0];
        6'd30: m_a[11] = score[1][1][0];
        6'd31: m_a[11] = score[2][1][0];
        6'd32: m_a[11] = score[1][2][0];
        6'd33: m_a[11] = score[2][2][0];
        6'd34: m_a[11] = score[1][3][0];
        6'd35: m_a[11] = score[2][3][0];
        6'd36: m_a[11] = score[1][4][0];
        6'd37: m_a[11] = score[2][4][0];
        default: m_a[11] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        6'd9: m_b[11] = q_w[2][0];
        6'd10: m_b[11] = q_w[2][1];
        6'd11: m_b[11] = q_w[2][2];
        6'd12: m_b[11] = q_w[2][3];
        6'd13: m_b[11] = q_w[3][0];
        6'd14: m_b[11] = q_w[3][1];
        6'd15: m_b[11] = q_w[3][2];
        6'd16: m_b[11] = q_w[3][3];
        6'd17: m_b[11] = q_w[3][0];
        6'd18: m_b[11] = q_w[3][1];
        6'd19: m_b[11] = q_w[3][2];
        6'd20: m_b[11] = q_w[3][3];

        6'd22: m_b[11] = q[3][0];
        6'd21: m_b[11] = q[2][2];
        6'd23: m_b[11] = q[0][2];
        6'd24: m_b[11] = q[4][2];

        6'd28: m_b[11] = v[0][0];
        6'd29: m_b[11] = v[0][2];
        6'd30: m_b[11] = v[0][0];
        6'd31: m_b[11] = v[0][2];
        6'd32: m_b[11] = v[0][0];
        6'd33: m_b[11] = v[0][2];
        6'd34: m_b[11] = v[0][0];
        6'd35: m_b[11] = v[0][2];
        6'd36: m_b[11] = v[0][0];
        6'd37: m_b[11] = v[0][2];
        default: m_b[11] = 32'b0;
    endcase
end
always @(*) begin  // m12_a
    case (counter)
        6'd18: m_a[12] = k[3][3];

        6'd9: m_a[12] = in_w[1][0];
        6'd10: m_a[12] = in_w[1][1];
        6'd11: m_a[12] = in_w[1][2];
        6'd12: m_a[12] = in_w[1][3];
        6'd13: m_a[12] = in_w[1][0];
        6'd14: m_a[12] = in_w[1][1];
        6'd15: m_a[12] = in_w[1][2];
        6'd16: m_a[12] = in_w[1][3];

        6'd17: m_a[12] = in_w[4][0];

        6'd19: m_a[12] = k[1][1];
        6'd22: m_a[12] = k[3][1];
        6'd21: m_a[12] = k[3][3];
        6'd23: m_a[12] = k[4][3];
        6'd24: m_a[12] = k[1][3];
        6'd20: m_a[12] = k[1][3];

        6'd28: m_a[12] = score[1][0][1];
        6'd29: m_a[12] = score[2][0][1];
        6'd30: m_a[12] = score[1][1][1];
        6'd31: m_a[12] = score[2][1][1];
        6'd32: m_a[12] = score[1][2][1];
        6'd33: m_a[12] = score[2][2][1];
        6'd34: m_a[12] = score[1][3][1];
        6'd35: m_a[12] = score[2][3][1];
        6'd36: m_a[12] = score[1][4][1];
        6'd37: m_a[12] = score[2][4][1];
        default: m_a[12] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        6'd18: m_b[12] = r2_rep;

        6'd9: m_b[12] = q_w[2][0];
        6'd10: m_b[12] = q_w[2][1];
        6'd11: m_b[12] = q_w[2][2];
        6'd12: m_b[12] = q_w[2][3];
        6'd13: m_b[12] = q_w[3][0];
        6'd14: m_b[12] = q_w[3][1];
        6'd15: m_b[12] = q_w[3][2];
        6'd16: m_b[12] = q_w[3][3];

        6'd17: m_b[12] = v_w[2][0];

        6'd19: m_b[12] = q[3][1];
        6'd22: m_b[12] = q[3][1];
        6'd21: m_b[12] = q[2][3];
        6'd23: m_b[12] = q[0][3];
        6'd24: m_b[12] = q[4][3];
        6'd20: m_b[12] = q[1][3];

        6'd28: m_b[12] = v[1][0];
        6'd29: m_b[12] = v[1][2];
        6'd30: m_b[12] = v[1][0];
        6'd31: m_b[12] = v[1][2];
        6'd32: m_b[12] = v[1][0];
        6'd33: m_b[12] = v[1][2];
        6'd34: m_b[12] = v[1][0];
        6'd35: m_b[12] = v[1][2];
        6'd36: m_b[12] = v[1][0];
        6'd37: m_b[12] = v[1][2];
        default: m_b[12] = 32'b0;
    endcase
end
always @(*) begin  // m13_a
    case (counter)
        6'd18: m_a[13] = k[3][2];

        6'd9: m_a[13] = in_w[2][0];
        6'd10: m_a[13] = in_w[2][1];
        6'd11: m_a[13] = in_w[2][2];
        6'd12: m_a[13] = in_w[2][3];
        6'd13: m_a[13] = in_w[2][0];
        6'd14: m_a[13] = in_w[2][1];
        6'd15: m_a[13] = in_w[2][2];
        6'd16: m_a[13] = in_w[2][3];

        6'd17: m_a[13] = in_w[1][0];
        6'd21: m_a[13] = in_w[3][2];
        6'd22: m_a[13] = in_w[3][3];

        6'd19: m_a[13] = k[2][0];
        6'd20: m_a[13] = k[2][2];
        6'd23: m_a[13] = k[4][2];
        6'd24: m_a[13] = k[2][2];

        6'd28: m_a[13] = score[1][0][2];
        6'd29: m_a[13] = score[2][0][2];
        6'd30: m_a[13] = score[1][1][2];
        6'd31: m_a[13] = score[2][1][2];
        6'd32: m_a[13] = score[1][2][2];
        6'd33: m_a[13] = score[2][2][2];
        6'd34: m_a[13] = score[1][3][2];
        6'd35: m_a[13] = score[2][3][2];
        6'd36: m_a[13] = score[1][4][2];
        6'd37: m_a[13] = score[2][4][2];
        default: m_a[13] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        6'd18: m_b[13] = r2_rep;

        6'd9: m_b[13] = q_w[2][0];
        6'd10: m_b[13] = q_w[2][1];
        6'd11: m_b[13] = q_w[2][2];
        6'd12: m_b[13] = q_w[2][3];
        6'd13: m_b[13] = q_w[3][0];
        6'd14: m_b[13] = q_w[3][1];
        6'd15: m_b[13] = q_w[3][2];
        6'd16: m_b[13] = q_w[3][3];

        6'd17: m_b[13] = v_w[3][0];
        6'd21: m_b[13] = v_w[3][2];
        6'd22: m_b[13] = v_w[3][3];

        6'd19: m_b[13] = q[3][0];
        6'd20: m_b[13] = q[1][2];
        6'd23: m_b[13] = q[1][2];
        6'd24: m_b[13] = q[4][2];

        6'd28: m_b[13] = v[2][0];
        6'd29: m_b[13] = v[2][2];
        6'd30: m_b[13] = v[2][0];
        6'd31: m_b[13] = v[2][2];
        6'd32: m_b[13] = v[2][0];
        6'd33: m_b[13] = v[2][2];
        6'd34: m_b[13] = v[2][0];
        6'd35: m_b[13] = v[2][2];
        6'd36: m_b[13] = v[2][0];
        6'd37: m_b[13] = v[2][2];
        default: m_b[13] = 32'b0;
    endcase
end
always @(*) begin  // m14_a
    case (counter)
        6'd18: m_a[14] = k[3][1];

        6'd13: m_a[14] = in_w[3][0];
        6'd14: m_a[14] = in_w[3][1];
        6'd15: m_a[14] = in_w[3][2];
        6'd16: m_a[14] = in_w[3][3];

        6'd9: m_a[14] = in_w[2][0];
        6'd10: m_a[14] = in_w[2][1];
        6'd12: m_a[14] = in_w[2][2];
        6'd17: m_a[14] = in_w[1][1];
        6'd21: m_a[14] = in_w[0][2];
        6'd22: m_a[14] = in_w[1][3];

        6'd11: m_a[14] = k[1][1];
        6'd19: m_a[14] = k[2][1];
        6'd20: m_a[14] = k[2][3];
        6'd23: m_a[14] = k[4][3];
        6'd24: m_a[14] = k[2][3];

        6'd28: m_a[14] = score[1][0][3];
        6'd29: m_a[14] = score[2][0][3];
        6'd30: m_a[14] = score[1][1][3];
        6'd31: m_a[14] = score[2][1][3];
        6'd32: m_a[14] = score[1][2][3];
        6'd33: m_a[14] = score[2][2][3];
        6'd34: m_a[14] = score[1][3][3];
        6'd35: m_a[14] = score[2][3][3];
        6'd36: m_a[14] = score[1][4][3];
        6'd37: m_a[14] = score[2][4][3];
        default: m_a[14] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        6'd18: m_b[14] = r2_rep;

        6'd13: m_b[14] = q_w[3][0];
        6'd14: m_b[14] = q_w[3][1];
        6'd15: m_b[14] = q_w[3][2];
        6'd16: m_b[14] = q_w[3][3];

        6'd9: m_b[14] = v_w[1][0];
        6'd10: m_b[14] = v_w[1][1];
        6'd12: m_b[14] = v_w[1][2];
        6'd17: m_b[14] = v_w[3][1];
        6'd21: m_b[14] = v_w[3][2];
        6'd22: m_b[14] = v_w[3][3];

        6'd11: m_b[14] = q[0][1];
        6'd19: m_b[14] = q[3][1];
        6'd20: m_b[14] = q[1][3];
        6'd23: m_b[14] = q[1][3];
        6'd24: m_b[14] = q[4][3];

        6'd28: m_b[14] = v[3][0];
        6'd29: m_b[14] = v[3][2];
        6'd30: m_b[14] = v[3][0];
        6'd31: m_b[14] = v[3][2];
        6'd32: m_b[14] = v[3][0];
        6'd33: m_b[14] = v[3][2];
        6'd34: m_b[14] = v[3][0];
        6'd35: m_b[14] = v[3][2];
        6'd36: m_b[14] = v[3][0];
        6'd37: m_b[14] = v[3][2];
        default: m_b[14] = 32'b0;
    endcase
end
always @(*) begin  // m15_a
    case (counter)
        6'd14: m_a[15] = k[0][2];
        6'd18: m_a[15] = k[3][0];

        6'd1: m_a[15] = in_w[0][0];
        6'd2: m_a[15] = in_w[0][1];
        6'd3: m_a[15] = in_w[0][2];
        6'd4: m_a[15] = in_w[0][3];
        6'd5: m_a[15] = in_w[0][0];
        6'd6: m_a[15] = in_w[0][1];
        6'd7: m_a[15] = in_w[0][2];
        6'd8: m_a[15] = in_w[0][3];
        6'd9: m_a[15] = in_w[0][0];
        6'd10: m_a[15] = in_w[0][1];
        6'd11: m_a[15] = in_w[0][2];
        6'd12: m_a[15] = in_w[0][3];
        6'd13: m_a[15] = in_w[2][3];
        6'd16: m_a[15] = in_w[2][0];
        6'd17: m_a[15] = in_w[3][1];
        6'd21: m_a[15] = in_w[1][2];
        6'd22: m_a[15] = in_w[4][1];
        6'd24: m_a[15] = in_w[4][2];
        6'd25: m_a[15] = in_w[4][3];

        6'd15: m_a[15] = k[2][0];
        6'd19: m_a[15] = k[0][2];
        6'd20: m_a[15] = k[0][2];
        6'd23: m_a[15] = k[4][2];

        6'd28: m_a[15] = score[1][0][4];
        6'd29: m_a[15] = score[2][0][4];
        6'd30: m_a[15] = score[1][1][4];
        6'd31: m_a[15] = score[2][1][4];
        6'd32: m_a[15] = score[1][2][4];
        6'd33: m_a[15] = score[2][2][4];
        6'd34: m_a[15] = score[1][3][4];
        6'd35: m_a[15] = score[2][3][4];
        6'd36: m_a[15] = score[1][4][4];
        6'd37: m_a[15] = score[2][4][4];
        default: m_a[15] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        6'd14: m_b[15] = r2_rep;
        6'd18: m_b[15] = r2_rep;

        6'd1: m_b[15] = v_w[0][0];
        6'd2: m_b[15] = v_w[0][1];
        6'd3: m_b[15] = v_w[0][2];
        6'd4: m_b[15] = v_w[0][3];
        6'd5: m_b[15] = v_w[1][0];
        6'd6: m_b[15] = v_w[1][1];
        6'd7: m_b[15] = v_w[1][2];
        6'd8: m_b[15] = v_w[1][3];
        6'd9: m_b[15] = v_w[2][0];
        6'd10: m_b[15] = v_w[2][1];
        6'd11: m_b[15] = v_w[2][2];
        6'd12: m_b[15] = v_w[2][3];
        6'd13: m_b[15] = v_w[1][3];
        6'd16: m_b[15] = v_w[3][0];
        6'd17: m_b[15] = v_w[3][1];
        6'd21: m_b[15] = v_w[3][2];
        6'd22: m_b[15] = v_w[1][1];
        6'd24: m_b[15] = v_w[1][2];
        6'd25: m_b[15] = v_w[1][3];

        6'd15: m_b[15] = q[0][0];
        6'd19: m_b[15] = q[0][2];
        6'd20: m_b[15] = q[2][2];
        6'd23: m_b[15] = q[2][2];

        6'd28: m_b[15] = v[4][0];
        6'd29: m_b[15] = v[4][2];
        6'd30: m_b[15] = v[4][0];
        6'd31: m_b[15] = v[4][2];
        6'd32: m_b[15] = v[4][0];
        6'd33: m_b[15] = v[4][2];
        6'd34: m_b[15] = v[4][0];
        6'd35: m_b[15] = v[4][2];
        6'd36: m_b[15] = v[4][0];
        6'd37: m_b[15] = v[4][2];
        default: m_b[15] = 32'b0;
    endcase
end
always @(*) begin  // m16_a
    case (counter)
        6'd14: m_a[16] = k[1][2];

        6'd5: m_a[16] = in_w[1][0];
        6'd6: m_a[16] = in_w[1][1];
        6'd7: m_a[16] = in_w[1][2];
        6'd8: m_a[16] = in_w[1][3];
        6'd9: m_a[16] = in_w[1][0];
        6'd10: m_a[16] = in_w[1][1];
        6'd11: m_a[16] = in_w[1][2];
        6'd12: m_a[16] = in_w[1][3];
        6'd13: m_a[16] = in_w[3][0];
        6'd16: m_a[16] = in_w[2][1];
        6'd17: m_a[16] = in_w[3][1];
        6'd18: m_a[16] = in_w[3][2];
        6'd21: m_a[16] = in_w[3][3];
        6'd22: m_a[16] = in_w[4][1];
        6'd24: m_a[16] = in_w[4][2];
        6'd25: m_a[16] = in_w[4][3];

        6'd15: m_a[16] = k[2][1];
        6'd19: m_a[16] = k[0][3];
        6'd20: m_a[16] = k[0][3];
        6'd23: m_a[16] = k[4][3];

        6'd28: m_a[16] = score[1][0][0];
        6'd29: m_a[16] = score[2][0][0];
        6'd30: m_a[16] = score[1][1][0];
        6'd31: m_a[16] = score[2][1][0];
        6'd32: m_a[16] = score[1][2][0];
        6'd33: m_a[16] = score[2][2][0];
        6'd34: m_a[16] = score[1][3][0];
        6'd35: m_a[16] = score[2][3][0];
        6'd36: m_a[16] = score[1][4][0];
        6'd37: m_a[16] = score[2][4][0];
        default: m_a[16] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        6'd14: m_b[16] = r2_rep;

        6'd5: m_b[16] = v_w[1][0];
        6'd6: m_b[16] = v_w[1][1];
        6'd7: m_b[16] = v_w[1][2];
        6'd8: m_b[16] = v_w[1][3];
        6'd9: m_b[16] = v_w[2][0];
        6'd10: m_b[16] = v_w[2][1];
        6'd11: m_b[16] = v_w[2][2];
        6'd12: m_b[16] = v_w[2][3];
        6'd13: m_b[16] = v_w[0][0];
        6'd16: m_b[16] = v_w[3][1];
        6'd17: m_b[16] = v_w[0][1];
        6'd18: m_b[16] = v_w[0][2];
        6'd21: m_b[16] = v_w[0][3];
        6'd22: m_b[16] = v_w[2][1];
        6'd24: m_b[16] = v_w[2][2];
        6'd25: m_b[16] = v_w[2][3];

        6'd15: m_b[16] = q[0][1];
        6'd19: m_b[16] = q[0][3];
        6'd20: m_b[16] = q[2][3];
        6'd23: m_b[16] = q[2][3];

        6'd28: m_b[16] = v[0][1];
        6'd29: m_b[16] = v[0][3];
        6'd30: m_b[16] = v[0][1];
        6'd31: m_b[16] = v[0][3];
        6'd32: m_b[16] = v[0][1];
        6'd33: m_b[16] = v[0][3];
        6'd34: m_b[16] = v[0][1];
        6'd35: m_b[16] = v[0][3];
        6'd36: m_b[16] = v[0][1];
        6'd37: m_b[16] = v[0][3];
        default: m_b[16] = 32'b0;
    endcase
end
always @(*) begin  // m17_a
    case (counter)
        6'd14: m_a[17] = k[2][2];

        6'd5: m_a[17] = in_w[1][0];
        6'd6: m_a[17] = in_w[1][1];
        6'd7: m_a[17] = in_w[1][2];
        6'd8: m_a[17] = in_w[1][3];
        6'd9: m_a[17] = in_w[2][0];
        6'd10: m_a[17] = in_w[2][1];
        6'd12: m_a[17] = in_w[2][2];
        6'd13: m_a[17] = in_w[2][3];
        6'd17: m_a[17] = in_w[2][2];
        6'd18: m_a[17] = in_w[4][0];
        6'd21: m_a[17] = in_w[2][3];
        6'd22: m_a[17] = in_w[0][3];
        6'd24: m_a[17] = in_w[4][2];
        6'd25: m_a[17] = in_w[4][3];

        6'd11: m_a[17] = k[0][0];
        6'd15: m_a[17] = k[2][0];
        6'd16: m_a[17] = k[0][0];
        6'd19: m_a[17] = k[1][2];
        6'd20: m_a[17] = k[1][2];
        6'd23: m_a[17] = k[4][2];

        6'd28: m_a[17] = score[1][0][1];
        6'd29: m_a[17] = score[2][0][1];
        6'd30: m_a[17] = score[1][1][1];
        6'd31: m_a[17] = score[2][1][1];
        6'd32: m_a[17] = score[1][2][1];
        6'd33: m_a[17] = score[2][2][1];
        6'd34: m_a[17] = score[1][3][1];
        6'd35: m_a[17] = score[2][3][1];
        6'd36: m_a[17] = score[1][4][1];
        6'd37: m_a[17] = score[2][4][1];
        default: m_a[17] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        6'd14: m_b[17] = r2_rep;

        6'd5: m_b[17] = v_w[0][0];
        6'd6: m_b[17] = v_w[0][1];
        6'd7: m_b[17] = v_w[0][2];
        6'd8: m_b[17] = v_w[0][3];
        6'd9: m_b[17] = v_w[0][0];
        6'd10: m_b[17] = v_w[0][1];
        6'd12: m_b[17] = v_w[0][2];
        6'd13: m_b[17] = v_w[0][3];
        6'd17: m_b[17] = v_w[3][2];
        6'd18: m_b[17] = v_w[3][0];
        6'd21: m_b[17] = v_w[3][3];
        6'd22: m_b[17] = v_w[3][3];
        6'd24: m_b[17] = v_w[3][2];
        6'd25: m_b[17] = v_w[3][3];

        6'd11: m_b[17] = q[1][0];
        6'd15: m_b[17] = q[1][0];
        6'd16: m_b[17] = q[2][0];
        6'd19: m_b[17] = q[0][2];
        6'd20: m_b[17] = q[2][2];
        6'd23: m_b[17] = q[3][2];

        6'd28: m_b[17] = v[1][1];
        6'd29: m_b[17] = v[1][3];
        6'd30: m_b[17] = v[1][1];
        6'd31: m_b[17] = v[1][3];
        6'd32: m_b[17] = v[1][1];
        6'd33: m_b[17] = v[1][3];
        6'd34: m_b[17] = v[1][1];
        6'd35: m_b[17] = v[1][3];
        6'd36: m_b[17] = v[1][1];
        6'd37: m_b[17] = v[1][3];
        default: m_b[17] = 32'b0;
    endcase
end
always @(*) begin  // m18_a
    case (counter)
        6'd14: m_a[18] = k[2][1];

        6'd9: m_a[18] = in_w[2][0];
        6'd10: m_a[18] = in_w[2][1];
        6'd12: m_a[18] = in_w[2][2];
        6'd13: m_a[18] = in_w[2][3];
        6'd17: m_a[18] = in_w[4][0];
        6'd18: m_a[18] = in_w[4][1];
        6'd21: m_a[18] = in_w[4][1];
        6'd22: m_a[18] = in_w[4][2];
        6'd24: m_a[18] = in_w[4][3];

        6'd11: m_a[18] = k[0][1];
        6'd15: m_a[18] = k[2][1];
        6'd16: m_a[18] = k[0][1];
        6'd19: m_a[18] = k[1][3];
        6'd20: m_a[18] = k[1][3];
        6'd23: m_a[18] = k[4][3];

        6'd28: m_a[18] = score[1][0][2];
        6'd29: m_a[18] = score[2][0][2];
        6'd30: m_a[18] = score[1][1][2];
        6'd31: m_a[18] = score[2][1][2];
        6'd32: m_a[18] = score[1][2][2];
        6'd33: m_a[18] = score[2][2][2];
        6'd34: m_a[18] = score[1][3][2];
        6'd35: m_a[18] = score[2][3][2];
        6'd36: m_a[18] = score[1][4][2];
        6'd37: m_a[18] = score[2][4][2];
        default: m_a[18] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        6'd14: m_b[18] = r2_rep;

        6'd9: m_b[18] = v_w[2][0];
        6'd10: m_b[18] = v_w[2][1];
        6'd12: m_b[18] = v_w[2][2];
        6'd13: m_b[18] = v_w[2][3];
        6'd17: m_b[18] = v_w[0][0];
        6'd18: m_b[18] = v_w[3][1];
        6'd21: m_b[18] = v_w[0][1];
        6'd22: m_b[18] = v_w[0][2];
        6'd24: m_b[18] = v_w[0][3];

        6'd11: m_b[18] = q[1][1];
        6'd15: m_b[18] = q[1][1];
        6'd16: m_b[18] = q[2][1];
        6'd19: m_b[18] = q[0][3];
        6'd20: m_b[18] = q[2][3];
        6'd23: m_b[18] = q[3][3];

        6'd28: m_b[18] = v[2][1];
        6'd29: m_b[18] = v[2][3];
        6'd30: m_b[18] = v[2][1];
        6'd31: m_b[18] = v[2][3];
        6'd32: m_b[18] = v[2][1];
        6'd33: m_b[18] = v[2][3];
        6'd34: m_b[18] = v[2][1];
        6'd35: m_b[18] = v[2][3];
        6'd36: m_b[18] = v[2][1];
        6'd37: m_b[18] = v[2][3];
        default: m_b[18] = 32'b0;
    endcase
end
always @(*) begin  // m19_a
    case (counter)
        6'd14: m_a[19] = k[2][0];

        6'd13: m_a[19] = in_w[3][0];
        6'd17: m_a[19] = in_w[3][1];
        6'd18: m_a[19] = in_w[3][2];
        6'd21: m_a[19] = in_w[3][3];

        6'd11: m_a[19] = k[1][0];
        6'd15: m_a[19] = k[2][0];
        6'd16: m_a[19] = k[1][0];
        6'd19: m_a[19] = k[2][2];
        6'd20: m_a[19] = k[2][2];
        6'd22: m_a[19] = k[3][2];
        6'd23: m_a[19] = k[4][2];
        6'd24: m_a[19] = k[3][2];
        
        6'd28: m_a[19] = score[1][0][3];
        6'd29: m_a[19] = score[2][0][3];
        6'd30: m_a[19] = score[1][1][3];
        6'd31: m_a[19] = score[2][1][3];
        6'd32: m_a[19] = score[1][2][3];
        6'd33: m_a[19] = score[2][2][3];
        6'd34: m_a[19] = score[1][3][3];
        6'd35: m_a[19] = score[2][3][3];
        6'd36: m_a[19] = score[1][4][3];
        6'd37: m_a[19] = score[2][4][3];
        default: m_a[19] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        6'd14: m_b[19] = r2_rep;

        6'd13: m_b[19] = v_w[1][0];
        6'd17: m_b[19] = v_w[1][1];
        6'd18: m_b[19] = v_w[1][2];
        6'd21: m_b[19] = v_w[1][3];

        6'd11: m_b[19] = q[1][0];
        6'd15: m_b[19] = q[2][0];
        6'd16: m_b[19] = q[2][0];
        6'd19: m_b[19] = q[0][2];
        6'd20: m_b[19] = q[2][2];
        6'd22: m_b[19] = q[3][2];
        6'd23: m_b[19] = q[4][2];
        6'd24: m_b[19] = q[4][2];

        6'd28: m_b[19] = v[3][1];
        6'd29: m_b[19] = v[3][3];
        6'd30: m_b[19] = v[3][1];
        6'd31: m_b[19] = v[3][3];
        6'd32: m_b[19] = v[3][1];
        6'd33: m_b[19] = v[3][3];
        6'd34: m_b[19] = v[3][1];
        6'd35: m_b[19] = v[3][3];
        6'd36: m_b[19] = v[3][1];
        6'd37: m_b[19] = v[3][3];
        default: m_b[19] = 32'b0;
    endcase
end
always @(*) begin  // m20_a
    case (counter)
        6'd13: m_a[20] = in_w[3][0];
        6'd14: m_a[20] = in_w[3][0];
        6'd17: m_a[20] = in_w[3][1];
        6'd18: m_a[20] = in_w[3][2];
        6'd21: m_a[20] = in_w[3][3];

        6'd11: m_a[20] = k[1][1];
        6'd15: m_a[20] = k[2][1];
        6'd16: m_a[20] = k[1][1];
        6'd19: m_a[20] = k[2][3];
        6'd20: m_a[20] = k[2][3];
        6'd22: m_a[20] = k[3][3];
        6'd23: m_a[20] = k[4][3];
        6'd24: m_a[20] = k[3][3];

        6'd28: m_a[20] = score[1][0][4];
        6'd29: m_a[20] = score[2][0][4];
        6'd30: m_a[20] = score[1][1][4];
        6'd31: m_a[20] = score[2][1][4];
        6'd32: m_a[20] = score[1][2][4];
        6'd33: m_a[20] = score[2][2][4];
        6'd34: m_a[20] = score[1][3][4];
        6'd35: m_a[20] = score[2][3][4];
        6'd36: m_a[20] = score[1][4][4];
        6'd37: m_a[20] = score[2][4][4];
        default: m_a[20] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        6'd13: m_b[20] = v_w[2][0];
        6'd14: m_b[20] = v_w[3][0];
        6'd17: m_b[20] = v_w[2][1];
        6'd18: m_b[20] = v_w[2][2];
        6'd21: m_b[20] = v_w[2][3];

        6'd11: m_b[20] = q[1][1];
        6'd15: m_b[20] = q[2][1];
        6'd16: m_b[20] = q[2][1];
        6'd19: m_b[20] = q[0][3];
        6'd20: m_b[20] = q[2][3];
        6'd22: m_b[20] = q[3][3];
        6'd23: m_b[20] = q[4][3];
        6'd24: m_b[20] = q[4][3];

        6'd28: m_b[20] = v[4][1];
        6'd29: m_b[20] = v[4][3];
        6'd30: m_b[20] = v[4][1];
        6'd31: m_b[20] = v[4][3];
        6'd32: m_b[20] = v[4][1];
        6'd33: m_b[20] = v[4][3];
        6'd34: m_b[20] = v[4][1];
        6'd35: m_b[20] = v[4][3];
        6'd36: m_b[20] = v[4][1];
        6'd37: m_b[20] = v[4][3];
        default: m_b[20] = 32'b0;
    endcase
end
//---------------------------------------------------------------------
// FP_ADD
//---------------------------------------------------------------------
always @(*) begin // add1_a
    case (counter)
        6'd3: add_a[1] = k[0][0];
        6'd4: add_a[1] = k[0][0];
        6'd5: add_a[1] = k[0][0];
        6'd11: add_a[1] = k[0][2];
        6'd12: add_a[1] = k[0][2];
        6'd13: add_a[1] = k[0][2];
        6'd15: add_a[1] = k[0][3];
        6'd16: add_a[1] = k[0][3];
        6'd17: add_a[1] = k[0][3];
        6'd19: add_a[1] = k[4][0];
        6'd20: add_a[1] = k[4][0];
        6'd21: add_a[1] = k[4][0];

        6'd29: add_a[1] = add_z[11];
        6'd30: add_a[1] = add_z[11];
        6'd31: add_a[1] = add_z[11];
        6'd32: add_a[1] = add_z[11];
        6'd33: add_a[1] = add_z[11];
        6'd34: add_a[1] = add_z[11];
        6'd35: add_a[1] = add_z[11];
        6'd36: add_a[1] = add_z[11];
        6'd37: add_a[1] = add_z[11];
        6'd38: add_a[1] = add_z[11];
        6'd39: add_a[1] = add_z[11];
        6'd40: add_a[1] = add_z[11];
        6'd41: add_a[1] = add_z[11];
        6'd42: add_a[1] = add_z[11];
        6'd43: add_a[1] = add_z[11];
        6'd44: add_a[1] = add_z[11];
        6'd45: add_a[1] = add_z[11];
        6'd46: add_a[1] = add_z[11];
        6'd47: add_a[1] = add_z[11];
        6'd48: add_a[1] = add_z[11];
        default: add_a[1] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        6'd29: add_b[1] = add_z[13];
        6'd30: add_b[1] = add_z[13];
        6'd31: add_b[1] = add_z[13];
        6'd32: add_b[1] = add_z[13];
        6'd33: add_b[1] = add_z[13];
        6'd34: add_b[1] = add_z[13];
        6'd35: add_b[1] = add_z[13];
        6'd36: add_b[1] = add_z[13];
        6'd37: add_b[1] = add_z[13];
        6'd38: add_b[1] = add_z[13];
        6'd39: add_b[1] = add_z[13];
        6'd40: add_b[1] = add_z[13];
        6'd41: add_b[1] = add_z[13];
        6'd42: add_b[1] = add_z[13];
        6'd43: add_b[1] = add_z[13];
        6'd44: add_b[1] = add_z[13];
        6'd45: add_b[1] = add_z[13];
        6'd46: add_b[1] = add_z[13];
        6'd47: add_b[1] = add_z[13];
        6'd48: add_b[1] = add_z[13];
        default: add_b[1] = m_reg[1];
    endcase
end
always @(*) begin // add2_a
    case (counter)
        6'd7: add_a[2] = k[0][1];
        6'd8: add_a[2] = k[0][1];
        6'd9: add_a[2] = k[0][1];
        6'd15: add_a[2] = k[1][3];
        6'd16: add_a[2] = k[1][3];
        6'd17: add_a[2] = k[1][3];
        6'd19: add_a[2] = k[4][1];
        6'd20: add_a[2] = k[4][1];
        6'd21: add_a[2] = k[4][1];

        6'd24: add_a[2] = m_reg[1];
        6'd25: add_a[2] = m_reg[1];
        6'd22: add_a[2] = m_reg[1];

        6'd33: add_a[2] = add_z[5];
        6'd34: add_a[2] = add_z[5];
        6'd35: add_a[2] = add_z[5];
        6'd36: add_a[2] = add_z[5];
        6'd37: add_a[2] = add_z[5];
        6'd38: add_a[2] = add_z[5];
        6'd39: add_a[2] = add_z[5];
        6'd40: add_a[2] = add_z[5];
        6'd41: add_a[2] = add_z[5];
        6'd42: add_a[2] = add_z[5];
        6'd43: add_a[2] = add_z[5];
        6'd44: add_a[2] = add_z[5];
        6'd45: add_a[2] = add_z[5];
        6'd46: add_a[2] = add_z[5];
        6'd47: add_a[2] = add_z[5];
        6'd48: add_a[2] = add_z[5];
        6'd49: add_a[2] = add_z[5];
        6'd50: add_a[2] = add_z[5];
        6'd51: add_a[2] = add_z[5];
        6'd52: add_a[2] = add_z[5];
        default: add_a[2] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        6'd33: add_b[2] = add_z[7];
        6'd34: add_b[2] = add_z[7];
        6'd35: add_b[2] = add_z[7];
        6'd36: add_b[2] = add_z[7];
        6'd37: add_b[2] = add_z[7];
        6'd38: add_b[2] = add_z[7];
        6'd39: add_b[2] = add_z[7];
        6'd40: add_b[2] = add_z[7];
        6'd41: add_b[2] = add_z[7];
        6'd42: add_b[2] = add_z[7];
        6'd43: add_b[2] = add_z[7];
        6'd44: add_b[2] = add_z[7];
        6'd45: add_b[2] = add_z[7];
        6'd46: add_b[2] = add_z[7];
        6'd47: add_b[2] = add_z[7];
        6'd48: add_b[2] = add_z[7];
        6'd49: add_b[2] = add_z[7];
        6'd50: add_b[2] = add_z[7];
        6'd51: add_b[2] = add_z[7];
        6'd52: add_b[2] = add_z[7];
        default: add_b[2] = m_reg[2];
    endcase
end
always @(*) begin // add3_a
    case (counter)
        6'd7: add_a[3] = k[1][1];
        6'd8: add_a[3] = k[1][1];
        6'd9: add_a[3] = k[1][1];
        6'd15: add_a[3] = k[2][3];
        6'd16: add_a[3] = k[2][3];
        6'd17: add_a[3] = k[2][3];
        6'd19: add_a[3] = k[4][2];
        6'd20: add_a[3] = k[4][2];
        6'd21: add_a[3] = k[4][2];

        6'd12: add_a[3] = m_reg[2];

        6'd30: add_a[3] = head_part[0][0];
        6'd31: add_a[3] = head_part[0][0];
        6'd32: add_a[3] = head_part[0][0];
        6'd33: add_a[3] = head_part[0][0];
        6'd34: add_a[3] = head_part[0][0];
        6'd35: add_a[3] = head_part[0][0];
        6'd36: add_a[3] = head_part[0][0];
        6'd37: add_a[3] = head_part[0][0];
        6'd38: add_a[3] = head_part[0][0];
        6'd39: add_a[3] = head_part[0][0];
        6'd40: add_a[3] = head_part[0][0];
        6'd41: add_a[3] = head_part[0][0];
        6'd42: add_a[3] = head_part[0][0];
        6'd43: add_a[3] = head_part[0][0];
        6'd44: add_a[3] = head_part[0][0];
        6'd45: add_a[3] = head_part[0][0];
        6'd46: add_a[3] = head_part[0][0];
        6'd47: add_a[3] = head_part[0][0];
        6'd48: add_a[3] = head_part[0][0];
        6'd49: add_a[3] = head_part[0][0];
        default: add_a[3] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        6'd30: add_b[3] = head_part[0][1];
        6'd31: add_b[3] = head_part[0][1];
        6'd32: add_b[3] = head_part[0][1];
        6'd33: add_b[3] = head_part[0][1];
        6'd34: add_b[3] = head_part[0][1];
        6'd35: add_b[3] = head_part[0][1];
        6'd36: add_b[3] = head_part[0][1];
        6'd37: add_b[3] = head_part[0][1];
        6'd38: add_b[3] = head_part[0][1];
        6'd39: add_b[3] = head_part[0][1];
        6'd40: add_b[3] = head_part[0][1];
        6'd41: add_b[3] = head_part[0][1];
        6'd42: add_b[3] = head_part[0][1];
        6'd43: add_b[3] = head_part[0][1];
        6'd44: add_b[3] = head_part[0][1];
        6'd45: add_b[3] = head_part[0][1];
        6'd46: add_b[3] = head_part[0][1];
        6'd47: add_b[3] = head_part[0][1];
        6'd48: add_b[3] = head_part[0][1];
        6'd49: add_b[3] = head_part[0][1];
        default: add_b[3] = m_reg[3];
    endcase
end
always @(*) begin // add4_a
    case (counter)
        6'd7: add_a[4] = k[1][0];
        6'd8: add_a[4] = k[1][0];
        6'd9: add_a[4] = k[1][0];
        6'd15: add_a[4] = k[3][3];
        6'd16: add_a[4] = k[3][3];
        6'd17: add_a[4] = k[3][3];
        6'd19: add_a[4] = k[4][3];
        6'd20: add_a[4] = k[4][3];
        6'd21: add_a[4] = k[4][3];

        6'd24: add_a[4] = m_reg[3];
        6'd25: add_a[4] = m_reg[3];
        6'd22: add_a[4] = m_reg[3];
        default: add_a[4] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        default: add_b[4] = m_reg[4];
    endcase
end
always @(*) begin // add5_a
    case (counter)
        6'd11: add_a[5] = k[1][2];
        6'd12: add_a[5] = k[1][2];
        6'd13: add_a[5] = k[1][2];
        6'd15: add_a[5] = k[3][2];
        6'd16: add_a[5] = k[3][2];
        6'd17: add_a[5] = k[3][2];
        
        6'd18: add_a[5] = m_reg[6];

        6'd33: add_a[5] = m_reg[4];
        6'd34: add_a[5] = m_reg[4];
        6'd35: add_a[5] = m_reg[4];
        6'd36: add_a[5] = m_reg[4];
        6'd37: add_a[5] = m_reg[4];
        6'd38: add_a[5] = m_reg[4];
        6'd39: add_a[5] = m_reg[4];
        6'd40: add_a[5] = m_reg[4];
        6'd41: add_a[5] = m_reg[4];
        6'd42: add_a[5] = m_reg[4];
        6'd43: add_a[5] = m_reg[4];
        6'd44: add_a[5] = m_reg[4];
        6'd45: add_a[5] = m_reg[4];
        6'd46: add_a[5] = m_reg[4];
        6'd47: add_a[5] = m_reg[4];
        6'd48: add_a[5] = m_reg[4];
        6'd49: add_a[5] = m_reg[4];
        6'd50: add_a[5] = m_reg[4];
        6'd51: add_a[5] = m_reg[4];
        6'd52: add_a[5] = m_reg[4];
        default: add_a[5] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        default: add_b[5] = m_reg[5];
    endcase
end
always @(*) begin // add6_a
    case (counter)
        6'd11: add_a[6] = k[2][2];
        6'd12: add_a[6] = k[2][2];
        6'd13: add_a[6] = k[2][2];
        6'd15: add_a[6] = k[3][1];
        6'd16: add_a[6] = k[3][1];
        6'd17: add_a[6] = k[3][1];

        6'd20: add_a[6] = m_reg[5];
        6'd23: add_a[6] = m_reg[5];
        6'd24: add_a[6] = m_reg[5];
        6'd25: add_a[6] = m_reg[5];

        6'd21: add_a[6] = m_reg[5];
        6'd22: add_a[6] = m_reg[5];
        default: add_a[6] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        default: add_b[6] = m_reg[6];
    endcase
end
always @(*) begin // add7_a
    case (counter)
        6'd11: add_a[7] = k[2][1];
        6'd12: add_a[7] = k[2][1];
        6'd13: add_a[7] = k[2][1];
        6'd15: add_a[7] = k[3][0];
        6'd16: add_a[7] = k[3][0];
        6'd17: add_a[7] = k[3][0];

        6'd33: add_a[7] = m_reg[6];
        6'd34: add_a[7] = m_reg[6];
        6'd35: add_a[7] = m_reg[6];
        6'd36: add_a[7] = m_reg[6];
        6'd37: add_a[7] = m_reg[6];
        6'd38: add_a[7] = m_reg[6];
        6'd39: add_a[7] = m_reg[6];
        6'd40: add_a[7] = m_reg[6];
        6'd41: add_a[7] = m_reg[6];
        6'd42: add_a[7] = m_reg[6];
        6'd43: add_a[7] = m_reg[6];
        6'd44: add_a[7] = m_reg[6];
        6'd45: add_a[7] = m_reg[6];
        6'd46: add_a[7] = m_reg[6];
        6'd47: add_a[7] = m_reg[6];
        6'd48: add_a[7] = m_reg[6];
        6'd49: add_a[7] = m_reg[6];
        6'd50: add_a[7] = m_reg[6];
        6'd51: add_a[7] = m_reg[6];
        6'd52: add_a[7] = m_reg[6];
        default: add_a[7] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        default: add_b[7] = m_reg[7];
    endcase
end
always @(*) begin // add8_a
    case (counter)
        6'd11: add_a[8] = k[2][0];
        6'd12: add_a[8] = k[2][0];
        6'd13: add_a[8] = k[2][0];

        6'd3: add_a[8] = q[0][0];
        6'd4: add_a[8] = q[0][0];
        6'd5: add_a[8] = q[0][0];
        6'd7: add_a[8] = q[0][1];
        6'd8: add_a[8] = q[0][1];
        6'd9: add_a[8] = q[0][1];
        6'd15: add_a[8] = q[3][2];
        6'd16: add_a[8] = q[3][2];
        6'd17: add_a[8] = q[3][2];
        6'd19: add_a[8] = q[4][2];
        6'd20: add_a[8] = q[4][2];
        6'd21: add_a[8] = q[4][2];

        6'd23: add_a[8] = m_reg[7];
        6'd24: add_a[8] = m_reg[7];
        6'd25: add_a[8] = m_reg[7];
        6'd22: add_a[8] = m_reg[7];
        default: add_a[8] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        default: add_b[8] = m_reg[8];
    endcase
end
always @(*) begin // add9_a
    case (counter)
        6'd7: add_a[9] = q[1][1];
        6'd8: add_a[9] = q[1][1];
        6'd9: add_a[9] = q[1][1];
        6'd11: add_a[9] = q[2][1];
        6'd12: add_a[9] = q[2][1];
        6'd13: add_a[9] = q[2][1];
        6'd15: add_a[9] = q[3][1];
        6'd16: add_a[9] = q[3][1];
        6'd17: add_a[9] = q[3][1];
        6'd19: add_a[9] = q[4][1];
        6'd20: add_a[9] = q[4][1];
        6'd21: add_a[9] = q[4][1];
        default: add_a[9] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        default: add_b[9] = m_reg[9];
    endcase
end
always @(*) begin // add10_a
    case (counter)
        6'd7: add_a[10] = q[1][0];
        6'd8: add_a[10] = q[1][0];
        6'd9: add_a[10] = q[1][0];
        6'd11: add_a[10] = q[2][0];
        6'd12: add_a[10] = q[2][0];
        6'd13: add_a[10] = q[2][0];
        6'd15: add_a[10] = q[3][0];
        6'd16: add_a[10] = q[3][0];
        6'd17: add_a[10] = q[3][0];
        6'd19: add_a[10] = q[4][0];
        6'd20: add_a[10] = q[4][0];
        6'd21: add_a[10] = q[4][0];

        6'd23: add_a[10] = m_reg[9];
        6'd24: add_a[10] = m_reg[9];
        6'd22: add_a[10] = m_reg[9];
        6'd25: add_a[10] = m_reg[9];
        default: add_a[10] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        default: add_b[10] = m_reg[10];
    endcase
end
always @(*) begin // add11_a
    case (counter)
        6'd11: add_a[11] = q[0][2];
        6'd12: add_a[11] = q[0][2];
        6'd13: add_a[11] = q[0][2];
        6'd15: add_a[11] = q[0][3];
        6'd16: add_a[11] = q[0][3];
        6'd17: add_a[11] = q[0][3];
        6'd19: add_a[11] = q[4][3];
        6'd20: add_a[11] = q[4][3];
        6'd21: add_a[11] = q[4][3];

        6'd29: add_a[11] = m_reg[12];
        6'd30: add_a[11] = m_reg[12];
        6'd31: add_a[11] = m_reg[12];
        6'd32: add_a[11] = m_reg[12];
        6'd33: add_a[11] = m_reg[12];
        6'd34: add_a[11] = m_reg[12];
        6'd35: add_a[11] = m_reg[12];
        6'd36: add_a[11] = m_reg[12];
        6'd37: add_a[11] = m_reg[12];
        6'd38: add_a[11] = m_reg[12];
        6'd39: add_a[11] = m_reg[12];
        6'd40: add_a[11] = m_reg[12];
        6'd41: add_a[11] = m_reg[12];
        6'd42: add_a[11] = m_reg[12];
        6'd43: add_a[11] = m_reg[12];
        6'd44: add_a[11] = m_reg[12];
        6'd45: add_a[11] = m_reg[12];
        6'd46: add_a[11] = m_reg[12];
        6'd47: add_a[11] = m_reg[12];
        6'd48: add_a[11] = m_reg[12];
        default: add_a[11] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        default: add_b[11] = m_reg[11];
    endcase
end
always @(*) begin // add12_a
    case (counter)
        6'd11: add_a[12] = q[1][2];
        6'd12: add_a[12] = q[1][2];
        6'd13: add_a[12] = q[1][2];
        6'd15: add_a[12] = q[1][3];
        6'd16: add_a[12] = q[1][3];
        6'd17: add_a[12] = q[1][3];

        6'd20: add_a[12] = m_reg[7];
        6'd23: add_a[12] = m_reg[11];

        6'd21: add_a[12] = m_reg[7];
        6'd22: add_a[12] = m_reg[11];
        6'd24: add_a[12] = m_reg[11];
        6'd25: add_a[12] = m_reg[11];
        default: add_a[12] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        default: add_b[12] = m_reg[12];
    endcase
end
always @(*) begin // add13_a
    case (counter)
        6'd11: add_a[13] = q[2][2];
        6'd12: add_a[13] = q[2][2];
        6'd13: add_a[13] = q[2][2];
        6'd15: add_a[13] = q[2][3];
        6'd16: add_a[13] = q[2][3];
        6'd17: add_a[13] = q[2][3];

        6'd18: add_a[13] = m_reg[14];
        6'd22: add_a[13] = v[3][3];
        6'd23: add_a[13] = v[3][3];

        6'd29: add_a[13] = m_reg[14];
        6'd30: add_a[13] = m_reg[14];
        6'd31: add_a[13] = m_reg[14];
        6'd32: add_a[13] = m_reg[14];
        6'd33: add_a[13] = m_reg[14];
        6'd34: add_a[13] = m_reg[14];
        6'd35: add_a[13] = m_reg[14];
        6'd36: add_a[13] = m_reg[14];
        6'd37: add_a[13] = m_reg[14];
        6'd38: add_a[13] = m_reg[14];
        6'd39: add_a[13] = m_reg[14];
        6'd40: add_a[13] = m_reg[14];
        6'd41: add_a[13] = m_reg[14];
        6'd42: add_a[13] = m_reg[14];
        6'd43: add_a[13] = m_reg[14];
        6'd44: add_a[13] = m_reg[14];
        6'd45: add_a[13] = m_reg[14];
        6'd46: add_a[13] = m_reg[14];
        6'd47: add_a[13] = m_reg[14];
        6'd48: add_a[13] = m_reg[14];
        default: add_a[13] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        default: add_b[13] = m_reg[13];
    endcase
end
always @(*) begin // add14_a
    case (counter)
        6'd15: add_a[14] = q[3][3];
        6'd16: add_a[14] = q[3][3];
        6'd17: add_a[14] = q[3][3];

        6'd11: add_a[14] = v[2][1];
        6'd13: add_a[14] = v[2][1];
        6'd22: add_a[14] = v[0][3];
        6'd23: add_a[14] = v[1][3];

        6'd12: add_a[14] = m_reg[4];
        6'd20: add_a[14] = m_reg[13];

        6'd21: add_a[14] = m_reg[13];
        6'd24: add_a[14] = m_reg[13];
        6'd25: add_a[14] = m_reg[13];
        default: add_a[14] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        default: add_b[14] = m_reg[14];
    endcase
end
always @(*) begin // add15_a
    case (counter)
        6'd3: add_a[15] = v[0][0];
        6'd4: add_a[15] = v[0][0];
        6'd5: add_a[15] = v[0][0];
        6'd7: add_a[15] = v[0][1];
        6'd8: add_a[15] = v[0][1];
        6'd9: add_a[15] = v[0][1];
        6'd11: add_a[15] = v[0][2];
        6'd12: add_a[15] = v[0][2];
        6'd13: add_a[15] = v[0][2];
        6'd14: add_a[15] = v[2][1];
        6'd17: add_a[15] = m_reg[16];
        6'd18: add_a[15] = v[3][3];
        6'd22: add_a[15] = v[1][3];
        6'd23: add_a[15] = v[4][1];
        6'd25: add_a[15] = v[4][1];
        6'd26: add_a[15] = v[4][1];

        default: add_a[15] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        default: add_b[15] = m_reg[15];
    endcase
end
always @(*) begin // add16_a
    case (counter)
        6'd7: add_a[16] = v[1][1];
        6'd8: add_a[16] = v[1][1];
        6'd9: add_a[16] = v[1][1];
        6'd11: add_a[16] = v[1][2];
        6'd12: add_a[16] = v[1][2];
        6'd13: add_a[16] = v[1][2];
        6'd18: add_a[16] = v[3][0];
        6'd19: add_a[16] = v[3][0];
        6'd22: add_a[16] = v[3][0];
        6'd23: add_a[16] = v[4][2];
        6'd25: add_a[16] = v[4][2];
        6'd26: add_a[16] = v[4][2];

        6'd16: add_a[16] = m_reg[15];
        6'd20: add_a[16] = m_reg[15];
        6'd21: add_a[16] = m_reg[15];
        6'd24: add_a[16] = m_reg[15];
        default: add_a[16] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        default: add_b[16] = m_reg[16];
    endcase
end
always @(*) begin // add17_a
    case (counter)
        6'd7: add_a[17] = v[1][0];
        6'd8: add_a[17] = v[1][0];
        6'd9: add_a[17] = v[1][0];
        6'd11: add_a[17] = v[2][0];
        6'd13: add_a[17] = v[2][0];
        6'd14: add_a[17] = v[2][0];
        6'd18: add_a[17] = v[2][3];
        6'd19: add_a[17] = m_reg[18];
        6'd22: add_a[17] = v[2][3];
        6'd23: add_a[17] = v[0][3];
        6'd25: add_a[17] = v[4][3];
        6'd26: add_a[17] = v[4][3];

        6'd29: add_a[17] = m_reg[16];
        6'd30: add_a[17] = m_reg[16];
        6'd31: add_a[17] = m_reg[16];
        6'd32: add_a[17] = m_reg[16];
        6'd33: add_a[17] = m_reg[16];
        6'd34: add_a[17] = m_reg[16];
        6'd35: add_a[17] = m_reg[16];
        6'd36: add_a[17] = m_reg[16];
        6'd37: add_a[17] = m_reg[16];
        6'd38: add_a[17] = m_reg[16];
        6'd39: add_a[17] = m_reg[16];
        6'd40: add_a[17] = m_reg[16];
        6'd41: add_a[17] = m_reg[16];
        6'd42: add_a[17] = m_reg[16];
        6'd43: add_a[17] = m_reg[16];
        6'd44: add_a[17] = m_reg[16];
        6'd45: add_a[17] = m_reg[16];
        6'd46: add_a[17] = m_reg[16];
        6'd47: add_a[17] = m_reg[16];
        6'd48: add_a[17] = m_reg[16];
        default: add_a[17] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        default: add_b[17] = m_reg[17];
    endcase
end
always @(*) begin // add18_a
    case (counter)
        6'd11: add_a[18] = v[2][2];
        6'd13: add_a[18] = v[2][2];
        6'd14: add_a[18] = v[2][2];
        6'd22: add_a[18] = v[4][0];
        6'd23: add_a[18] = v[4][0];
        6'd25: add_a[18] = v[4][0];

        6'd12: add_a[18] = m_reg[17];
        6'd16: add_a[18] = m_reg[17];
        6'd17: add_a[18] = m_reg[17];
        6'd20: add_a[18] = m_reg[17];
        6'd21: add_a[18] = m_reg[17];
        6'd24: add_a[18] = m_reg[17];

        6'd29: add_a[18] = m_reg[19];
        6'd30: add_a[18] = m_reg[19];
        6'd31: add_a[18] = m_reg[19];
        6'd32: add_a[18] = m_reg[19];
        6'd33: add_a[18] = m_reg[19];
        6'd34: add_a[18] = m_reg[19];
        6'd35: add_a[18] = m_reg[19];
        6'd36: add_a[18] = m_reg[19];
        6'd37: add_a[18] = m_reg[19];
        6'd38: add_a[18] = m_reg[19];
        6'd39: add_a[18] = m_reg[19];
        6'd40: add_a[18] = m_reg[19];
        6'd41: add_a[18] = m_reg[19];
        6'd42: add_a[18] = m_reg[19];
        6'd43: add_a[18] = m_reg[19];
        6'd44: add_a[18] = m_reg[19];
        6'd45: add_a[18] = m_reg[19];
        6'd46: add_a[18] = m_reg[19];
        6'd47: add_a[18] = m_reg[19];
        6'd48: add_a[18] = m_reg[19];
        default: add_a[18] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        default: add_b[18] = m_reg[18];
    endcase
end
always @(*) begin // add19_a
    case (counter)
        6'd18: add_a[19] = v[3][1];
        6'd19: add_a[19] = v[3][1];
        6'd22: add_a[19] = v[3][1];

        6'd29: add_a[19] = add_z[17];
        6'd30: add_a[19] = add_z[17];
        6'd31: add_a[19] = add_z[17];
        6'd32: add_a[19] = add_z[17];
        6'd33: add_a[19] = add_z[17];
        6'd34: add_a[19] = add_z[17];
        6'd35: add_a[19] = add_z[17];
        6'd36: add_a[19] = add_z[17];
        6'd37: add_a[19] = add_z[17];
        6'd38: add_a[19] = add_z[17];
        6'd39: add_a[19] = add_z[17];
        6'd40: add_a[19] = add_z[17];
        6'd41: add_a[19] = add_z[17];
        6'd42: add_a[19] = add_z[17];
        6'd43: add_a[19] = add_z[17];
        6'd44: add_a[19] = add_z[17];
        6'd45: add_a[19] = add_z[17];
        6'd46: add_a[19] = add_z[17];
        6'd47: add_a[19] = add_z[17];
        6'd48: add_a[19] = add_z[17];
        default: add_a[19] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        6'd29: add_b[19] = add_z[18];
        6'd30: add_b[19] = add_z[18];
        6'd31: add_b[19] = add_z[18];
        6'd32: add_b[19] = add_z[18];
        6'd33: add_b[19] = add_z[18];
        6'd34: add_b[19] = add_z[18];
        6'd35: add_b[19] = add_z[18];
        6'd36: add_b[19] = add_z[18];
        6'd37: add_b[19] = add_z[18];
        6'd38: add_b[19] = add_z[18];
        6'd39: add_b[19] = add_z[18];
        6'd40: add_b[19] = add_z[18];
        6'd41: add_b[19] = add_z[18];
        6'd42: add_b[19] = add_z[18];
        6'd43: add_b[19] = add_z[18];
        6'd44: add_b[19] = add_z[18];
        6'd45: add_b[19] = add_z[18];
        6'd46: add_b[19] = add_z[18];
        6'd47: add_b[19] = add_z[18];
        6'd48: add_b[19] = add_z[18];
        default: add_b[19] = m_reg[19];
    endcase
end
always @(*) begin // add20_a
    case (counter)
        6'd18: add_a[20] = v[3][2];
        6'd19: add_a[20] = v[3][2];
        6'd22: add_a[20] = v[3][2];

        6'd12: add_a[20] = m_reg[19];
        6'd16: add_a[20] = m_reg[19];
        6'd17: add_a[20] = m_reg[19];
        6'd20: add_a[20] = m_reg[19];
        6'd21: add_a[20] = m_reg[19];
        6'd23: add_a[20] = m_reg[19];
        6'd24: add_a[20] = m_reg[19];
        6'd25: add_a[20] = m_reg[19];

        6'd30: add_a[20] = head_part[1][0];
        6'd31: add_a[20] = head_part[1][0];
        6'd32: add_a[20] = head_part[1][0];
        6'd33: add_a[20] = head_part[1][0];
        6'd34: add_a[20] = head_part[1][0];
        6'd35: add_a[20] = head_part[1][0];
        6'd36: add_a[20] = head_part[1][0];
        6'd37: add_a[20] = head_part[1][0];
        6'd38: add_a[20] = head_part[1][0];
        6'd39: add_a[20] = head_part[1][0];
        6'd40: add_a[20] = head_part[1][0];
        6'd41: add_a[20] = head_part[1][0];
        6'd42: add_a[20] = head_part[1][0];
        6'd43: add_a[20] = head_part[1][0];
        6'd44: add_a[20] = head_part[1][0];
        6'd45: add_a[20] = head_part[1][0];
        6'd46: add_a[20] = head_part[1][0];
        6'd47: add_a[20] = head_part[1][0];
        6'd48: add_a[20] = head_part[1][0];
        6'd49: add_a[20] = head_part[1][0];
        default: add_a[20] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        6'd30: add_b[20] = head_part[1][1];
        6'd31: add_b[20] = head_part[1][1];
        6'd32: add_b[20] = head_part[1][1];
        6'd33: add_b[20] = head_part[1][1];
        6'd34: add_b[20] = head_part[1][1];
        6'd35: add_b[20] = head_part[1][1];
        6'd36: add_b[20] = head_part[1][1];
        6'd37: add_b[20] = head_part[1][1];
        6'd38: add_b[20] = head_part[1][1];
        6'd39: add_b[20] = head_part[1][1];
        6'd40: add_b[20] = head_part[1][1];
        6'd41: add_b[20] = head_part[1][1];
        6'd42: add_b[20] = head_part[1][1];
        6'd43: add_b[20] = head_part[1][1];
        6'd44: add_b[20] = head_part[1][1];
        6'd45: add_b[20] = head_part[1][1];
        6'd46: add_b[20] = head_part[1][1];
        6'd47: add_b[20] = head_part[1][1];
        6'd48: add_b[20] = head_part[1][1];
        6'd49: add_b[20] = head_part[1][1];
        default: add_b[20] = m_reg[20];
    endcase
end
//---------------------------------------------------------------------
// FP_EXP
//---------------------------------------------------------------------
always @(*) begin
    case (counter)
        6'd13: exp_a[1] = score[1][0][0];
        6'd17: exp_a[1] = score[1][0][2];
        6'd18: exp_a[1] = score[1][2][0];
        6'd21: exp_a[1] = score[1][3][0];
        6'd24: exp_a[1] = score[1][0][3];
        6'd25: exp_a[1] = score[1][0][4];
        6'd26: exp_a[1] = score[1][4][0];
        6'd22: exp_a[1] = score[2][0][2];
        6'd23: exp_a[1] = score[2][2][2];
        6'd27: exp_a[1] = score[2][2][3];
        6'd28: exp_a[1] = score[2][4][2];
        default: exp_a[1] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        6'd13: exp_a[2] = score[1][0][1];
        6'd17: exp_a[2] = score[1][1][2];
        6'd18: exp_a[2] = score[1][2][1];
        6'd21: exp_a[2] = score[1][3][1];
        6'd24: exp_a[2] = score[1][1][3];
        6'd25: exp_a[2] = score[1][1][4];
        6'd26: exp_a[2] = score[1][4][1];
        6'd22: exp_a[2] = score[2][1][2];
        6'd23: exp_a[2] = score[2][3][2];
        6'd27: exp_a[2] = score[2][3][3];
        6'd28: exp_a[2] = score[2][4][3];
        default: exp_a[2] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        6'd13: exp_a[3] = score[1][1][0];
        6'd17: exp_a[3] = score[1][2][2];
        6'd21: exp_a[3] = score[1][3][2];
        6'd24: exp_a[3] = score[1][2][3];
        6'd25: exp_a[3] = score[1][2][4];
        6'd26: exp_a[3] = score[1][4][2];
        6'd22: exp_a[3] = score[2][2][0];
        6'd23: exp_a[3] = score[2][2][1];
        6'd27: exp_a[3] = score[2][2][4];
        6'd28: exp_a[3] = score[2][3][4];
        default: exp_a[3] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        6'd13: exp_a[4] = score[1][1][1];
        6'd24: exp_a[4] = score[1][3][3];
        6'd25: exp_a[4] = score[1][3][4];
        6'd26: exp_a[4] = score[1][4][3];
        6'd21: exp_a[4] = score[2][0][0];
        6'd22: exp_a[4] = score[2][1][0];
        6'd23: exp_a[4] = score[2][3][0];
        6'd27: exp_a[4] = score[2][1][3];
        6'd28: exp_a[4] = score[2][4][0];
        default: exp_a[4] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        6'd25: exp_a[5] = score[1][4][4];
        6'd21: exp_a[5] = score[2][0][1];
        6'd22: exp_a[5] = score[2][1][1];
        6'd23: exp_a[5] = score[2][3][1];
        6'd24: exp_a[5] = score[2][0][3];
        6'd26: exp_a[5] = score[2][0][4];
        6'd27: exp_a[5] = score[2][1][4];
        6'd28: exp_a[5] = score[2][4][1];
        6'd29: exp_a[5] = score[2][4][4];
        default: exp_a[5] = 32'b0;
    endcase
end
//---------------------------------------------------------------------
// FP_DIV
//---------------------------------------------------------------------
generate
    for (i = 0; i < 5; i = i + 1) begin:div_assign
        always @(*) begin
            case (counter)
                6'd27: div_a[i] = score[1][0][i];
                6'd29: div_a[i] = score[1][1][i];
                6'd31: div_a[i] = score[1][2][i];
                6'd33: div_a[i] = score[1][3][i];
                6'd35: div_a[i] = score[1][4][i];

                6'd28: div_a[i] = score[2][0][i];
                6'd30: div_a[i] = score[2][1][i];
                6'd32: div_a[i] = score[2][2][i];
                6'd34: div_a[i] = score[2][3][i];
                6'd36: div_a[i] = score[2][4][i];
                default: div_a[i] = 32'b0;
            endcase
        end
        always @(*) begin
            case (counter)
                6'd27: div_b[i] = sum3[1][0];
                6'd29: div_b[i] = sum3[1][1];
                6'd31: div_b[i] = sum3[1][2];
                6'd33: div_b[i] = sum3[1][3];
                6'd35: div_b[i] = sum3[1][4];

                6'd28: div_b[i] = sum3[2][0];
                6'd30: div_b[i] = sum3[2][1];
                6'd32: div_b[i] = sum3[2][2];
                6'd34: div_b[i] = sum3[2][3];
                6'd36: div_b[i] = sum3[2][4];
                default: div_b[i] = 32'b0;
            endcase
        end
    end
endgenerate
//---------------------------------------------------------------------
// FP_SUM3
//---------------------------------------------------------------------
always @(*) begin
    case (counter)
        6'd18: sum_a[1] = score[1][0][0];
        6'd19: sum_a[1] = score[1][2][0];
        6'd22: sum_a[1] = score[1][3][0];
        6'd30: sum_a[1] = score[1][4][0];

        6'd26: sum_a[1] = sum3[1][0];
        6'd27: sum_a[1] = sum3[1][2];
        6'd29: sum_a[1] = sum3[1][3];
        6'd31: sum_a[1] = sum3[1][4];

        6'd23: sum_a[1] = score[2][0][0];
        6'd24: sum_a[1] = score[2][2][0];

        6'd28: sum_a[1] = sum3[2][1];
        default: sum_a[1] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        6'd18: sum_b[1] = score[1][0][1];
        6'd19: sum_b[1] = score[1][2][1];
        6'd22: sum_b[1] = score[1][3][1];
        6'd30: sum_b[1] = score[1][4][1];

        6'd26: sum_b[1] = score[1][0][3];
        6'd27: sum_b[1] = score[1][2][3];
        6'd29: sum_b[1] = score[1][3][3];
        6'd31: sum_b[1] = score[1][4][3];

        6'd23: sum_b[1] = score[2][0][1];
        6'd24: sum_b[1] = score[2][2][1];

        6'd28: sum_b[1] = score[2][1][3];
        default: sum_b[1] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        6'd18: sum_c[1] = score[1][0][2];
        6'd19: sum_c[1] = score[1][2][2];
        6'd22: sum_c[1] = score[1][3][2];
        6'd30: sum_c[1] = score[1][4][2];

        6'd26: sum_c[1] = score[1][0][4];
        6'd27: sum_c[1] = score[1][2][4];
        6'd29: sum_c[1] = score[1][3][4];
        6'd31: sum_c[1] = score[1][4][4];

        6'd23: sum_c[1] = score[2][0][2];
        6'd24: sum_c[1] = score[2][2][2];

        6'd28: sum_c[1] = score[2][1][4];
        default: sum_c[1] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        6'd18: sum_a[2] = score[1][1][0];

        6'd26: sum_a[2] = sum3[1][1];

        6'd23: sum_a[2] = score[2][1][0];
        6'd24: sum_a[2] = score[2][3][0];
        6'd30: sum_a[2] = score[2][4][0];

        6'd27: sum_a[2] = sum3[2][0];
        6'd28: sum_a[2] = sum3[2][2];
        6'd29: sum_a[2] = sum3[2][3];
        6'd31: sum_a[2] = sum3[2][4];
        default: sum_a[2] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        6'd18: sum_b[2] = score[1][1][1];

        6'd26: sum_b[2] = score[1][1][3];

        6'd23: sum_b[2] = score[2][1][1];
        6'd24: sum_b[2] = score[2][3][1];
        6'd30: sum_b[2] = score[2][4][1];

        6'd27: sum_b[2] = score[2][0][3];
        6'd28: sum_b[2] = score[2][2][3];
        6'd29: sum_b[2] = score[2][3][3];
        6'd31: sum_b[2] = score[2][4][3];
        default: sum_b[2] = 32'b0;
    endcase
end
always @(*) begin
    case (counter)
        6'd18: sum_c[2] = score[1][1][2];

        6'd26: sum_c[2] = score[1][1][4];

        6'd23: sum_c[2] = score[2][1][2];
        6'd24: sum_c[2] = score[2][3][2];
        6'd30: sum_c[2] = score[2][4][2];

        6'd27: sum_c[2] = score[2][0][4];
        6'd28: sum_c[2] = score[2][2][4];
        6'd29: sum_c[2] = score[2][3][4];
        6'd31: sum_c[2] = score[2][4][4];
        default: sum_c[2] = 32'b0;
    endcase
end
endmodule